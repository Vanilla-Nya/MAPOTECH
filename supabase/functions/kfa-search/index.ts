// ==============================================================================
// SUPABASE EDGE FUNCTION: kfa-search
// Purpose: Proxy API to search SatuSehat KFA v2 products without CORS / Geo-blocking
// ==============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { keyword, token, env = "production", page = 1, size = 20 } = await req.json();

    if (!keyword || !token) {
      return new Response(
        JSON.stringify({ status: false, message: "Parameter keyword dan token wajib disertakan." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const isStg = env.toLowerCase() === "development" || env.toLowerCase() === "dev" || env.toLowerCase() === "stg";
    const kfaBaseUrl = isStg
      ? "https://api-satusehat-stg.dto.kemkes.go.id/kfa-v2"
      : "https://api-satusehat.kemkes.go.id/kfa-v2";

    const targetUrl = `${kfaBaseUrl}/products/all?keyword=${encodeURIComponent(keyword)}&page=${page}&size=${size}&product_type=farmasi`;

    const response = await fetch(targetUrl, {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Accept": "application/json",
        "User-Agent": "Mapotech-Healthcare-Platform/1.0",
      },
    });

    const responseBody = await response.text();

    if (response.ok) {
      try {
        const data = JSON.parse(responseBody);
        return new Response(
          JSON.stringify({ status: true, data }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      } catch (_) {
        return new Response(
          JSON.stringify({ status: true, data: responseBody }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    } else {
      return new Response(
        JSON.stringify({
          status: false,
          code: response.status,
          message: `KFA API Kemenkes error (${response.status}): ${responseBody}`,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  } catch (err: any) {
    return new Response(
      JSON.stringify({ status: false, message: `Proxy exception: ${err.message || err}` }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

