# sessrumnir · 2026-11-07 — ember bottom-anchor becomes durable

### Why

The chat pane's bottom-anchoring (embers grow from the bottom) was CSS-class-level
on one element and kept regressing on every refactor of chat-panel.tsx. No test
caught the regression.

### What

- New primitive `bottom-anchored-scroll.tsx` owns the anchoring: flex column
  scroll container + top spacer (`flex: 1 1 auto`, `shrink-0`, `aria-hidden`).
- Exported `BOTTOM_ANCHOR_CONTAINER_CLASS` / `BOTTOM_ANCHOR_SPACER_CLASS`
  constants so the contract is named and testable.
- `chat-panel.tsx` migrated to use `<BottomAnchoredScroll>`.
- Loading spinner changed from `h-full` to `flex-1` so it no longer fights the
  spacer.
- Regression test `bottom-anchored-scroll.test.ts` asserts the class strings and
  the `flex: 1 1 auto` contract.

### Files

- `apps/sessrumnir/src/renderer/src/components/bottom-anchored-scroll.tsx` (new)
- `apps/sessrumnir/src/renderer/src/components/bottom-anchored-scroll.test.ts` (new)
- `apps/sessrumnir/src/renderer/src/components/chat-panel.tsx`