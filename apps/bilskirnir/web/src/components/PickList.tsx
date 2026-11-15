import { useEffect, useRef, useState } from 'react';
import { Icon } from './Icon';

export interface PickOption { value: string; label: string; hint?: string; disabled?: boolean }

/**
 * A dropdown drawn inside the page (plan 275, 2026-11-13). The native <select> opened its list as a window of its
 * own and could spill off the screen, and a typed model id was the only way to name a model. This list is never wider
 * than the window, never taller than the room left, opens upward when there is no room below, and scrolls.
 */
export function PickList({ label, value, options, onPick, placeholder, disabled }: {
  label: string; value: string; options: PickOption[]; onPick: (v: string) => void; placeholder?: string; disabled?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [up, setUp] = useState(false);
  const [room, setRoom] = useState(320);
  const ref = useRef<HTMLDivElement>(null);
  const current = options.find((o) => o.value === value);

  useEffect(() => {
    if (!open) return;
    const down = (e: MouseEvent) => { if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false); };
    const key = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.stopPropagation(); setOpen(false); } };
    document.addEventListener('mousedown', down);
    document.addEventListener('keydown', key, true);
    ref.current?.querySelector<HTMLElement>('[aria-selected="true"]')?.scrollIntoView({ block: 'nearest' });
    return () => { document.removeEventListener('mousedown', down); document.removeEventListener('keydown', key, true); };
  }, [open]);

  const toggle = () => {
    if (disabled) return;
    if (!open && ref.current) {
      const r = ref.current.getBoundingClientRect();
      const below = window.innerHeight - r.bottom - 12, above = r.top - 12;
      const goUp = below < 200 && above > below;
      setUp(goUp);
      setRoom(Math.max(120, Math.min(360, goUp ? above : below)));
    }
    setOpen(!open);
  };

  return (
    <div ref={ref} className={`picklist${open ? ' is-open' : ''}${up ? ' is-up' : ''}`}>
      <button type="button" className="picklist__button" aria-label={label} aria-haspopup="listbox" aria-expanded={open} onClick={toggle} disabled={disabled}>
        <span className="picklist__value">{current?.label ?? (value || placeholder || 'Choose…')}</span>
        <Icon name="chev_down" size={10} opacity={0.66} />
      </button>
      {open && (
        <div className="picklist__list" role="listbox" aria-label={label} style={{ maxHeight: room }}>
          {options.map((o) => (
            <button key={o.value} type="button" role="option" aria-selected={o.value === value} disabled={o.disabled}
              className={`picklist__option${o.value === value ? ' is-selected' : ''}`}
              onClick={() => { setOpen(false); if (o.value !== value) onPick(o.value); }}>
              <span>{o.label}</span>
              {o.hint && <span className="picklist__hint">{o.hint}</span>}
            </button>
          ))}
          {!options.length && <div className="picklist__empty">Nothing to choose here.</div>}
        </div>
      )}
    </div>
  );
}
