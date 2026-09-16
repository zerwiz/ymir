import { useEffect, useRef } from 'react';
// The hearth itself lives in the design system, not here: one fire, every
// surface. This component only gives it a box and a lifetime.
import { startEmbers } from '../../../../midgard/design-system/ember.js';

/**
 * EmberBackground — the landing page's fire, warming a Ymir surface.
 *
 * Fixed behind the whole app, so the shell *and* the login burn over the same
 * hearth. Decorative: pointer-events none, aria-hidden, and a reader who asked
 * for less motion gets a still frame instead of an animation (the shared module
 * decides that).
 */
export function EmberBackground() {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (!ref.current) return;
    return startEmbers(ref.current);
  }, []);

  return (
    <canvas
      ref={ref}
      aria-hidden="true"
      style={{
        position: 'fixed',
        inset: 0,
        width: '100%',
        height: '100%',
        pointerEvents: 'none',
        zIndex: 0,
      }}
    />
  );
}
