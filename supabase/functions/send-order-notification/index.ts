import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'
import { JWT } from 'https://esm.sh/google-auth-library@9.1.0'

interface Order {
  id: string
  restaurant_id: string
  table_number: string
  total: number
  customer_name?: string
}

interface WebhookPayload {
  type: 'INSERT'
  table: string
  record: Order
  schema: 'public'
}

Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json()
    console.log('Received webhook for order:', payload.record.id)

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Fetch restaurant's FCM token
    const { data: restaurant, error: resError } = await supabase
      .from('restaurants')
      .select('name, fcm_token')
      .eq('id', payload.record.restaurant_id)
      .single()

    if (resError || !restaurant?.fcm_token) {
      console.log('No FCM token found for restaurant:', payload.record.restaurant_id)
      return new Response(JSON.stringify({ message: 'No token' }), { status: 200 })
    }

    // Get Firebase Service Account from Env
    const firebaseConfig = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!firebaseConfig) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT environment variable is not set')
    }
    const serviceAccount = JSON.parse(firebaseConfig)

    // Get Access Token
    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })
    
    const tokens = await jwtClient.authorize()
    const accessToken = tokens.access_token

    // Send Notification
    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: restaurant.fcm_token,
            notification: {
              title: `New Order: Table ${payload.record.table_number}`,
              body: `${payload.record.customer_name || 'Customer'} ordered items totaling ₹${payload.record.total}`,
            },
            android: {
              priority: 'high',
              notification: {
                channel_id: 'godine_new_orders',
                sound: 'default',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
              },
            },
            data: {
              order_id: payload.record.id,
              type: 'new_order'
            }
          },
        }),
      }
    )

    const fcmResult = await fcmRes.json()
    console.log('FCM Result:', fcmResult)

    return new Response(JSON.stringify(fcmResult), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('Error sending notification:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
