import { useMemo, useState } from 'react';
import type { ChatModel } from '../services/api';

interface ModelPickerProps {
  value: string;
  onChange: (id: string) => void;
  models: ChatModel[];
  placeholder?: string;
  allowFree?: boolean;
}

/**
 * A themed combobox for choosing a model. Native datalists spill off-theme and
 * stretch the hall; this keeps the catalog in a scroll of our own making,
 * filters as you type, and always allows a free-typed id.
 */
export function ModelPicker({ value, onChange, models, placeholder, allowFree = true }: ModelPickerProps) {
  const [open, setOpen] = useState(false);
  const [filter, setFilter] = useState('');
  const needle = (filter || value).toLowerCase();

  const matches = useMemo(() => {
    const list = models.filter(
      (m) => !needle || `${m.id} ${m.provider}`.toLowerCase().includes(needle),
    );
    return list.slice(0, 60);
  }, [models, needle]);

  const exact = models.some((m) => m.id === value);
  const typed = filter || value;

  return (
    <div className="model-picker">
      <input
        value={value}
        placeholder={placeholder}
        title={value || undefined}
        role="combobox"
        aria-expanded={open}
        aria-label={placeholder ?? 'Choose a model'}
        onFocus={() => setOpen(true)}
        onChange={(e) => {
          onChange(e.target.value);
          setFilter(e.target.value);
          setOpen(true);
        }}
        onBlur={() => window.setTimeout(() => setOpen(false), 160)}
        onKeyDown={(e) => {
          if (e.key === 'Escape') setOpen(false);
        }}
      />
      {value ? (
        <div className="model-current" title={value}>
          {value}
        </div>
      ) : null}
      {open && (matches.length > 0 || (allowFree && typed)) ? (
        <ul className="model-menu" role="listbox">
          {matches.map((m) => (
            <li
              key={m.id}
              role="option"
              aria-selected={m.id === value}
              title={m.id}
              className={m.id === value ? 'active' : ''}
              onMouseDown={(e) => {
                e.preventDefault();
                onChange(m.id);
                setFilter('');
                setOpen(false);
              }}
            >
              <span className="mono grow">{m.id}</span>
              <span className={`badge ${m.kind}`}>{m.kind}</span>
            </li>
          ))}
          {allowFree && typed && !exact ? (
            <li
              className="free"
              onMouseDown={(e) => {
                e.preventDefault();
                onChange(typed);
                setFilter('');
                setOpen(false);
              }}
            >
              <span className="mono grow">Use “{typed}”</span>
              <span className="dim">free-type</span>
            </li>
          ) : null}
        </ul>
      ) : null}
      {open && matches.length === 0 && !(allowFree && typed) ? (
        <ul className="model-menu" role="listbox">
          <li className="dim">No connected models.</li>
        </ul>
      ) : null}
    </div>
  );
}
