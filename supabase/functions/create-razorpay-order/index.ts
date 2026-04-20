import { serve } from "https://deno.land/std@0.177.1/http/server.ts";
import Razorpay from "npm:razorpay@2.9.2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { amount, currency = "INR", receipt } = await req.json();

    if (!amount || amount < 100) {
      return new Response(JSON.stringify({ error: "Invalid amount. Minimum 100 paise required." }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const key_id = Deno.env.get("RAZORPAY_KEY_ID");
    const key_secret = Deno.env.get("RAZORPAY_KEY_SECRET");

    if (!key_id || !key_secret) {
      throw new Error("Razorpay keys not configured on server.");
    }

    const razorpay = new Razorpay({
      key_id,
      key_secret
    });

    const options = {
      amount: parseInt(amount, 10),
      currency,
      receipt: receipt || `rcpt_${Date.now()}`
    };

    const order = await razorpay.orders.create(options);

    return new Response(JSON.stringify(order), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
