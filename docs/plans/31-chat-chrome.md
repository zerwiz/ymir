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
## Findings — 2026-09-14 (investigation done, by the Allfather's word)

### Issue 1 — the typing hides behind the chat box: MECHANISM FOUND
- The composer floats: `chat-panel.tsx` renders it `absolute inset-x-0 bottom-0 z-10
  pb-3 pt-8` over a fade gradient (`from-chat-column … to-transparent`).
- The message scroller's bottom padding (`paddingBottom: composerPadPx`) is what
  clears the tail above the glass — but it is measured **once** on mount
  (`useEffect(..., [])` on `composerWrapRef`), while the panel swaps render
  branches between the empty-state and the messages layout. When the observed
  node is the wrong branch or null, the pad stays `DEFAULT_COMPOSER_PAD_PX`
  (144) while the live composer — CouncilPanels + the "still working" banner +
  project picker — is taller. The stream's newest lines then scroll **under the
  glass and into the fade**: the typing disappears behind the chat box.
- FIX: measure every mount — re-run the composer-height observer whenever the
  messages branch becomes active (and on `isStreaming` + `reattachedMidTurn`
  growth); guard the floor at the live height + margin. Optional stronger cure:
  put the composer in normal flow (flex column) so hiding is physically
  impossible. Meanwhile a stale-144 pad is the smallest honest fix.

### Issue 2 — the thinking: MECHANISM FOUND
- The thinking IS wired: `streamingThinking` renders live in `StreamingBubble`
  and `message.thinking` renders as collapsible blocks — both gated by the
  **Show Thinking** settings toggle (`settings-panel.tsx`), which defaults
  off. So the reasoning vanishes by default, and the toggle sits buried in
  Settings.
- There is **no storage**: nothing writes the thinking to a file; a session's
  thoughts die with the stream.
- FIX: (a) keep the toggle but surface it where the eye lands (chat toolbar),
  remember the choice; (b) add **store thinking**: when on, append the
  thinking segments to a per-session artifact (e.g. `<session>.thinking.md`
  beside the session record) reopenable after the fact; (c) live parity: the
  streaming thought already follows the tail when at-bottom — keep that.

### Verdict
Both wants are reachable with honest fixes; nothing needs invention — the
thinking stream exists and the layout is one pad-measure away from honesty.
