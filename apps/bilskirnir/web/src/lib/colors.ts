import type { AvatarColor } from '@shared/types';

/**
 * Bot colors. `fill` is the avatar/swatch color, `bubble` the user message bubble, `action` the
 * accent for toggles and the send button, and `hover` its hover state.
 */
export interface BotPalette { fill: string; bubble: string; action: string; hover: string }

// The house's hues only (2026-11-12, the Allfather: "make the colour swatches house hues only (stone, bone,
// bronze, rust, moss, steel — never blue or purple)"). The keys stay as Bot HQ named them, because agents in
// the database carry them; what each key WEARS is a house hue, and only six are offered. Older keys that a
// stored agent may still carry (brown, orange, cyan, violet, magenta) fall to the nearest house hue.
export const BOT_COLORS: Record<AvatarColor, BotPalette> = {
  // bone follows the theme's ink (bone on stone), so it uses tokens instead of hex
  black: { fill: 'var(--color-ink)', bubble: 'var(--color-bubble-user)', action: 'var(--color-primary)', hover: 'var(--color-bg-primary-hover)' },
  gray: { fill: '#8A8170', bubble: '#5E5747', action: '#7A7262', hover: '#5E5747' },     // stone
  yellow: { fill: '#C9973F', bubble: '#7D5F2A', action: '#B5873A', hover: '#7D5F2A' },   // bronze
  red: { fill: '#A0523D', bubble: '#7C3A30', action: '#8E4636', hover: '#7C3A30' },      // rust
  green: { fill: '#7D8F6A', bubble: '#64744F', action: '#71825D', hover: '#64744F' },    // moss
  blue: { fill: '#96A0A8', bubble: '#5F686E', action: '#7E8890', hover: '#5F686E' },     // steel
  // kept for agents that already carry them — never offered
  brown: { fill: '#8A6A4A', bubble: '#6E533A', action: '#7C5F42', hover: '#6E533A' },
  orange: { fill: '#B5762F', bubble: '#8A5A24', action: '#A06A2B', hover: '#8A5A24' },
  cyan: { fill: '#7D8F6A', bubble: '#64744F', action: '#71825D', hover: '#64744F' },
  violet: { fill: '#8A6A4A', bubble: '#6E533A', action: '#7C5F42', hover: '#6E533A' },
  magenta: { fill: '#A0523D', bubble: '#7C3A30', action: '#8E4636', hover: '#7C3A30' },
};

/** The six hues offered when an agent is seated, in the house's order. */
export const COLOR_ORDER: AvatarColor[] = ['gray', 'black', 'yellow', 'red', 'green', 'blue'];

/** What each hue is called where a person reads it (the key is an identifier and stays). */
export const COLOR_NAMES: Record<AvatarColor, string> = {
  gray: 'Stone', black: 'Bone', yellow: 'Bronze', red: 'Rust', green: 'Moss', blue: 'Steel',
  brown: 'Umber', orange: 'Deep bronze', cyan: 'Moss', violet: 'Umber', magenta: 'Rust',
};

export const palette = (c: AvatarColor | string | undefined): BotPalette => BOT_COLORS[(c as AvatarColor) ?? 'black'] ?? BOT_COLORS.black;

/** CSS custom properties that theme a subtree with a bot's color. */
export function botVars(c: AvatarColor | string | undefined): React.CSSProperties {
  const p = palette(c);
  return {
    ['--bot-fill' as string]: p.fill, ['--bot-bubble' as string]: p.bubble, ['--bot-action' as string]: p.action, ['--bot-action-hover' as string]: p.hover,
    ['--bot-on-action' as string]: p === BOT_COLORS.black ? 'var(--color-on-primary)' : '#FFFFFF',
    ['--bot-action-soft' as string]: `color-mix(in srgb, ${p.action} 13%, transparent)`,
    ['--bot-action-text' as string]: p === BOT_COLORS.black ? 'var(--color-text-secondary)' : p.action,
  };
}
