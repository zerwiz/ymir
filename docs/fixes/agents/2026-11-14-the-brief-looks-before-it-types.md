# agents · unversioned · 2026-11-14 — the brief looks before it types, and says where it goes

Plan 293 part 5. `bin/agents/eindri-send.sh` already existed (plan 253) as a one-line door: stamp
the text, call `herdr agent prompt`, print `sent`. Everything that made a brief *safe* lived in a
runbook paragraph instead, and on 2026-11-14 the paragraph was written in blood: a prompt sent into
a box that already held the Allfather's half-written sentence, and a brief sent twice because
`herdr agent get` said `idle` while the screen showed a spinner.

## Why

Three faults, each measured on a live pane that day:

1. **`herdr agent prompt` appends.** It does not replace, and no herdr verb clears the box
   (`pane send-keys` refuses `C-u`). A blind send lands inside whatever is there.
2. **A send is not a landing.** A prompt that arrives before the agent is ready is lost silently,
   so a door must check, and may send once more — but only when it has proof the first one did not
   land.
3. **`agent get` lags the screen.** Three workers read `idle` while their screens showed work; the
   helm resent each and every one got two briefs. The resend must read the screen too.
4. **A typed brief is not a sent one** (measured by the helm the same evening). A prompt that
   arrives while pi is still starting can stand in the editor above the footer, with no spinner and
   an `idle` status: typed, never submitted. Sending the text again doubles it; pressing Enter
   finishes it.

And a fourth, about the far side: the heart's herdr is **0.7.4** and has no `agent prompt` — its
road is `agent send` then `pane send-keys <pane> Enter`, and it needs a login shell to be on `PATH`
at all (measured: a non-interactive ssh answered `herdr: command not found`).

## What changed

- **A new reader, `bin/seat/herdr-editor.py`**, answers one question: what is in that pane's input
  box? One reader for two shapes, both measured on live panes — claude bounds the box with two rules
  and opens it with `❯`; pi puts the box between its status separator and the rule beneath. It
  returns `empty`, `text` (with the draft) or `unknown`, and it is fed text over stdin for a far
  pane's tail so the same judgement is made on both roads.
- **The door refuses before it types.** A box holding text stops the send with exit 3 and a message
  that names what it read and says plainly that nothing was sent and nothing was cleared.
- **The door waits, then asks three witnesses.** After the send it waits (`--wait`, default 20s)
  and reads `herdr agent get`; a spinner or `Working`, `queued`, `esc to interrupt` on the screen
  counts as landed. Only when both are quiet does it read the **box**, and then:

  | What the box holds | What the door does | `resent` |
  |---|---|---|
  | text | presses **Enter** — our words are there, unsent; never retypes | `enter` |
  | empty | sends the line **once more** — it was lost | `copy` |
  | unknown | does **neither** — a duplicate costs more than a retry | `none` |
- **The far side is probed, never assumed.** `herdr agent --help` is asked what verbs it has;
  `prompt` is used where it exists, `send` + `pane send-keys Enter` where it does not. Machine names
  resolve from the home's fleet registry (`hodd/data/fleet.json` → `user@tailnet`), and a name the
  registry does not carry is refused by name.
- **`<machine>:<pane>`** is the target form: a pane id carries one colon, a road two or more, so the
  split is unambiguous and the prefix must be a real machine. `--machine <name>` says it explicitly.
- The origin stamp (2026-11-14's `msg-origin.sh`) is unchanged and still carried on every line.

## Files

- `bin/agents/eindri-send.sh`
- `bin/seat/herdr-editor.py`
- `bin/agents/tests/test_eindri_send.sh`
- `bin/seat/tests/test_herdr_editor.sh`
- `docs/features/hand-a-brief-to-a-worker.md`
- `docs/features/_catalogue/entries/02-114-hand-a-brief-to-a-worker.md`
- `bin/gates/ci-verify.sh`

## Verified

- `bin/seat/tests/test_herdr_editor.sh` — 8/8: pi and claude boxes, empty and holding a draft, a
  two-line draft, and the two honest `unknown` cases (no box; a transcript caught as a box).
- `bin/agents/tests/test_eindri_send.sh` — 28/28 against a stubbed `herdr` and a stubbed `ssh`: the
  refusal in both shapes with **nothing** recorded as sent, the stamp on the line, one send when the
  box is empty, a resend when nothing landed, **no** resend when the screen shows a spinner while
  `agent get` says `idle`, **Enter instead of a second copy** when the brief stands typed and
  unsent in the box, a refusal when no agent stands in the pane, the 0.7.x far road
  (`send` + `Enter`), the 0.9.x far road (`prompt`), an unknown machine refused with no ssh dialled,
  and a one-colon pane id that never rides ssh.
- Live on this machine, 2026-11-14: a pane holding the Allfather's own draft (`w39:pW`) was refused
  with exit 3 and the words it read; a pane with no agent on the heart
  (`<heart>:w0:p9`) was refused with exit 3 after the far `herdr` was probed, which proves the ssh
  road, the login shell and the verb probe in one call.

## What this does not do

It does not clear a box, ever — the words in one may be the Allfather's. A caller that must send
anyway clears it in the pane and calls again.
