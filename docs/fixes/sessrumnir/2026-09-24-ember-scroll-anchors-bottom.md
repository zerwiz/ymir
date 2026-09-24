# sessrumnir · 2026-09-24 — the embers grow from the bottom of the chat pane

## Why
In the seat-hall's chat, the message cells ("embers") painted from the top (the
Allfather: they "start from one third up" instead of the bottom). The scroll
container in `chat-panel.tsx` was a plain block: `<div ref={scrollRef}
onScroll={onScroll} className="flex-1 overflow-y-auto">` with a top-aligned
content wrapper — so a short (or freshly loaded) conversation renders from the
top of the pane, not anchored to the bottom as a chat should.

## What
- The scroll container becomes a flex column, and a **top spacer**
  (`flex: '1 1 auto'`, `shrink-0`) is inserted before the messages: when the
  conversation is short the spacer takes the free space and the embers sit at
  the BOTTOM; when it overflows, the spacer collapses to 0 so scrolling still
  reaches every message (this deliberately avoids the `justify-content:
  flex-end` overflow trap, which can make the START of long content
  unreachable). The existing `useChatScroll` hook still ends a long
  conversation at the bottom (`scrollToBottom` on session load / content
  growth).

## Verified
- `npm run typecheck`: the error set with the fix is IDENTICAL to main HEAD
  (7 pre-existing TS errors in `bridge-http.ts` — the http-typed bridge lacks
  the preload's `fleet` system — and `ember-background.tsx`; none in
  `chat-panel.tsx`; verified by stash contrast). The change adds no type
  errors.
- **Pre-existing bench note:** the fork does NOT typecheck clean on main today
  (7 errors). A separate errand should reconcile `bridge-http.ts` with the
  preload and mend `ember-background.tsx`.

## Files
- `apps/sessrumnir/src/renderer/src/components/chat-panel.tsx`