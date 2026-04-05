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

    // Fetch restaurant name and primary FCM token
    const { data: restaurant, error: resError } = await supabase
      .from('restaurants')
      .select('name, fcm_token')
      .eq('id', payload.record.restaurant_id)
      .single()

    if (resError) {
      console.log('Restaurant lookup error:', resError.message)
      return new Response(JSON.stringify({ message: 'Restaurant not found' }), { status: 200 })
    }

    // Collect all FCM tokens: primary from restaurants table + all from owner_fcm_tokens
    const tokens: string[] = []
    if (restaurant?.fcm_token) {
      tokens.push(restaurant.fcm_token)
    }

    // Also fetch from owner_fcm_tokens for multi-device support
    const { data: tokenRows } = await supabase
      .from('owner_fcm_tokens')
      .select('token')
      .eq('restaurant_id', payload.record.restaurant_id)

    if (tokenRows) {
      for (const row of tokenRows) {
        if (row.token && !tokens.includes(row.token)) {
          tokens.push(row.token)
        }
      }
    }

    if (tokens.length === 0) {
      console.log('No FCM tokens found for restaurant:', payload.record.restaurant_id)
      return new Response(JSON.stringify({ message: 'No tokens' }), { status: 200 })
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
    
    const authTokens = await jwtClient.authorize()
    const accessToken = authTokens.access_token

    // Send Notification to all tokens
    const results = []
    for (const token of tokens) {
      try {
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
                token: token,
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
                apns: {
                  payload: {
                    aps: {
                      alert: {
                        title: `New Order: Table ${payload.record.table_number}`,
                        body: `${payload.record.customer_name || 'Customer'} ordered ₹${payload.record.total}`,
                      },
                      sound: 'default',
                      badge: 1,
                    },
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
        console.log(`FCM Result for token ${token.substring(0, 10)}...:`, fcmResult)
        results.push({ token: token.substring(0, 10) + '...', result: fcmResult })

        // If token is invalid, clean it up
        if (fcmResult.error?.code === 404 || fcmResult.error?.details?.[0]?.errorCode === 'UNREGISTERED') {
          console.log('Removing invalid token:', token.substring(0, 10))
          await supabase.from('owner_fcm_tokens').delete().eq('token', token)
          // Also clear from restaurants table if it matches
          if (restaurant?.fcm_token === token) {
            await supabase.from('restaurants').update({ fcm_token: null }).eq('id', payload.record.restaurant_id)
          }
        }
      } catch (tokenError) {
        console.error(`Error sending to token ${token.substring(0, 10)}...:`, tokenError)
        results.push({ token: token.substring(0, 10) + '...', error: tokenError.message })
      }
    }

    return new Response(JSON.stringify({ sent_to: tokens.length, results }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('Error sending notification:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
