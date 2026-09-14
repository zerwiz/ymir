import { useEffect, useRef } from 'react'

interface EmberBackgroundProps {
  className?: string
}

/**
 * EmberBackground — the hearth of the landing page, carried into the chat.
 *
 * The same little fire-dots that fly around the landing's hero (Ginnungagap):
 * 26 embers rise slowly with a gentle sway, seeded fresh on any resize, drawn
 * on one canvas behind the chat column. Purely decorative — pointer-events
 * none, aria-hidden, subtle enough that text stays the master of the room.
 */
export function EmberBackground({ className = '' }: EmberBackgroundProps): React.JSX.Element {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const cv = canvasRef.current
    if (!cv) return
    const ctx = cv.getContext('2d')
    if (!ctx) return
    const host = cv.parentElement
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
      cv.width = Math.max(1, W * dpr)
      cv.height = Math.max(1, H * dpr)
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    }
    function init() {
      embers = []
      haze = []
      for (let i = 0; i < 30; i++) {
        embers.push({
          x: Math.random() * W,
          y: H + Math.random() * H * 0.3 - 6,
          r: 1.0 + Math.random() * 1.6,
          v: 0.14 + Math.random() * 0.34,
          ph: Math.random() * 6.28,
          sp: 0.6 + Math.random() * 1.4,
        })
      }
      for (let i = 0; i < 6; i++) {
        haze.push({
          x: Math.random() * W,
          y: H * 0.3 + Math.random() * H * 0.7,
          r: 130 + Math.random() * 170,
          v: (Math.random() - 0.5) * 0.15,
        })
      }
    }
    function frame() {
      t += 0.016
      ctx.clearRect(0, 0, W, H)
      for (const ha of haze) {
        ha.x += ha.v
        if (ha.x < -ha.r) ha.x = W + ha.r
        if (ha.x > W + ha.r) ha.x = -ha.r
        const g = ctx.createRadialGradient(ha.x, ha.y, 0, ha.x, ha.y, ha.r)
        g.addColorStop(0, 'rgba(214,138,64,0.030)')
        g.addColorStop(1, 'rgba(0,0,0,0)')
        ctx.fillStyle = g
        ctx.beginPath()
        ctx.arc(ha.x, ha.y, ha.r, 0, 6.283)
        ctx.fill()
      }
      for (const e of embers) {
        e.y -= e.v
        e.x += Math.sin(t * e.sp + e.ph) * 0.18
        if (e.y < -6) {
          e.y = H + 6
          e.x = Math.random() * W
        }
        const a = 0.26 + 0.4 * (0.5 + 0.5 * Math.sin(t * e.sp * 2 + e.ph))
        ctx.fillStyle = 'rgba(236,166,84,' + a.toFixed(3) + ')'
        ctx.beginPath()
        ctx.arc(e.x, e.y, e.r, 0, 6.283)
        ctx.fill()
      }
    }
    function loop() {
      frame()
      raf = requestAnimationFrame(loop)
    }
    let raf = 0
    function onResize() {
      size()
      init()
    }
    size()
    init()
    raf = requestAnimationFrame(loop)
    window.addEventListener('resize', onResize)
    return () => {
      cancelAnimationFrame(raf)
      window.removeEventListener('resize', onResize)
    }
  }, [])

  return <canvas ref={canvasRef} aria-hidden="true" className={className} />
}