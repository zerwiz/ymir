/**
 * ember.js — the hearth, in one place.
 *
 * The fire that warms Sessrúmnir's chat came from the landing page's hero
 * (Ginnungagap): embers rising slowly with a gentle sway, over a few drifting
 * haze pools. Sessrúmnir carries a React port; this is the framework-neutral
 * original, so every surface can share one fire instead of four copies.
 *
 *   import { startEmbers } from '.../midgard/design-system/ember.js'
 *   const stop = startEmbers(document.querySelector('[data-ember]'))
 *
 * Or simply mark an element and let it find its own:
 *
 *   <canvas data-ember></canvas>
 *   <script type="module" src="/ember.js"></script>
 *
 * It is decorative: the canvas is given `pointer-events: none` and
 * `aria-hidden`, and a reader who has asked their machine for less motion gets a
 * still, single-frame hearth instead of an animation.
 */

const EMBERS = 30;
const HAZE = 6;
const EMBER_RGB = '236,166,84';
const HAZE_RGB = '214,138,64';

/** Draw one still frame — also the whole effect under reduced motion. */
function paint(ctx, W, H, embers, haze) {
  ctx.clearRect(0, 0, W, H);
  for (const ha of haze) {
    const g = ctx.createRadialGradient(ha.x, ha.y, 0, ha.x, ha.y, ha.r);
    g.addColorStop(0, `rgba(${HAZE_RGB},0.030)`);
    g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(ha.x, ha.y, ha.r, 0, 6.283);
    ctx.fill();
  }
  for (const e of embers) {
    ctx.fillStyle = `rgba(${EMBER_RGB},${e.a.toFixed(3)})`;
    ctx.beginPath();
    ctx.arc(e.x, e.y, e.r, 0, 6.283);
    ctx.fill();
  }
}

function seed(W, H) {
  const embers = [];
  for (let i = 0; i < EMBERS; i++) {
    embers.push({
      x: Math.random() * W,
      y: H + Math.random() * H * 0.3 - 6,
      r: 1.0 + Math.random() * 1.6,
      v: 0.14 + Math.random() * 0.34,
      ph: Math.random() * 6.28,
      sp: 0.6 + Math.random() * 1.4,
      a: 0.26,
    });
  }
  const haze = [];
  for (let i = 0; i < HAZE; i++) {
    haze.push({ x: Math.random() * W, y: H * 0.3 + Math.random() * H * 0.7, r: 130 + Math.random() * 170, v: (Math.random() - 0.5) * 0.15 });
  }
  return { embers, haze };
}

/**
 * Start the hearth on <host>. Returns a stop function. Safe to call on a host
 * that has no box yet (it simply draws nothing until it has one).
 */
export function startEmbers(host) {
  if (!host) return () => {};
  const canvas = host.tagName === 'CANVAS' ? host : document.createElement('canvas');
  if (canvas !== host) {
    canvas.style.position = 'absolute';
    canvas.style.inset = '0';
    host.appendChild(canvas);
  }
  canvas.setAttribute('aria-hidden', 'true');
  canvas.style.pointerEvents = 'none';

  const ctx = canvas.getContext('2d');
  if (!ctx) return () => {};

  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  let W = 0;
  let H = 0;
  let t = 0;
  let raf = 0;
  let { embers, haze } = seed(1, 1);

  const reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true;

  function size() {
    const rect = canvas.getBoundingClientRect();
    W = rect.width || canvas.clientWidth || 0;
    H = rect.height || canvas.clientHeight || 0;
    canvas.width = Math.max(1, W * dpr);
    canvas.height = Math.max(1, H * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function reseed() {
    ({ embers, haze } = seed(W, H));
    if (reduced) {
      for (const e of embers) e.a = 0.3 + 0.4 * Math.random();
      paint(ctx, W, H, embers, haze);
    }
  }

  function frame() {
    t += 0.016;
    for (const ha of haze) {
      ha.x += ha.v;
      if (ha.x < -ha.r) ha.x = W + ha.r;
      if (ha.x > W + ha.r) ha.x = -ha.r;
    }
    for (const e of embers) {
      e.y -= e.v;
      e.x += Math.sin(t * e.sp + e.ph) * 0.18;
      if (e.y < -6) {
        e.y = H + 6;
        e.x = Math.random() * W;
      }
      e.a = 0.26 + 0.4 * (0.5 + 0.5 * Math.sin(t * e.sp * 2 + e.ph));
    }
    paint(ctx, W, H, embers, haze);
  }

  function loop() {
    frame();
    raf = requestAnimationFrame(loop);
  }

  size();
  reseed();
  if (!reduced) raf = requestAnimationFrame(loop);

  const onResize = () => {
    size();
    reseed();
  };
  window.addEventListener('resize', onResize);

  // The hearth warms a *container*, and containers change without a window
  // resize (a split pane, a toggled sidebar). Watch the host: re-size and
  // re-seed only when its dimensions actually changed, never per-frame.
  let ro = null;
  if (typeof ResizeObserver !== 'undefined' && canvas.parentElement) {
    const host = canvas.parentElement;
    let lastW = 0;
    let lastH = 0;
    ro = new ResizeObserver((entries) => {
      const e = entries[0];
      if (!e) return;
      const w = e.contentRect?.width ?? e.contentBoxSize?.[0]?.inlineSize ?? 0;
      const h = e.contentRect?.height ?? e.contentBoxSize?.[0]?.blockSize ?? 0;
      if (Math.abs(w - lastW) > 0.5 || Math.abs(h - lastH) > 0.5) {
        lastW = w;
        lastH = h;
        onResize();
      }
    });
    ro.observe(host);
  }

  return () => {
    if (raf) cancelAnimationFrame(raf);
    window.removeEventListener('resize', onResize);
    if (ro) ro.disconnect();
  };
}

/** Every element marked `data-ember` lights its own hearth. */
export function startAllEmbers(root = document) {
  return Array.from(root.querySelectorAll('[data-ember]')).map(startEmbers);
}

if (typeof document !== 'undefined') {
  const boot = () => startAllEmbers();
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot, { once: true });
  else boot();
}
