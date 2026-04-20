import { serve } from "https://deno.land/std@0.177.1/http/server.ts";
import crypto from "node:crypto";
import { createClient } from "npm:@supabase/supabase-js@2.103.0";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, plan_id, restaurant_id } = await req.json();
    const key_secret = Deno.env.get("RAZORPAY_KEY_SECRET");

    if (!key_secret) throw new Error("Server secret key missing.");

    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
       return new Response(JSON.stringify({ error: "Missing required Razorpay fields." }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const body = razorpay_order_id + "|" + razorpay_payment_id;
    const expectedSignature = crypto
      .createHmac("sha256", key_secret)
      .update(body.toString())
      .digest("hex");

    if (expectedSignature !== razorpay_signature) {
      return new Response(JSON.stringify({ error: "Signature mismatch. Payment verification failed." }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    // Payment is valid! Update the database
    // Usually auth header is passed by the client
    const authHeader = req.headers.get('Authorization')
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    
    // We use service_role to forcefully update since we verified the payment via HMAC!
    const adminClient = createClient(
      supabaseUrl,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    let plan = 'starter';
    const numPlanId = parseInt(plan_id, 10);
    let amountMonths = 1;
    if (numPlanId === 2) plan = 'pro';
    else if (numPlanId === 3) plan = 'advanced';
    else if (numPlanId === 4) { plan = 'lifetime'; amountMonths = 1200; } // 100 years

    const futureDate = new Date();
    futureDate.setMonth(futureDate.getMonth() + amountMonths);

    if (restaurant_id) {
       const { error } = await adminClient.from('restaurants').update({
           plan: plan,
           subscription_end: futureDate.toISOString()
       }).eq('id', restaurant_id);
       if (error) throw error;
    }

    return new Response(JSON.stringify({ success: true, message: "Payment verified successfully!" }), {
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
