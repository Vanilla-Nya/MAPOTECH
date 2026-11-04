// ==============================================================================
// SUPABASE EDGE FUNCTION: satusehat-proxy
// Purpose: Secure server-side proxy for SatuSehat FHIR API to bypass browser CORS
// ==============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

serve(async (req: Request) => {
  // Handle CORS preflight request
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const {
      method = "POST",
      endpoint,
      token,
      env = "production",
      payload,
    } = await req.json();

    if (!endpoint || !token) {
      return new Response(
        JSON.stringify({
          status: false,
          message: "Parameter 'endpoint' dan 'token' wajib disertakan.",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const isStg =
      env.toLowerCase() === "development" ||
      env.toLowerCase() === "dev" ||
      env.toLowerCase() === "stg";

    const baseUrl = isStg
      ? "https://api-satusehat-stg.dto.kemkes.go.id/fhir-r4/v1"
      : "https://api-satusehat.kemkes.go.id/fhir-r4/v1";

    // Clean endpoint to ensure proper formatting
    let cleanEndpoint = endpoint.trim();
    if (cleanEndpoint.startsWith("/fhir-r4/v1/")) {
      cleanEndpoint = cleanEndpoint.replace("/fhir-r4/v1/", "/");
    } else if (cleanEndpoint.startsWith("fhir-r4/v1/")) {
      cleanEndpoint = cleanEndpoint.replace("fhir-r4/v1/", "/");
    }
    if (!cleanEndpoint.startsWith("/")) {
      cleanEndpoint = `/${cleanEndpoint}`;
    }

    const targetUrl = `${baseUrl}${cleanEndpoint}`;

    const headers: Record<string, string> = {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
      "User-Agent": "Mapotech-Healthcare-Platform/1.0",
    };

    const httpMethod = method.toUpperCase();
    if (httpMethod !== "GET" && httpMethod !== "HEAD") {
      headers["Content-Type"] = "application/json";
    }

    const fetchOptions: RequestInit = {
      method: httpMethod,
      headers,
    };

    if (
      payload &&
      (httpMethod === "POST" || httpMethod === "PUT" || httpMethod === "PATCH")
    ) {
      fetchOptions.body =
        typeof payload === "string" ? payload : JSON.stringify(payload);
    }

    const response = await fetch(targetUrl, fetchOptions);
    const responseText = await response.text();

    let data;
    try {
      data = JSON.parse(responseText);
    } catch (_) {
      data = responseText;
    }

    if (response.ok) {
      return new Response(
        JSON.stringify({ status: true, statusCode: response.status, data }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    } else {
      let errorMessage = responseText;
      if (typeof data === "object" && data !== null) {
        if (data.issue && Array.isArray(data.issue) && data.issue[0]?.details?.text) {
          errorMessage = data.issue[0].details.text;
        } else if (data.message) {
          errorMessage = data.message;
        }
      }

      return new Response(
        JSON.stringify({
          status: false,
          statusCode: response.status,
          message: `SatuSehat API error (${response.status}): ${errorMessage}`,
          data,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }
  } catch (err: any) {
    return new Response(
      JSON.stringify({
        status: false,
        message: `Proxy exception: ${err.message || err}`,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

