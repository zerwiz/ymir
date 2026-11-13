import type { AvatarColor, AvatarShape } from '@shared/types';
import { BotAvatar, PICKER_CHARACTERS } from './BotAvatar';

/** The house's characters, three rows of five (plan 275, 2026-11-13). Its colour shows as the ring. */
export function CharacterPicker({ shape, color, onShape, size = 40 }: { shape: AvatarShape; color: AvatarColor; onShape: (s: AvatarShape) => void; size?: number }) {
  const rows = [PICKER_CHARACTERS.slice(0, 5), PICKER_CHARACTERS.slice(5, 10), PICKER_CHARACTERS.slice(10)];
  return (
    <div className="shape-grid" role="radiogroup" aria-label="The agent's character">
      {rows.map((row, i) => (
        <div key={i} className="shape-grid__row">
          {row.map((c) => (
            <button key={c.id} type="button" role="radio" aria-checked={shape === c.id} aria-label={c.name} title={c.name}
              className="shape-cell" onClick={() => onShape(c.id)}>
              <BotAvatar shape={c.id} color={color} size={size} ring={shape === c.id} />
            </button>
          ))}
        </div>
      ))}
    </div>
  );
}
