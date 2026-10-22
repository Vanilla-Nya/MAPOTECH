// ==============================================================================
// DRAFT SUPABASE EDGE FUNCTION: vitascale-device
// Purpose: Authenticated Device API for VitaScale ESP32
// Status: DRAFT / LOCAL DEVELOPMENT (Tidak dideploy tanpa izin produksi)
// ==============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-device-token",
};

// SHA-256 helper
async function sha256(str: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(str));
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  const url = new URL(req.url);
  const path = url.pathname.replace(/^\/vitascale-device\/?/, "");

  try {
    // --------------------------------------------------------------------------
    // 1. ENDPOINT: POST /pair (Registrasi Perangkat Menggunakan Kode Sekali Pakai)
    // --------------------------------------------------------------------------
    if (path === "pair" && req.method === "POST") {
      const { pairing_code, device_serial, firmware_version } = await req.json();

      if (!pairing_code || !device_serial) {
        return new Response(
          JSON.stringify({ error: "pairing_code dan device_serial wajib diisi." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const codeHash = await sha256(pairing_code.trim().toUpperCase());

      // Validasi kode pairing di database
      const { data: codeRow, error: codeErr } = await supabase
        .schema("vitascale")
        .from("pairing_codes")
        .select("*")
        .eq("code_hash", codeHash)
        .is("used_at", null)
        .gt("expires_at", new Date().toISOString())
        .maybeSingle();

      if (codeErr || !codeRow) {
        return new Response(
          JSON.stringify({ error: "Kode pairing tidak valid, sudah digunakan, atau kedaluwarsa." }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Generate token perangkat unik dan simpan hash-nya
      const rawDeviceToken = `vts_dev_${crypto.randomUUID().replace(/-/g, "")}`;
      const tokenHash = await sha256(rawDeviceToken);

      // Daftarkan perangkat ke faskes terkait
      const { data: device, error: devErr } = await supabase
        .schema("vitascale")
        .from("devices")
        .upsert(
          {
            facility_id: codeRow.facility_id,
            device_serial: device_serial,
            device_label: `VitaScale - ${device_serial.substring(0, 8)}`,
            token_hash: tokenHash,
            status: "active",
            firmware_version: firmware_version ?? "v1.0.0",
            last_seen_at: new Date().toISOString(),
          },
          { onConflict: "device_serial" }
        )
        .select()
        .single();

      if (devErr) {
        return new Response(
          JSON.stringify({ error: "Gagal mendaftarkan perangkat.", details: devErr.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Tandai kode pairing sudah digunakan
      await supabase
        .schema("vitascale")
        .from("pairing_codes")
        .update({ used_at: new Date().toISOString(), used_by_device_id: device.id })
        .eq("id", codeRow.id);

      return new Response(
        JSON.stringify({
          success: true,
          message: "Perangkat berhasil terhubung ke faskes MAPOTECH.",
          device_id: device.id,
          device_token: rawDeviceToken, // Token rahasia ini hanya dikembalikan sekali ke ESP32
          facility_id: codeRow.facility_id,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // --------------------------------------------------------------------------
    // 2. AUTHENTICATION: Periksa Header X-Device-Token untuk Endpoint Sensor
    // --------------------------------------------------------------------------
    const rawToken = req.headers.get("x-device-token");
    if (!rawToken) {
      return new Response(
        JSON.stringify({ error: "Header x-device-token wajib disertakan." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const tokenHash = await sha256(rawToken);
    const { data: device, error: authErr } = await supabase
      .schema("vitascale")
      .from("devices")
      .select("*")
      .eq("token_hash", tokenHash)
      .eq("status", "active")
      .maybeSingle();

    if (authErr || !device) {
      return new Response(
        JSON.stringify({ error: "Kredensial perangkat tidak sah atau perangkat telah dicabut." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // --------------------------------------------------------------------------
    // 3. ENDPOINT: POST /heartbeat (Laporan Status Online Perangkat)
    // --------------------------------------------------------------------------
    if (path === "heartbeat" && req.method === "POST") {
      await supabase
        .schema("vitascale")
        .from("devices")
        .update({ last_seen_at: new Date().toISOString() })
        .eq("id", device.id);

      return new Response(
        JSON.stringify({
          status: "online",
          device_id: device.id,
          server_time: new Date().toISOString(),
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // --------------------------------------------------------------------------
    // 4. ENDPOINT: POST /measurement (Penerimaan Event Sensor dari ESP32)
    // --------------------------------------------------------------------------
    if (path === "measurement" && req.method === "POST") {
      const payload = await req.json();
      const { session_id, measurement_type, value, unit, quality, idempotency_key } = payload;

      if (!session_id || !measurement_type || value === undefined || !idempotency_key) {
        return new Response(
          JSON.stringify({ error: "Payload sensor tidak lengkap." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Validasi sesi aktif & milik faskes yang sama
      const { data: session, error: sesErr } = await supabase
        .schema("vitascale")
        .from("screening_sessions")
        .select("id, facility_id, status")
        .eq("id", session_id)
        .eq("facility_id", device.facility_id)
        .maybeSingle();

      if (sesErr || !session) {
        return new Response(
          JSON.stringify({ error: "Sesi skrining tidak ditemukan atau bukan milik faskes perangkat." }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (session.status !== "active") {
        return new Response(
          JSON.stringify({ error: "Sesi skrining sudah ditutup/selesai. Pengukuran baru ditolak." }),
          { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Validasi rentang nilai fisik
      const numVal = Number(value);
      if (measurement_type === "weight" && (numVal < 1.0 || numVal > 150.0)) {
        return new Response(
          JSON.stringify({ error: "Nilai berat badan di luar rentang valid (1.0 - 150 kg)." }),
          { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      if (measurement_type === "waist" && (numVal < 25.0 || numVal > 140.0)) {
        return new Response(
          JSON.stringify({ error: "Nilai lingkar perut di luar rentang valid (25 - 140 cm)." }),
          { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Simpan event dengan penanganan idempotency (ON CONFLICT DO NOTHING)
      const { data: event, error: evErr } = await supabase
        .schema("vitascale")
        .from("measurement_events")
        .insert({
          session_id: session_id,
          device_id: device.id,
          measurement_type: measurement_type,
          value_numeric: numVal,
          unit: unit ?? (measurement_type === "weight" ? "kg" : "cm"),
          quality: quality ?? "stable",
          captured_at: payload.captured_at ?? new Date().toISOString(),
          idempotency_key: idempotency_key,
        })
        .select()
        .maybeSingle();

      if (evErr) {
        // Jika duplikasi idempotency_key, kembalikan respon sukses idempotent tanpa input ulang
        if (evErr.code === "23505") {
          return new Response(
            JSON.stringify({
              success: true,
              message: "Event duplikat diabaikan (Idempotent OK).",
              idempotent: true,
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
        return new Response(
          JSON.stringify({ error: "Gagal menyimpan data sensor.", details: evErr.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Update waktu aktif perangkat
      await supabase
        .schema("vitascale")
        .from("devices")
        .update({ last_seen_at: new Date().toISOString() })
        .eq("id", device.id);

      return new Response(
        JSON.stringify({
          success: true,
          event_id: event?.id,
          message: "Data pengukuran sensor berhasil dicatat ke sesi.",
        }),
        { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ error: "Endpoint tidak ditemukan." }),
      { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: "Terjadi kesalahan internal server.", details: err?.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
