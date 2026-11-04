import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import md5 from "https://esm.sh/blueimp-md5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const orderId = body.merchantOrderId || body.orderId;

    if (!orderId) {
      return new Response(
        JSON.stringify({ error: "Missing merchantOrderId" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const merchantCode = body.merchantCode || Deno.env.get("DUITKU_MERCHANT_CODE") || "DS24853";
    const merchantKey = body.merchantKey || Deno.env.get("DUITKU_MERCHANT_KEY") || "605d62af77cf1f18830c961b80cdbe9f";

    const isSandboxMerchant = merchantCode.startsWith("DS");
    const checkUrl = isSandboxMerchant
      ? "https://sandbox.duitku.com/webapi/api/merchant/transactionStatus"
      : "https://passport.duitku.com/webapi/api/merchant/transactionStatus";

    const signature = md5(`${merchantCode}${orderId}${merchantKey}`);

    const res = await fetch(checkUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        merchantCode,
        merchantOrderId: orderId,
        signature,
      }),
    });

    const duitkuData = await res.json();
    console.log("Check Status Response:", duitkuData);

    const isPaid = duitkuData.statusCode === "00";

    return new Response(
      JSON.stringify({
        statusCode: duitkuData.statusCode,
        statusMessage: duitkuData.statusMessage,
        isPaid,
        duitkuData,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

