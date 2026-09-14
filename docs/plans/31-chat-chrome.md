# Plan 31 — The Chat Chrome: seeing the weaving, keeping the thoughts

**Status:** OPEN (planned 2026-09-14 for the morning; no investigation done — by the Allfather's word)
**Owner:** Brokk + the seat's smiths
**Surface:** the chat interface of the seat (pi / Sessrúmnir renderer) and its thinking stream.

## The two wants (the Allfather's own words)

1. **The typing disappears behind the chat box.** When Brokk (the agent) is
   writing, the streaming output goes *behind* the Allfather's chat box —
   he cannot see what is being typed while it happens. He must see the weave
   as it is spun.
2. **The thinking is visible or storable, at the user's will.** The
   ephemeral thinking/reasoning vanishes from the chat surface. A user who
   wants it must be able to **store** the thinking (and see it) — a drawer,
   a toggle, a capture — on demand, without forcing it on anyone.

## What to do in the morning (in order)

1. **Reproduce + locate** — take the seat's chat pane and the stream wheel:
   find which layer occludes the output (the composer's z-order / shell? the
   input box's glass? the container's height/anchor?). Fix the stacking so
   streamed text is always visible above the composer.
2. **The thinking drawer** — capture the reasoning stream (the session's
   `thinking` segments) into a storable artifact at the user's word: a
   per-session `thinking.md` / a drawer in the chat column that shows the
   latest thought live and writes the full trail. A user toggle: on = see &
   store; off = UI unchanged (the current behavior).
3. **Store & revisit** — the stored thinking lands beside the session record
   (state/sessions or the seat's own store) so a user can reopen it after the
   fact, exactly like a saved report.
4. **Verify** — stream visible during typing (no hidden text behind the
   box), the drawer's on/off works, the stored trail matches the session,
   nothing forces the thinking on anyone.

## Acceptance

- Typing is never hidden behind the chat box — the last line is always in
  view.
- A user can toggle *store thinking*; the artifact exists and reopens.
- The default behavior stays the quiet one; the power is opt-in.

## Dependencies / notes

- Likely lives in the seat's renderer (pi/Sessrúmnir chat chrome) and the
  session-message handling; the thinking segments already exist in the
  session stream — the work is showing and keeping them, not inventing them.
- Plan only, by the Allfather's order. Morning word opens it. Masterplan
  row: `OPEN — The Chat Chrome (see docs/plans/31-chat-chrome.md)`.