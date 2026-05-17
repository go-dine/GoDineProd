// ─────────────────────────────────────────────
//  GoDine  ·  Customer Notification Module
//  Drop in your project root and add:
//    <script src="customer-notifications.js"></script>
//  in customer.html / menu.html BEFORE your main script.
// ─────────────────────────────────────────────

const GoDineCustomer = (() => {

  // ── STATUS CONFIG  ────────────────────────────
  //  Each status gets its own message, emoji, tone, and color.

  const STATUS = {
    accepted: {
      title:   'Order Accepted!',
      body:    'The restaurant has received your order.',
      emoji:   '✅',
      color:   '#16a34a',
      tone:    'confirm',   // warm double-pulse
    },
    preparing: {
      title:   'Being Prepared',
      body:    'Your food is now being prepared in the kitchen.',
      emoji:   '👨‍🍳',
      color:   '#f97316',
      tone:    'busy',      // soft single mid-note
    },
    ready: {
      title:   'Ready to Serve!',
      body:    'Your order is ready. Enjoy your meal!',
      emoji:   '🍽️',
      color:   '#7c3aed',
      tone:    'fanfare',   // triumphant 4-note rise
    },
  };

  // Normalise incoming status strings to our keys
  function resolveStatus(raw) {
    if (!raw) return null;
    const s = raw.toLowerCase().trim();
    if (s === 'accepted'  || s === 'confirmed' || s === 'pending') return 'accepted';
    if (s === 'preparing' || s === 'in progress' || s === 'cooking') return 'preparing';
    if (s === 'ready'     || s === 'completed'   || s === 'done')    return 'ready';
    return null;
  }


  // ── 1.  TONES  ────────────────────────────────

  function playTone(type) {
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      const now = ctx.currentTime;

      const note = (freq, start, dur, peak = 0.7) => {
        const osc = ctx.createOscillator();
        const g   = ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, now + start);
        g.gain.setValueAtTime(0, now + start);
        g.gain.linearRampToValueAtTime(peak, now + start + 0.04);
        g.gain.setValueAtTime(peak * 0.85, now + start + 0.12);
        g.gain.exponentialRampToValueAtTime(0.001, now + start + dur);
        osc.connect(g);
        g.connect(ctx.destination);
        osc.start(now + start);
        osc.stop(now + start + dur);
      };

      if (type === 'confirm') {
        // Two warm pulses — "yes, we got you"
        note(659.25, 0.00, 0.25, 0.65);  // E5
        note(783.99, 0.22, 0.40, 0.70);  // G5
      }

      if (type === 'busy') {
        // Single soft mid-note with gentle decay
        note(587.33, 0.00, 0.45, 0.55);  // D5
      }

      if (type === 'fanfare') {
        // Triumphant 4-note rise — order is ready!
        note(523.25, 0.00, 0.22, 0.60);  // C5
        note(659.25, 0.18, 0.22, 0.65);  // E5
        note(783.99, 0.36, 0.22, 0.70);  // G5
        note(1046.5, 0.54, 0.55, 0.80);  // C6  ← big finish
        // shimmer on C6
        note(2093.0, 0.56, 0.50, 0.14);  // C7 overtone
      }

    } catch (e) {
      console.warn('[GoDine Customer] Audio error:', e);
    }
  }


  // ── 2.  BROWSER PUSH NOTIFICATION  ───────────

  async function requestPermission() {
    if (!('Notification' in window)) return false;
    if (Notification.permission === 'granted') return true;
    if (Notification.permission === 'denied')  return false;
    const result = await Notification.requestPermission();
    return result === 'granted';
  }

  // ── Web Push Registration ─────────────────────
  const VAPID_PUBLIC_KEY = 'BBt1ykJipLTVYA3IYu8l5TL5Rwp9lhMsUBfUJVJQMYOZL9S1jxwGifAb5GjfqgcrimpG-PhtIVyYcrxEM4Wy334';

  function urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding).replace(/\-/g, '+').replace(/_/g, '/');
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }

  async function registerWebPush(supabase, customerPhone) {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      console.warn('[GoDine Customer] Push not supported');
      return;
    }

    try {
      const permission = await requestPermission();
      if (!permission) return;

      const registration = await navigator.serviceWorker.ready;
      
      // Subscribe to Push
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY)
      });

      console.log('[GoDine Customer] Registered for Web Push');

      // Save to Supabase
      const { endpoint, keys } = subscription.toJSON();
      const { error } = await supabase
        .from('web_push_subscriptions')
        .upsert({
          endpoint: endpoint,
          p256dh: keys.p256dh,
          auth: keys.auth,
          customer_phone: customerPhone
        }, { onConflict: 'endpoint' });

      if (error) throw error;
      console.log('[GoDine Customer] Subscription synced to database');

    } catch (err) {
      console.error('[GoDine Customer] Push registration failed:', err);
    }
  }

  function showPush(statusKey, orderId) {
    if (Notification.permission !== 'granted') return;
    const cfg   = STATUS[statusKey];
    const title = `${cfg.emoji} ${cfg.title}`;
    const n = new Notification(title, {
      body:              cfg.body,
      icon:              '/favicon.ico',
      tag:               `order-status-${orderId}`,  // replaces previous notification for same order
      requireInteraction: statusKey === 'ready',      // stay on screen only when food is ready
    });
    n.onclick = () => { window.focus(); n.close(); };
  }


  // ── 3.  IN-PAGE STATUS BANNER  ────────────────
  //  A prominent banner at top of the customer menu page.

  function injectBannerStyles() {
    if (document.getElementById('gd-customer-styles')) return;
    const s = document.createElement('style');
    s.id = 'gd-customer-styles';
    s.textContent = `
      #gd-status-banner {
        position: fixed; top: 0; left: 0; right: 0;
        z-index: 9999;
        padding: 16px 24px;
        display: flex; align-items: center; gap: 14px;
        font-family: 'Space Grotesk', sans-serif;
        transform: translateY(-100%);
        transition: transform 0.4s cubic-bezier(0.16, 1, 0.3, 1);
        box-shadow: 0 8px 32px rgba(0,0,0,0.35);
        backdrop-filter: blur(12px);
        -webkit-backdrop-filter: blur(12px);
      }
      #gd-status-banner.show { transform: translateY(0); }
      #gd-status-banner .gd-banner-emoji { font-size: 24px; flex-shrink: 0; }
      #gd-status-banner .gd-banner-text  { flex: 1; }
      #gd-status-banner .gd-banner-title { font-weight: 800; font-size: 16px; color: #fff; letter-spacing: -0.3px; }
      #gd-status-banner .gd-banner-body  { font-size: 13px; color: rgba(255,255,255,0.9); margin-top: 3px; font-family: 'Manrope', sans-serif; font-weight: 500; }
      #gd-status-banner .gd-banner-close {
        color: rgba(255,255,255,0.8); font-size: 20px;
        cursor: pointer; padding: 4px; flex-shrink: 0;
        transition: color 0.2s;
      }
      #gd-status-banner .gd-banner-close:hover { color: #fff; }

      #gd-status-tracker {
        position: fixed; bottom: 24px; left: 50%; transform: translateX(-50%);
        background: rgba(15, 15, 25, 0.85);
        backdrop-filter: blur(16px);
        -webkit-backdrop-filter: blur(16px);
        border: 1px solid rgba(255, 255, 255, 0.08);
        color: #f0f0ec;
        border-radius: 40px; padding: 12px 28px;
        display: flex; align-items: center; gap: 18px;
        font-family: 'Space Grotesk', sans-serif; font-size: 13px; font-weight: 600;
        box-shadow: 0 8px 32px rgba(0,0,0,0.5), 0 0 20px rgba(182, 255, 42, 0.04);
        z-index: 9998; white-space: nowrap;
        transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
        opacity: 0;
      }
      
      .gd-step {
        display: flex; align-items: center; gap: 8px;
        opacity: 0.35; transition: all 0.4s ease;
        position: relative;
      }
      
      .gd-step-dot {
        width: 10px; height: 10px; border-radius: 50%;
        background: rgba(255, 255, 255, 0.3);
        transition: all 0.4s ease;
      }
      
      /* Active & Completed States */
      .gd-step.active {
        opacity: 1;
        text-shadow: 0 0 10px currentColor;
      }
      
      .gd-step.done {
        opacity: 0.7;
        color: #10b981;
      }
      
      .gd-step.done .gd-step-dot {
        background: #10b981;
        box-shadow: 0 0 8px rgba(16, 185, 129, 0.5);
      }
      
      /* Active specific styles */
      #gd-step-accepted.active {
        color: #10b981;
      }
      #gd-step-accepted.active .gd-step-dot {
        background: #10b981;
        box-shadow: 0 0 12px #10b981;
        animation: gd-pulse-green 1.5s infinite alternate;
      }
      
      #gd-step-preparing.active {
        color: #f59e0b;
      }
      #gd-step-preparing.active .gd-step-dot {
        background: #f59e0b;
        box-shadow: 0 0 12px #f59e0b;
        animation: gd-pulse-amber 1.5s infinite alternate;
      }
      
      #gd-step-ready.active {
        color: #b6ff2a;
      }
      #gd-step-ready.active .gd-step-dot {
        background: #b6ff2a;
        box-shadow: 0 0 16px #b6ff2a;
        animation: gd-pulse-lime 1.5s infinite alternate;
      }

      /* Pulse Keyframe Animations */
      @keyframes gd-pulse-green {
        0% { transform: scale(1); box-shadow: 0 0 6px rgba(16, 185, 129, 0.4); }
        100% { transform: scale(1.3); box-shadow: 0 0 16px rgba(16, 185, 129, 0.8); }
      }
      @keyframes gd-pulse-amber {
        0% { transform: scale(1); box-shadow: 0 0 6px rgba(245, 158, 11, 0.4); }
        100% { transform: scale(1.3); box-shadow: 0 0 16px rgba(245, 158, 11, 0.8); }
      }
      @keyframes gd-pulse-lime {
        0% { transform: scale(1); box-shadow: 0 0 8px rgba(182, 255, 42, 0.5); }
        100% { transform: scale(1.3); box-shadow: 0 0 20px rgba(182, 255, 42, 1); }
      }
      
      .gd-divider {
        opacity: 0.15;
        color: #f0f0ec;
        margin: 0 4px;
        font-weight: 300;
      }
    `;
    document.head.appendChild(s);

    // Banner element
    if (!document.getElementById('gd-status-banner')) {
      const banner = document.createElement('div');
      banner.id = 'gd-status-banner';
      banner.innerHTML = `
        <span class="gd-banner-emoji" id="gd-b-emoji"></span>
        <div class="gd-banner-text">
          <div class="gd-banner-title" id="gd-b-title"></div>
          <div class="gd-banner-body"  id="gd-b-body"></div>
        </div>
        <span class="gd-banner-close" onclick="document.getElementById('gd-status-banner').classList.remove('show')">✕</span>
      `;
      document.body.appendChild(banner);
    }

    // Step tracker pill at bottom
    if (!document.getElementById('gd-status-tracker')) {
      const tracker = document.createElement('div');
      tracker.id = 'gd-status-tracker';
      tracker.innerHTML = `
        <div class="gd-step" id="gd-step-accepted">
          <div class="gd-step-dot"></div><span>Accepted</span>
        </div>
        <span class="gd-divider">──</span>
        <div class="gd-step" id="gd-step-preparing">
          <div class="gd-step-dot"></div><span>Preparing</span>
        </div>
        <span class="gd-divider">──</span>
        <div class="gd-step" id="gd-step-ready">
          <div class="gd-step-dot"></div><span>Ready</span>
        </div>
      `;
      document.body.appendChild(tracker);
    }
  }

  const stepOrder = ['accepted', 'preparing', 'ready'];

  function updateTracker(currentKey) {
    const tracker = document.getElementById('gd-status-tracker');
    if (!tracker) return;

    if (currentKey === 'completed' || currentKey === 'cancelled') {
      tracker.style.opacity = '0';
      setTimeout(() => { tracker.style.display = 'none'; }, 400);
      return;
    } else {
      tracker.style.display = 'flex';
      setTimeout(() => { tracker.style.opacity = '1'; }, 50);
    }

    const idx = stepOrder.indexOf(currentKey);
    stepOrder.forEach((key, i) => {
      const el = document.getElementById(`gd-step-${key}`);
      if (!el) return;
      el.classList.remove('active', 'done');
      if (i < idx)  el.classList.add('done');
      if (i === idx) el.classList.add('active');
    });
  }

  function showBanner(statusKey) {
    injectBannerStyles();
    const cfg    = STATUS[statusKey];
    const banner = document.getElementById('gd-status-banner');
    if (!banner) return;
    document.getElementById('gd-b-emoji').textContent = cfg.emoji;
    document.getElementById('gd-b-title').textContent = cfg.title;
    document.getElementById('gd-b-body').textContent  = cfg.body;
    banner.style.background = cfg.color;
    banner.classList.add('show');
    updateTracker(statusKey);
    if (statusKey !== 'ready') {
      setTimeout(() => banner.classList.remove('show'), 6000);
    }
  }


  // ── 4.  FIRE EVERYTHING  ─────────────────────

  function fireCustomerAlert(statusKey, orderId) {
    const key = resolveStatus(statusKey);
    if (!key) return;
    playTone(STATUS[key].tone);
    showPush(key, orderId);
    showBanner(key);
  }


  // ── 5.  SUPABASE REALTIME LISTENER  ──────────
  //  Call GoDineCustomer.init(supabaseClient, orderId)
  //  after the customer places an order.

  function init(supabase, orderId) {
    requestPermission();
    injectBannerStyles();

    // 1. Fetch order details to get initial status and customer phone for push targeting
    supabase.from('orders').select('status, customer_phone').eq('id', orderId).single().then(({data}) => {
      if (data) {
        if (data.customer_phone) {
          registerWebPush(supabase, data.customer_phone);
        }
        const resolved = resolveStatus(data.status);
        if (resolved) {
          updateTracker(resolved);
        }
      }
    });

    const channel = supabase.channel(`customer-order-${orderId}`);
    
    channel.on(
        'postgres_changes',
        {
          event:  'UPDATE',
          schema: 'public',
          table:  'orders',
          filter: `id=eq.${orderId}`,
        },
        (payload) => {
          const newStatus = payload.new.status;
          console.log('[GoDine Customer] Status update:', newStatus);
          fireCustomerAlert(newStatus, orderId);
          
          // Auto-unsubscribe when finished to prevent leakage
          if (newStatus === 'completed' || newStatus === 'cancelled') {
            console.log('[GoDine Customer] Order finished. Unsubscribing.');
            channel.unsubscribe();
          }
        }
      )
      .subscribe();
      
    return channel;
  }

  // ── PUBLIC API  ───────────────────────────────
  return { init, fireCustomerAlert, playTone, requestPermission };

})();
