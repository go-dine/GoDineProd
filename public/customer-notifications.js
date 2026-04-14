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
        padding: 14px 20px;
        display: flex; align-items: center; gap: 12px;
        font-family: sans-serif;
        transform: translateY(-100%);
        transition: transform 0.35s cubic-bezier(0.34, 1.56, 0.64, 1);
        box-shadow: 0 4px 16px rgba(0,0,0,0.18);
      }
      #gd-status-banner.show { transform: translateY(0); }
      #gd-status-banner .gd-banner-emoji { font-size: 22px; flex-shrink: 0; }
      #gd-status-banner .gd-banner-text  { flex: 1; }
      #gd-status-banner .gd-banner-title { font-weight: 700; font-size: 15px; color: #fff; }
      #gd-status-banner .gd-banner-body  { font-size: 13px; color: rgba(255,255,255,0.85); margin-top: 2px; }
      #gd-status-banner .gd-banner-close {
        color: rgba(255,255,255,0.7); font-size: 18px;
        cursor: pointer; padding: 4px; flex-shrink: 0;
      }
      #gd-status-tracker {
        position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%);
        background: #1a1a2e; color: #fff;
        border-radius: 40px; padding: 10px 20px;
        display: flex; align-items: center; gap: 16px;
        font-family: sans-serif; font-size: 13px;
        box-shadow: 0 4px 20px rgba(0,0,0,0.3);
        z-index: 9998; white-space: nowrap;
        transition: opacity 0.3s;
      }
      .gd-step {
        display: flex; align-items: center; gap: 5px;
        opacity: 0.35; transition: opacity 0.4s;
      }
      .gd-step.active  { opacity: 1; }
      .gd-step.done    { opacity: 0.6; }
      .gd-step-dot {
        width: 8px; height: 8px; border-radius: 50%;
        background: #fff;
      }
      .gd-step.active .gd-step-dot { background: #f97316; }
      .gd-divider { opacity: 0.25; }
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
