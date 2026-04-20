import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { amount, currency = 'INR', receipt } = await req.json();

    if (!amount || amount < 100) {
      return new Response(JSON.stringify({ error: 'Invalid amount. Minimum 100 paise required.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const key_id = Deno.env.get('RAZORPAY_KEY_ID');
    const key_secret = Deno.env.get('RAZORPAY_KEY_SECRET');

    if (!key_id || !key_secret) {
      throw new Error('Razorpay keys not configured on server.');
    }

    const authHeader = 'Basic ' + btoa(key_id + ':' + key_secret);

    const orderRes = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      },
      body: JSON.stringify({
        amount: parseInt(String(amount), 10),
        currency,
        receipt: receipt || `rcpt_${Date.now()}`,
      }),
    });

    const order = await orderRes.json();

    if (!orderRes.ok) {
      throw new Error(order.error?.description || 'Failed to create Razorpay order');
    }

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
