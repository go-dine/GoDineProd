import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, plan_id, restaurant_id } = await req.json();
    const key_secret = Deno.env.get('RAZORPAY_KEY_SECRET');

    if (!key_secret) throw new Error('Server secret key missing.');

    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return new Response(JSON.stringify({ error: 'Missing required Razorpay fields.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Compute HMAC-SHA256 signature
    const body = razorpay_order_id + '|' + razorpay_payment_id;
    const encoder = new TextEncoder();
    const keyData = encoder.encode(key_secret);
    const msgData = encoder.encode(body);

    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      keyData,
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );

    const sig = await crypto.subtle.sign('HMAC', cryptoKey, msgData);
    const expectedSignature = Array.from(new Uint8Array(sig))
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');

    if (expectedSignature !== razorpay_signature) {
      return new Response(JSON.stringify({ error: 'Signature mismatch. Payment verification failed.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Payment is valid — update the database
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    let plan = 'starter';
    const numPlanId = parseInt(String(plan_id), 10);
    let amountMonths = 1;
    
    // Align with Flutter App Plan IDs: 2 = Pro (Monthly), 3 = Lifetime
    if (numPlanId === 2) {
      plan = 'pro';
      amountMonths = 1;
    } else if (numPlanId === 3) {
      plan = 'lifetime';
      amountMonths = 1200; // 100 years
    }

    if (restaurant_id) {
      // 1. Fetch current subscription end to calculate extension
      const { data: restaurant, error: fetchError } = await adminClient
        .from('restaurants')
        .select('subscription_end')
        .eq('id', restaurant_id)
        .single();
      
      if (fetchError) throw fetchError;

      const currentEnd = restaurant.subscription_end ? new Date(restaurant.subscription_end) : new Date();
      const baseDate = currentEnd > new Date() ? currentEnd : new Date();
      
      const futureDate = new Date(baseDate);
      futureDate.setMonth(futureDate.getMonth() + amountMonths);

      // 2. Update restaurant subscription
      const { error: updateError } = await adminClient.from('restaurants').update({
        plan: plan,
        subscription_end: futureDate.toISOString(),
        is_trial: false,
      }).eq('id', restaurant_id);
      
      if (updateError) throw updateError;

      // 3. Log payment with the new "Renew Date" (subscription_end)
      const { error: logError } = await adminClient.from('payments').insert({
        restaurant_id: restaurant_id,
        amount: 0, // Should ideally be passed from request, but keep as 0 if unknown
        status: 'successful',
        method: 'razorpay',
        razorpay_order_id: razorpay_order_id,
        razorpay_payment_id: razorpay_payment_id,
        plan_id: String(plan_id),
        renew_date: futureDate.toISOString(),
      });

      if (logError) console.error('Error logging payment:', logError);
    }

    return new Response(JSON.stringify({ success: true, message: 'Payment verified successfully!' }), {
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
