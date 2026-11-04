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

    // Dynamic price based on clicked package
    const rawAmount = body.amount ?? body.paymentAmount ?? body.price;
    const paymentAmount = Number(rawAmount) || 150000;

    const packageType = body.packageType || "subscription_30";
    const email = body.customerEmail || body.email || "customer@mapotech.app";
    const customerName = body.customerName || "Pengguna Mapotech";

    const merchantCode = body.merchantCode || Deno.env.get("DUITKU_MERCHANT_CODE") || "DS24853";
    const merchantKey = body.merchantKey || Deno.env.get("DUITKU_MERCHANT_KEY") || "605d62af77cf1f18830c961b80cdbe9f";
    // NQ = Nobu QRIS (Universal standard national QRIS), SP = ShopeePay QRIS
    const requestedMethod = body.paymentMethod || Deno.env.get("DUITKU_PAYMENT_METHOD") || "NQ";

    const isSandboxMerchant = merchantCode.startsWith("DS");
    const inquiryUrl = isSandboxMerchant
      ? "https://sandbox.duitku.com/webapi/api/merchant/v2/inquiry"
      : "https://passport.duitku.com/webapi/api/merchant/v2/inquiry";

    const callbackUrl = Deno.env.get("DUITKU_CALLBACK_URL") || "https://abdburxhqqwsobmzuwmz.supabase.co/functions/v1/duitku-callback";
    const returnUrl = Deno.env.get("DUITKU_RETURN_URL") || "https://mapotech.app/payment-success";

    const orderId = `MAPO-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

    let productDetails = "Langganan Mapotech";
    if (packageType === "subscription_30") productDetails = "Standard Subscription (30 Hari)";
    else if (packageType === "premium_30") productDetails = "Premium Customizer (30 Hari)";
    else if (packageType === "premium_sync") productDetails = "Premium Customizer (Sync Durasi)";
    else if (packageType === "premium_lifetime") productDetails = "Premium Customizer (Lifetime)";
    else if (packageType === "bundle_30") productDetails = "Mega Bundle (30 Hari)";

    async function callDuitkuInquiry(method: string) {
      const signature = md5(`${merchantCode}${orderId}${paymentAmount}${merchantKey}`);
      const payload = {
        merchantCode,
        paymentAmount,
        paymentMethod: method,
        merchantOrderId: orderId,
        productDetails,
        email,
        additionalParam: packageType,
        merchantUserInfo: "",
        customerVaName: customerName,
        callbackUrl,
        returnUrl,
        signature,
        expiryPeriod: 60,
      };

      console.log("Calling Duitku Inquiry:", { inquiryUrl, merchantCode, orderId, paymentAmount, paymentMethod: method });

      const res = await fetch(inquiryUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      return await res.json();
    }

    let duitkuData = await callDuitkuInquiry(requestedMethod);
    console.log("Duitku Response 1:", duitkuData);

    // If requested method failed (e.g. SP returned "Failed to generate QR String Shopee"), fallback to NQ
    if (duitkuData.statusCode !== "00" && requestedMethod !== "NQ") {
      console.log(`Method ${requestedMethod} failed, falling back to NQ (Nobu QRIS)...`);
      duitkuData = await callDuitkuInquiry("NQ");
      console.log("Duitku Fallback Response:", duitkuData);
    }

    if (duitkuData.statusCode === "00") {
      return new Response(
        JSON.stringify({
          statusCode: "00",
          statusMessage: "SUCCESS",
          orderId,
          paymentUrl: duitkuData.paymentUrl,
          qrString: duitkuData.qrString || duitkuData.vaNumber || "",
          amount: paymentAmount,
          reference: duitkuData.reference,
          packageType,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    } else {
      return new Response(
        JSON.stringify({
          statusCode: duitkuData.statusCode || "99",
          statusMessage: duitkuData.statusMessage || "Gagal membuat transaksi QRIS",
          error: duitkuData.statusMessage,
          duitkuData,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
