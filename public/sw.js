// GoDine Service Worker — Background & Push Notifications
// Enables system-level notifications even when the dashboard tab is closed

const CACHE_NAME = 'godine-sw-v2';

// Install — immediately take over
self.addEventListener('install', event => {
  self.skipWaiting();
});

// Activate — claim all open clients
self.addEventListener('activate', event => {
  event.waitUntil(self.clients.claim());
});

// ── PUSH EVENT ──────────────────────────────────
// Triggered by Web Push API (VAPID) from our edge function
self.addEventListener('push', event => {
  let data = { title: 'GoDine', body: 'New notification', data: {} };
  
  try {
    if (event.data) {
      const parsed = event.data.json();
      data = { ...data, ...parsed };
    }
  } catch (e) {
    if (event.data) {
      data.body = event.data.text();
    }
  }

  // Determine icon and badge based on notification type
  const isWaiterCall = data.data?.type === 'waiter_call';
  const isOrder = data.data?.type === 'new_order';

  const options = {
    body: data.body || 'You have a new notification',
    icon: 'https://cdn-icons-png.flaticon.com/512/3500/3500833.png',
    badge: 'https://cdn-icons-png.flaticon.com/512/3500/3500833.png',
    vibrate: isWaiterCall ? [300, 100, 300, 100, 300] : [200, 100, 200],
    tag: isWaiterCall ? 'godine-waiter-' + (data.data?.table_number || Date.now()) 
       : isOrder ? 'godine-order-' + Date.now()
       : 'godine-push-' + Date.now(),
    renotify: true,
    requireInteraction: true, // Keep notification visible until user interacts
    data: data.data || {},
    actions: isWaiterCall ? [
      { action: 'view', title: 'View Dashboard' },
      { action: 'dismiss', title: 'Dismiss' }
    ] : isOrder ? [
      { action: 'view', title: 'View Order' },
    ] : []
  };

  event.waitUntil(
    self.registration.showNotification(data.title || 'GoDine', options)
  );
});

// ── NOTIFICATION CLICK ──────────────────────────
// Focus existing dashboard tab or open a new one
self.addEventListener('notificationclick', event => {
  event.notification.close();

  if (event.action === 'dismiss') return;

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clients => {
      // Focus existing dashboard tab if found
      for (const client of clients) {
        if (client.url.includes('dashboard') && 'focus' in client) {
          return client.focus();
        }
      }
      // Otherwise open a new tab
      return self.clients.openWindow('/dashboard.html');
    })
  );
});

// ── NOTIFICATION CLOSE ──────────────────────────
self.addEventListener('notificationclose', event => {
  // Analytics hook — could log dismissed notifications
});
