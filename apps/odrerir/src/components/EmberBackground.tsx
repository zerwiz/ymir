import { useEffect, useRef } from 'react';
import { startEmbers } from '../../midgard/design-system/ember.js';

/**
 * The hearth — the hall's glow, carried in this repo (not shared or borrowed),
 * exactly as the high seat carries its own.
 */
export default function EmberBackground() {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const stop = startEmbers(el);
    return () => stop?.();
  }, []);
  return <canvas ref={ref} className="ember-bg" data-ember aria-hidden="true" />;
}