// GoDine Service Worker — Background Notifications
// This enables system-level notifications even when the dashboard tab is in the background

const CACHE_NAME = 'godine-sw-v1';

// Install event
self.addEventListener('install', event => {
  self.skipWaiting();
});

// Activate event
self.addEventListener('activate', event => {
  event.waitUntil(self.clients.claim());
});

// Handle notification click — focus the dashboard tab or open it
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clients => {
      // Focus existing dashboard tab if found
      for (const client of clients) {
        if (client.url.includes('/dashboard') && 'focus' in client) {
          return client.focus();
        }
      }
      // Otherwise open a new tab
      return self.clients.openWindow('/dashboard');
    })
  );
});

// Handle push events (for future FCM Web Push integration)
self.addEventListener('push', event => {
  let data = { title: 'GoDine', body: 'New notification' };
  try {
    if (event.data) {
      data = event.data.json();
    }
  } catch (e) {
    if (event.data) {
      data.body = event.data.text();
    }
  }

  event.waitUntil(
    self.registration.showNotification(data.title || 'GoDine', {
      body: data.body || 'You have a new notification',
      icon: 'https://cdn-icons-png.flaticon.com/512/3500/3500833.png',
      badge: 'https://cdn-icons-png.flaticon.com/512/3500/3500833.png',
      vibrate: [200, 100, 200],
      tag: 'godine-push-' + Date.now(),
      renotify: true
    })
  );
});
