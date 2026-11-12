import type { AvatarColor } from '@shared/types';

/**
 * Bot colors. `fill` is the avatar/swatch color, `bubble` the user message bubble, `action` the
 * accent for toggles and the send button, and `hover` its hover state.
 */
export interface BotPalette { fill: string; bubble: string; action: string; hover: string }

// No blue and no purple in this house (2026-11-12, the Allfather). The four cool names keep their keys
// (bots in the database carry them) but wear house hues: cyan→moss, blue→steel, violet→umber, magenta→rust.
export const BOT_COLORS: Record<AvatarColor, BotPalette> = {
  // Black follows the theme (ink on light, light ink on dark), so it uses tokens instead of hex.
  black: { fill: 'var(--color-ink)', bubble: 'var(--color-bubble-user)', action: 'var(--color-primary)', hover: 'var(--color-bg-primary-hover)' },
  brown: { fill: '#A06B39', bubble: '#86592E', action: '#9D6937', hover: '#86592E' },
  red: { fill: '#FB2B3E', bubble: '#C82532', action: '#E72E3B', hover: '#C82532' },
  orange: { fill: '#FD690F', bubble: '#D2550A', action: '#EE620D', hover: '#D2550A' },
  yellow: { fill: '#F59312', bubble: '#C2730B', action: '#DA830E', hover: '#C2730B' },
  green: { fill: '#14C16F', bubble: '#0D9655', action: '#10AB61', hover: '#0D9655' },
  cyan: { fill: '#7D8F6A', bubble: '#64744F', action: '#71825D', hover: '#64744F' },
  blue: { fill: '#96A0A8', bubble: '#5F686E', action: '#7E8890', hover: '#5F686E' },
  violet: { fill: '#8A6A4A', bubble: '#6E533A', action: '#7C5F42', hover: '#6E533A' },
  magenta: { fill: '#A0523D', bubble: '#7C3A30', action: '#8E4636', hover: '#7C3A30' },
  gray: { fill: '#959595', bubble: '#6E6E6E', action: '#7A7A7A', hover: '#6E6E6E' },
};

/** Swatch order in the Create New Bot picker. */
export const COLOR_ORDER: AvatarColor[] = ['black', 'brown', 'red', 'orange', 'yellow', 'green', 'cyan', 'blue', 'violet', 'magenta', 'gray'];

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
