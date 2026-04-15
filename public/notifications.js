// ─────────────────────────────────────────────
//  GoDine  ·  Notification Module
//  Drop this file into your project root and
//  add <script src="notifications.js"></script>
//  in dashboard.html  BEFORE  your main script.
// ─────────────────────────────────────────────

const GoDineNotify = (() => {

  // ── 1.  AUDIO TONES  ──────────────────────────
  
  function playOrderTone() {
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      const notes = [
        { freq: 523.25, start: 0.00, dur: 0.35 },   // C5
        { freq: 659.25, start: 0.18, dur: 0.35 },   // E5
        { freq: 783.99, start: 0.36, dur: 0.65 },   // G5
      ];
      notes.forEach(({ freq, start, dur }) => {
        const osc = ctx.createOscillator();
        const gainNode = ctx.createGain();
        const now = ctx.currentTime;
        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, now + start);
        gainNode.gain.setValueAtTime(0, now + start);
        gainNode.gain.linearRampToValueAtTime(0.8, now + start + 0.04);
        gainNode.gain.exponentialRampToValueAtTime(0.001, now + start + dur);
        osc.connect(gainNode); gainNode.connect(ctx.destination);
        osc.start(now + start); osc.stop(now + start + dur);
      });
    } catch (e) {}
  }

  function playStatusTone() {
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      const osc = ctx.createOscillator();
      const gainNode = ctx.createGain();
      const now = ctx.currentTime;
      osc.type = 'sine';
      osc.frequency.setValueAtTime(880, now); // A5
      osc.frequency.exponentialRampToValueAtTime(1320, now + 0.1); // E6
      gainNode.gain.setValueAtTime(0.3, now);
      gainNode.gain.exponentialRampToValueAtTime(0.001, now + 0.15);
      osc.connect(gainNode); gainNode.connect(ctx.destination);
      osc.start(); osc.stop(now + 0.15);
    } catch (e) {}
  }


  // ── 2.  BROWSER NOTIFICATION  ────────────────

  function urlB64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding)
      .replace(/\-/g, '+')
      .replace(/_/g, '/');
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }

  async function requestPermission() {
    if (!('Notification' in window)) return false;
    if (Notification.permission === 'granted') return true;
    const result = await Notification.requestPermission();
    return result === 'granted';
  }

  async function registerWebPush(supabase, restaurantId) {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) return;
    
    try {
      const permission = await requestPermission();
      if (!permission) return;

      const registration = await navigator.serviceWorker.ready;
      
      // VAPID public key
      const applicationServerKey = urlB64ToUint8Array('BBt1ykJipLTVYA3IYu8l5TL5Rwp9lhMsUBfUJVJQMYOZL9S1jxwGifAb5GjfqgcrimpG-PhtIVyYcrxEM4Wy334');
      
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey
      });

      const subData = JSON.parse(JSON.stringify(subscription));

      // Save to Supabase (using UPSERT logic by checking existing first, or just inserting and handling duplicate)
      const { data: existing } = await supabase
        .from('web_push_subscriptions')
        .select('id')
        .eq('endpoint', subData.endpoint)
        .single();
        
      if (!existing) {
        await supabase.from('web_push_subscriptions').insert({
          restaurant_id: restaurantId,
          endpoint: subData.endpoint,
          p256dh: subData.keys.p256dh,
          auth: subData.keys.auth
        });
        console.log('[Web Push] Subscribed successfully');
      }

    } catch(e) {
      console.error('[Web Push] Subscription failed:', e);
    }
  }

  function showBrowserNotification(order, isUpdate = false) {
    if (Notification.permission !== 'granted') return;

    let title = `New Order  ·  Table ${order.table_number}`;
    let body = order.items ? order.items.map(i => `${i.quantity}× ${i.name}`).join(', ') : 'Click to view details';
    
    if (isUpdate) {
      title = `Status Update  ·  Table ${order.table_number}`;
      body = `Order is now marked as ${order.status.toUpperCase()}`;
    }

    const n = new Notification(title, { body, icon: '/favicon.ico', tag: isUpdate ? `update-${order.id}` : `order-${order.id}` });
    n.onclick = () => { window.focus(); n.close(); };
  }


  // ── 3.  IN-PAGE TOAST  ───────────────────────

  function injectToastStyles() {
    if (document.getElementById('gd-toast-styles')) return;
    const s = document.createElement('style');
    s.id = 'gd-toast-styles';
    s.textContent = `
      #gd-toast-container { position: fixed; bottom: 24px; right: 24px; display: flex; flex-direction: column; gap: 10px; z-index: 10000; pointer-events: none; }
      .gd-toast { background: #111; color: #fff; padding: 16px; border-radius: 14px; font-family: 'Manrope', sans-serif; font-size: 14px; min-width: 280px; max-width: 360px; box-shadow: 0 12px 40px rgba(0,0,0,0.5); pointer-events: all; animation: gd-slide-in 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275) forwards; border-left: 4px solid #b6ff2a; display: flex; align-items: flex-start; gap: 12px; }
      .gd-toast.update { border-left-color: #3b82f6; }
      .gd-toast-icon { font-size: 20px; }
      .gd-toast-content { flex: 1; }
      .gd-toast-title { font-weight: 800; margin-bottom: 2px; font-size: 15px; letter-spacing: -0.2px; }
      .gd-toast-body { opacity: 0.7; font-size: 12px; line-height: 1.4; font-weight: 500; }
      @keyframes gd-slide-in { from { opacity: 0; transform: translateX(40px) scale(0.9); } to { opacity: 1; transform: translateX(0) scale(1); } }
    `;
    document.head.appendChild(s);
    const wrap = document.createElement('div'); wrap.id = 'gd-toast-container'; document.body.appendChild(wrap);
  }

  function showToast(order, isUpdate = false) {
    injectToastStyles();
    const container = document.getElementById('gd-toast-container');
    const toast = document.createElement('div');
    toast.className = 'gd-toast' + (isUpdate ? ' update' : '');
    
    if (isUpdate) {
      const statusMap = { 'pending': 'Pending', 'preparing': 'Preparing', 'ready': 'READY!', 'completed': 'Completed', 'cancelled': 'Cancelled' };
      const statusText = statusMap[order.status] || order.status;
      toast.innerHTML = `
        <div class="gd-toast-icon">🔄</div>
        <div class="gd-toast-content">
          <div class="gd-toast-title">Table ${order.table_number}: Status Updated</div>
          <div class="gd-toast-body">Order is now: <b>${statusText}</b></div>
        </div>
      `;
    } else {
      const items = order.items ? order.items.map(i => `${i.qty || i.quantity}× ${i.name}`).join(', ') : 'New order received';
      toast.innerHTML = `
        <div class="gd-toast-icon">🛎️</div>
        <div class="gd-toast-content">
          <div class="gd-toast-title">New Order: Table ${order.table_number}</div>
          <div class="gd-toast-body">${items}</div>
        </div>
      `;
    }
    
    container.appendChild(toast);
    setTimeout(() => {
      toast.style.animation = 'gd-slide-in 0.4s reverse forwards';
      setTimeout(() => toast.remove(), 400);
    }, 6000);
  }


  // ── 4.  FIRE ALERTS  ─────────────────────────

  function fireNewOrder(order) {
    playOrderTone();
    showBrowserNotification(order, false);
    showToast(order, false);
  }

  function fireStatusUpdate(order) {
    playStatusTone();
    showToast(order, true);
  }


  // ── 5.  INIT  ────────────────────────────────

  function init(supabase, restaurantId, onUpdate) {
    registerWebPush(supabase, restaurantId);
    
    return supabase
      .channel(`godine-notify-${restaurantId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders', filter: `restaurant_id=eq.${restaurantId}` }, (payload) => {
        if (payload.eventType === 'INSERT') {
          fireNewOrder(payload.new);
          if (onUpdate) onUpdate(payload);
        } else if (payload.eventType === 'UPDATE') {
          if (payload.old.status !== payload.new.status) {
            fireStatusUpdate(payload.new);
          }
          if (onUpdate) onUpdate(payload);
        }
      })
      .subscribe();
  }

  return { init, fireNewOrder, fireStatusUpdate, playOrderTone, playStatusTone, requestPermission };

})();
