import os

path = r'c:\Users\Aditya Pandey\Downloads\Go Dine\godine-project\index.html'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove Live Demo from footer
old_footer = '''        <a href="#features" style="font-size:13px; color:var(--muted);">Features</a>
        <a href="#pricing" style="font-size:13px; color:var(--muted);">Pricing</a>
        <a href="menu.html?r=demo&table=demo" style="font-size:13px; color:var(--muted);">Live Demo</a>
      </div>'''
new_footer = '''        <a href="#features" style="font-size:13px; color:var(--muted);">Features</a>
        <a href="#pricing" style="font-size:13px; color:var(--muted);">Pricing</a>
      </div>'''

content = content.replace(old_footer, new_footer)

# 2. Fix Script (Replace everything from /* ── Custom Cursor ── */ to the end)
script_start_marker = "/* ── Custom Cursor ── */"
script_end_marker = "</script>"

script_start_idx = content.find(script_start_marker)
script_end_idx = content.find(script_end_marker, script_start_idx)

if script_start_idx != -1 and script_end_idx != -1:
    clean_script = r'''/* ── Custom Cursor ── */
const cur = document.getElementById('cursor');
const ring = document.getElementById('cursor-ring');
let mx = 0, my = 0, rx = 0, ry = 0;
document.addEventListener('mousemove', e => { mx = e.clientX; my = e.clientY; cur.style.left = mx + 'px'; cur.style.top = my + 'px'; });
(function animRing() { rx += (mx - rx) * 0.12; ry += (my - ry) * 0.12; ring.style.left = rx + 'px'; ring.style.top = ry + 'px'; requestAnimationFrame(animRing); })();
document.querySelectorAll('a,button').forEach(el => {
  el.addEventListener('mouseenter', () => { ring.style.width = '48px'; ring.style.height = '48px'; ring.style.borderColor = 'rgba(182,255,42,.7)'; cur.style.opacity = '0'; });
  el.addEventListener('mouseleave', () => { ring.style.width = '32px'; ring.style.height = '32px'; ring.style.borderColor = 'rgba(182,255,42,.4)'; cur.style.opacity = '1'; });
});

/* ── Particle Network ── */
const canvas = document.getElementById('particleCanvas');
if (canvas) {
  const ctx = canvas.getContext('2d');
  let W, H;
  const particles = [];
  function resizeCanvas() { W = canvas.width = window.innerWidth; H = canvas.height = window.innerHeight; }
  resizeCanvas();
  window.addEventListener('resize', resizeCanvas);
  class Particle {
    constructor() { this.reset(); }
    reset() {
      this.x = Math.random() * W; this.y = Math.random() * H;
      this.vx = (Math.random() - 0.5) * 0.3; this.vy = (Math.random() - 0.5) * 0.3;
      this.alpha = Math.random() * 0.4 + 0.1; this.radius = Math.random() * 1.5 + 0.5;
      this.phase = Math.random() * Math.PI * 2;
    }
    update() {
      this.x += this.vx; this.y += this.vy;
      this.phase += 0.02; this.alpha = 0.08 + 0.12 * Math.sin(this.phase);
      if (this.x < 0 || this.x > W || this.y < 0 || this.y > H) this.reset();
    }
    draw() {
      ctx.beginPath(); ctx.arc(this.x, this.y, this.radius, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(182,255,42,${this.alpha})`; ctx.fill();
    }
  }
  for (let i = 0; i < 80; i++) particles.push(new Particle());
  (function particleLoop() {
    ctx.clearRect(0, 0, W, H);
    particles.forEach(p => { p.update(); p.draw(); });
    for (let i = 0; i < particles.length; i++) {
      for (let j = i + 1; j < particles.length; j++) {
        const dx = particles[i].x - particles[j].x, dy = particles[i].y - particles[j].y;
        const d = Math.sqrt(dx * dx + dy * dy);
        if (d < 120) {
          ctx.beginPath(); ctx.moveTo(particles[i].x, particles[i].y); ctx.lineTo(particles[j].x, particles[j].y);
          ctx.strokeStyle = `rgba(182,255,42,${0.07 * (1 - d / 120)})`; ctx.lineWidth = 0.5; ctx.stroke();
        }
      }
    }
    requestAnimationFrame(particleLoop);
  })();
}

/* ── Scroll Reveal ── */
const observer = new IntersectionObserver(entries => entries.forEach(e => {
  if (e.isIntersecting) { e.target.classList.add('in'); observer.unobserve(e.target); }
}), { threshold: 0.1 });
document.querySelectorAll('.reveal').forEach(el => observer.observe(el));

/* ── Interactive Steps ── */
document.querySelectorAll('.hw-step').forEach(s => s.addEventListener('click', () => {
  document.querySelectorAll('.hw-step').forEach(x => x.classList.remove('active'));
  s.classList.add('active');
}));

/* ── Decorative QR Canvas ── */
(function drawQR() {
  const c = document.getElementById('qr-canvas');
  if (!c) return;
  const x = c.getContext('2d');
  const sz = 160, cell = Math.floor(sz / 11), pad = Math.floor((sz - cell * 11) / 2);
  const grid = [
    [1,1,1,1,1,1,1,0,0,1,0], [1,0,0,0,0,0,1,0,1,0,1], [1,0,1,1,1,0,1,0,0,1,0],
    [1,0,1,1,1,0,1,0,1,1,0], [1,0,1,1,1,0,1,0,0,0,1], [1,0,0,0,0,0,1,0,1,0,0],
    [1,1,1,1,1,1,1,0,1,0,1], [0,0,0,0,0,0,0,0,0,1,0], [1,0,1,1,0,1,0,1,1,0,1],
    [0,1,0,0,1,0,0,0,1,0,1], [1,0,1,0,1,1,1,0,0,1,0]
  ];
  grid.forEach((row, i) => row.forEach((v, j) => {
    if (v) { 
      x.fillStyle = 'rgba(182,255,42,.9)'; 
      x.beginPath(); 
      const rx = pad + j * cell + 1, ry = pad + i * cell + 1, rw = cell - 2, rh = cell - 2;
      if (x.roundRect) x.roundRect(rx, ry, rw, rh, 2); else x.rect(rx, ry, rw, rh);
      x.fill(); 
    }
  }));
})();

/* ── Onboarding & Login Logic ── */
let currentStep = 1;
let selectedPlanId = 2;

function openOnboarding(initialPlanId) {
  if (initialPlanId) { selectedPlanId = initialPlanId; updatePlanUI(); }
  const bg = document.getElementById('modal-bg');
  const obModal = document.getElementById('onboarding-modal');
  const loginModal = document.getElementById('login-modal');
  if(bg) bg.classList.add('open');
  if(obModal) obModal.classList.add('active');
  if(loginModal) loginModal.classList.remove('active');
  showStep(1);
}

function openLogin() {
  const bg = document.getElementById('modal-bg');
  const loginModal = document.getElementById('login-modal');
  const obModal = document.getElementById('onboarding-modal');
  if(bg) bg.classList.add('open');
  if(loginModal) loginModal.classList.add('active');
  if(obModal) obModal.classList.remove('active');
}

function closeModals() {
  const bg = document.getElementById('modal-bg');
  const obModal = document.getElementById('onboarding-modal');
  const loginModal = document.getElementById('login-modal');
  if(bg) bg.classList.remove('open');
  if(obModal) obModal.classList.remove('active');
  if(loginModal) loginModal.classList.remove('active');
}

function showStep(s) {
  currentStep = s;
  document.querySelectorAll('.ob-body').forEach(b => b.classList.remove('active'));
  const stepEl = document.getElementById('step-' + s);
  if (stepEl) stepEl.classList.add('active');
  
  const titles = ["Restaurant Profile", "Menu Settings", "Security", "Select Plan"];
  const descs = ["Basic info to set up your store.", "How your customers will see your menu.", "Your admin login credentials.", "Choose a plan to grow your business."];
  
  const sn = document.getElementById('step-num');
  const st = document.getElementById('step-title');
  const sd = document.getElementById('step-desc');
  const backBtn = document.getElementById('ob-back');
  const nextTxt = document.getElementById('next-text');

  if(sn) sn.textContent = s;
  if(st) st.textContent = titles[s-1];
  if(sd) sd.textContent = descs[s-1];
  if(backBtn) backBtn.style.display = s === 1 ? 'none' : 'block';
  if(nextTxt) nextTxt.textContent = s === 4 ? 'Complete Setup' : 'Continue';
  if(s === 4) updatePlanUI();
}

function nextStep() {
  if (currentStep < 4) {
    if (currentStep === 1 && !document.getElementById('ob-name').value) { alert("Please enter restaurant name."); return; }
    if (currentStep === 3 && (!document.getElementById('ob-email').value || document.getElementById('ob-password').value.length < 6)) {
      alert("Please enter a valid email and password (min 6 chars)."); return;
    }
    showStep(currentStep + 1);
  } else { handleComplete(); }
}

function backStep() { if (currentStep > 1) showStep(currentStep - 1); }

function selectPlan(id, el) {
  selectedPlanId = id;
  if (el) {
    document.querySelectorAll('.price-card').forEach(c => c.classList.remove('selected'));
    el.classList.add('selected');
  }
}

function updatePlanUI() {
  document.querySelectorAll('.price-card').forEach((c, index) => {
    if (index + 1 === selectedPlanId) c.classList.add('selected');
    else c.classList.remove('selected');
  });
}

async function handleComplete() {
  const nameVal = document.getElementById('ob-name').value;
  const locationVal = document.getElementById('ob-location').value;
  const currencyVal = document.getElementById('ob-currency').value;
  const slugVal = document.getElementById('ob-slug').value || nameVal.toLowerCase().replace(/\s+/g, '-');
  const emailVal = document.getElementById('ob-email').value;
  const passwordVal = document.getElementById('ob-password').value;

  const btn = document.getElementById('ob-next');
  if(btn) {
    btn.disabled = true;
    btn.innerHTML = '<span>Setting up...</span>';
  }

  try {
    if (typeof supabase === 'undefined' || !CONFIG.supabaseUrl) throw new Error("Database configuration missing.");
    const sbClient = supabase.createClient(CONFIG.supabaseUrl, CONFIG.supabaseKey);

    const { data: rest, error: restErr } = await sbClient.from('restaurants').insert({
      name: nameVal,
      slug: slugVal,
      owner_email: emailVal,
      settings: { currency: currencyVal, plan: selectedPlanId, location: locationVal }
    }).select().single();

    if (restErr) throw restErr;
    localStorage.setItem('godine_session', JSON.stringify({ restaurant_id: rest.id, slug: rest.slug, name: rest.name }));
    alert("Registration successful! Redirecting to your dashboard...");
    window.location.href = "dashboard.html";
  } catch(e) {
    alert("Error: " + e.message);
    if (btn) {
      btn.disabled = false;
      btn.innerHTML = '<span>Complete Setup</span> <i data-lucide="chevron-right" style="width:18px;height:18px"></i>';
      lucide.createIcons();
    }
  }
}

async function completeLogin() {
   const ident = document.getElementById('login-ident').value.trim();
   const pass = document.getElementById('login-pass').value;
   if (!ident || !pass) { alert("Please enter credentials."); return; }
   try {
     const sbClient = supabase.createClient(CONFIG.supabaseUrl, CONFIG.supabaseKey);
     const { data: rest, error } = await sbClient.from('restaurants').select('*').or(`slug.eq."${ident}",owner_email.eq."${ident}"`).single();
     if (error || !rest) { alert("Restaurant not found."); return; }
     localStorage.setItem('godine_session', JSON.stringify({ restaurant_id: rest.id, slug: rest.slug, name: rest.name }));
     window.location.href = "dashboard.html";
   } catch(e) { alert("Login failed: " + e.message); }
}

lucide.createIcons();
'''
    content = content[:script_start_idx] + clean_script + content[script_end_idx:]

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
