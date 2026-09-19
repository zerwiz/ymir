import type { CSSProperties } from 'react';

interface RuneTagProps {
  label: string;
  color?: string;
  glyph?: string;
}

export function RuneTag({ label, color, glyph }: RuneTagProps) {
  return (
    <span
      className="rune-tag"
      style={color ? ({ '--tag-color': color } as CSSProperties) : undefined}
    >
      {glyph ? (
        <span className="g" aria-hidden="true">
          {glyph}
        </span>
      ) : null}
      {label}
    </span>
  );
}
