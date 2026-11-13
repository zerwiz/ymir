import { useEffect, useRef } from 'react'

interface EmberBackgroundProps {
  className?: string
}

/**
 * EmberBackground — Sessrúmnir's ONE hearth: the landing's fire and the chat column's.
 *
 * The same little fire-dots that fly around the landing's hero (Ginnungagap):
 * 30 embers rise slowly with a gentle sway, seeded fresh on any resize, drawn
 * on one canvas behind the column. Purely decorative — pointer-events none,
 * aria-hidden, subtle enough that text stays the master of the room.
 *
 * ONE IMPLEMENTATION, ON PURPOSE (plan 283, 2026-11-13). Until tonight this app carried
 * three hearths — this one, a dead `EmberBackground.tsx` twin and a dark copy of
 * `midgard/design-system/ember.js` — so every repair landed in a file the other two did
 * not read and the fire "came back broken" after being fixed. The other apps keep using
 * the shared module; this app keeps this port, and it is the only file to change.
 */
export function EmberBackground({ className = '' }: EmberBackgroundProps): React.JSX.Element {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const el = canvasRef.current
    if (!el) return
    const ctx = el.getContext('2d')
    if (!ctx) return
    const canvas: HTMLCanvasElement = el
    const context: CanvasRenderingContext2D = ctx
    const host = canvas.parentElement
    const dpr = Math.min(window.devicePixelRatio || 1, 2)
    let W = 0
    let H = 0
    let embers: Array<{ x: number; y: number; r: number; v: number; ph: number; sp: number }> = []
    let haze: Array<{ x: number; y: number; r: number; v: number }> = []
    let t = 0

    function size() {
      if (!host) return
      const rect = host.getBoundingClientRect()
      W = rect.width
      H = rect.height
      canvas.width = Math.max(1, W * dpr)
      canvas.height = Math.max(1, H * dpr)
      context.setTransform(dpr, 0, 0, dpr, 0, 0)
    }
    // The fire rises FROM THE FLOOR (his words, 2026-11-13: "the chat dont have it from
    // the bottom"). It used to be seeded entirely BELOW the bottom edge, so a cold view
    // showed an empty room for the seconds it takes one ember to climb into sight, and a
    // view that is shown for a moment showed nothing at all. Half the fire now starts
    // inside the lower half of the column — densest at the floor — and the rest waits
    // just under it, so the hearth is alight on the first painted frame and keeps rising.
    function init() {
      embers = []
      haze = []
      const total = 30
      const alight = Math.ceil(total * 0.5)
      for (let i = 0; i < total; i++) {
        embers.push({
          x: Math.random() * W,
          y: i < alight ? H * (0.45 + Math.random() * 0.55) : H + Math.random() * 36,
          r: 1.0 + Math.random() * 1.6,
          v: 0.18 + Math.random() * 0.42,
          ph: Math.random() * 6.28,
          sp: 0.6 + Math.random() * 1.4,
        })
      }
      for (let i = 0; i < 6; i++) {
        haze.push({
          x: Math.random() * W,
          y: H - Math.random() * Math.min(H * 0.28, 240),
          r: 130 + Math.random() * 170,
          v: (Math.random() - 0.5) * 0.15,
        })
      }
    }
    function frame() {
      t += 0.016
      context.clearRect(0, 0, W, H)
      for (const ha of haze) {
        ha.x += ha.v
        if (ha.x < -ha.r) ha.x = W + ha.r
        if (ha.x > W + ha.r) ha.x = -ha.r
        const g = context.createRadialGradient(ha.x, ha.y, 0, ha.x, ha.y, ha.r)
        g.addColorStop(0, 'rgba(214,138,64,0.030)')
        g.addColorStop(1, 'rgba(0,0,0,0)')
        context.fillStyle = g
        context.beginPath()
        context.arc(ha.x, ha.y, ha.r, 0, 6.283)
        context.fill()
      }
      for (const e of embers) {
        e.y -= e.v
        e.x += Math.sin(t * e.sp + e.ph) * 0.18
        if (e.y < -6) {
          e.y = H + 6
          e.x = Math.random() * W
        }
        const a = 0.26 + 0.4 * (0.5 + 0.5 * Math.sin(t * e.sp * 2 + e.ph))
        context.fillStyle = 'rgba(236,166,84,' + a.toFixed(3) + ')'
        context.beginPath()
        context.arc(e.x, e.y, e.r, 0, 6.283)
        context.fill()
      }
    }
    function loop() {
      frame()
      raf = requestAnimationFrame(loop)
    }
    let raf = 0
    let timer: ReturnType<typeof setInterval> | null = null
    function onResize() {
      size()
      init()
      // Resizing the buffer CLEARS the canvas; draw once here so a pane split or a
      // panel toggle never leaves one blank frame of cold hearth.
      frame()
    }
    // A canvas that mounts before its column has a box — the chat is mounted while the
    // landing shows — stayed at the 1x1 it was sized to, and only a window resize could
    // ever mend it. That is why the chat had no fire at all on 2026-11-13 while the landing
    // did. So: size now, and if there is no box yet ask again every 250 ms until there is.
    // Nothing is ever drawn into a single pixel again.
    function begin(): boolean {
      size()
      if (W < 2 || H < 2) return false
      if (timer) {
        clearInterval(timer)
        timer = null
      }
      init()
      frame()
      raf = requestAnimationFrame(loop)
      return true
    }
    if (!begin()) timer = setInterval(begin, 250)
    window.addEventListener('resize', onResize)
    // The host is usually mounted HIDDEN (the app keeps the chat mounted while another
    // view shows), so at mount its rect is 0x0, the canvas was sized 1x1, and the embers
    // were drawn into a single pixel for the whole session — only a window resize could
    // ever have fixed it. Observing the HOST re-sizes the moment the room is shown. The
    // hearth warms the chat column *and* the home screen, and both resize when panes
    // split or panels toggle — so re-seed only when its dimensions actually changed.
    let ro: ResizeObserver | null = null
    if (typeof ResizeObserver !== 'undefined' && host) {
      let lastW = 0
      let lastH = 0
      ro = new ResizeObserver((entries) => {
        const e = entries[0]
        if (!e) return
        const w = e.contentRect?.width ?? 0
        const h = e.contentRect?.height ?? 0
        if (Math.abs(w - lastW) > 0.5 || Math.abs(h - lastH) > 0.5) {
          lastW = w
          lastH = h
          onResize()
        }
      })
      ro.observe(host)
    }
    return () => {
      cancelAnimationFrame(raf)
      if (timer) clearInterval(timer)
      window.removeEventListener('resize', onResize)
      if (ro) ro.disconnect()
    }
  }, [])

  // `width`/`height` here are the LAYOUT size, never the drawing buffer: a canvas is a
  // replaced element, so `absolute inset-0` alone leaves it at its intrinsic 1x1 and the
  // fire is a single pixel in the corner. The buffer is still set by size() at dpr.
  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      className={className}
      style={{ width: '100%', height: '100%' }}
    />
  )
}