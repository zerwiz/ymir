import type { AvatarColor, AvatarShape, Bot } from '@shared/types';
import { Icon } from '../components/Icon';
import { SHAPES, type ShapeDef } from './shapes.gen';
// The one mark, from the design system (Vite serves it from outside this folder; see vite.config fs.allow).
import ymirMark from '@design/ymir-mark.svg?url';

/** Shapes without an exported SVG fall back to the closest silhouette we have. */
const FALLBACK: Partial<Record<AvatarShape, string>> = {
  bean: 'teardrop', squircle: 'square', capsule: 'tablet', cylinder: 'tablet', gem: 'hex', crystal: 'hex',
  shield: 'house', dome: 'house', arch: 'house', leaf: 'teardrop',
};

export function shapeDef(shape: AvatarShape | string): ShapeDef {
  return SHAPES[shape] ?? SHAPES[FALLBACK[shape as AvatarShape] ?? 'blob'] ?? SHAPES.blob;
}

/** Shapes offered in the Create New Bot picker, in the design's order (rows of 5/5/3). */
export const PICKER_SHAPES: AvatarShape[] = ['blob', 'cloud', 'square', 'sparkle', 'clover', 'heart', 'flower', 'teardrop', 'tablet', 'wedge', 'house', 'star', 'hex'];

interface Props {
  shape: AvatarShape | string;
  color: AvatarColor | string;
  /** Slot size in px. */
  size: number;
  star?: boolean;
  /** Selected ring. */
  ring?: boolean;
  className?: string;
  title?: string;
}

// The house avatar: the Ymir mark itself, in bronze on stone (Bilskirnir, 2026-11-12). The Allfather tried
// a shield, a Viking and a rune stone, then chose from five laid side by side: "Do E" — the house's own
// mark (midgard/design-system/ymir-mark.svg), the one file, never a copy. runeFor stays for the places
// that print an agent's rune as text.
const RUNES: Record<string, string> = {
  a: 'ᚨ', b: 'ᛒ', c: 'ᚲ', d: 'ᛞ', e: 'ᛖ', f: 'ᚠ', g: 'ᚷ', h: 'ᚺ', i: 'ᛁ', j: 'ᛃ', k: 'ᚲ', l: 'ᛚ', m: 'ᛗ',
  n: 'ᚾ', o: 'ᛟ', p: 'ᛈ', q: 'ᚲ', r: 'ᚱ', s: 'ᛊ', t: 'ᛏ', u: 'ᚢ', v: 'ᚹ', w: 'ᚹ', x: 'ᚲ', y: 'ᛃ', z: 'ᛉ',
  'þ': 'ᚦ', 'ð': 'ᛞ', 'æ': 'ᚨ', 'ø': 'ᛟ', 'ö': 'ᛟ', 'å': 'ᚨ', 'ä': 'ᚨ',
};
export function runeFor(name?: string) {
  const ch = (name ?? '').trim().normalize('NFC').charAt(0).toLowerCase();
  return RUNES[ch] ?? RUNES[ch.normalize('NFD').charAt(0)] ?? 'ᛉ';
}

export function BotAvatar({ size, star, ring, className, title }: Props) {
  return (
    <span className={`bot-avatar ${className ?? ''}`} style={{ width: size, height: size }} title={title} role="img" aria-label={title}>
      <img src={ymirMark} alt="" width={size} height={size} draggable={false}
        style={{ position: 'absolute', inset: 0, width: size, height: size, borderRadius: size * 0.08,
          boxShadow: ring ? '0 0 0 2px var(--ymir-cyan-1, #c9973f)' : '0 2px 8px rgba(0,0,0,0.55)' }} />
      {star && (
        <span className="bot-avatar__star" style={{ width: size * 0.2667, height: size * 0.2667 }}>
          <Icon name="star" size={size * 0.1333} color="#FFFFFF" />
        </span>
      )}
    </span>
  );
}

export function BotAvatarFor({ bot, size, star, className }: { bot: Pick<Bot, 'avatarShape' | 'avatarColor' | 'name'> & { isPrimary?: boolean }; size: number; star?: boolean; className?: string }) {
  return <BotAvatar shape={bot.avatarShape} color={bot.avatarColor} size={size} star={star} className={className} title={bot.name} />;
}
