import { useEffect, useRef } from 'react';
// the app's own copy of midgard/design-system/ember.js (the split, 2026-11-19), kept equal by Ymir's shared-copy test
import { startEmbers } from '../house-design/ember.js';

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