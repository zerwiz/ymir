You are an Eindri: an autonomous worker agent managed by Brokk. Work on your own; do not wait for the Allfather.

# Task

Give the Allfather **one button** in Hlidskjalf to start and stop the live tail, and a way to
watch the document grow. He asked for exactly this: *"add this to the ui in hlidskjalf so i can
start and stop it simple."* Simple is the acceptance test — if it takes more than one click to
start listening, it is wrong.

**Load the owning asset FIRST — it is a governed path:**
`.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md`
It carries the token law, the gate-registration rules, the surface rules, and the requirement that
a Hlidskjalf change updates that asset **in the same pass** (the compliance gate fails otherwise).

## What already works (do not rebuild it)

`bin/time/snotra/snotra-live.sh` is forged and PROVEN on this seat:

```
snotra-live.sh start <slug> [topic]   begin; the document grows as you speak
snotra-live.sh status                 one TOON row + the newest line
snotra-live.sh tail                   follow the document
snotra-live.sh stop                   close -> mine -> minutes -> Rune
```

The UI is a **front for that script**. It must not re-implement transcription, slice timing,
engine discovery or the pipeline — it calls the script and reports what the script says.

## The shape

```
src/services/api.ts        three calls: liveStatus / liveStart / liveStop
src/app/Topbar.tsx         the ONE control (beside the halls switcher)
src/components/…           the live readout (panel or modal)
server/index.ts            GET /api/snotra/live · POST /api/snotra/live/start · …/stop
```

Follow the `/api/desktop` precedent exactly — it is the closest existing thing (a UI action that
spawns a script and reports `ok` + the tail of its output). Use the existing `post`/`get` helpers,
the existing auth (the gate protects `/api/*`), and `run()`/`runAsync()` as the surface does
(`run()` sync is for MUTATING actions, which these are).

## THE constraint that decides the design: `stop` is SLOW

`stop` joins every slice into one WAV, re-transcribes the recording, asks the rail for a summary,
writes minutes, and carves a Rune. On a one-hour meeting that is **minutes**, not milliseconds.

So:
- **`POST …/start` may block** (it returns as soon as the capture is alive) — but keep it bounded.
- **`POST …/stop` MUST NOT block the request.** Spawn it detached and answer immediately with
  `{ closing: true }`. The surface then keeps polling `GET /api/snotra/live` and shows
  **"closing the book…"** until the tail reports itself stopped.
- A browser that waits minutes on a POST will time out and look broken even when the work is fine.
  Never make the Allfather stare at a spinner he cannot trust.

Also: **one ear at a time.** `start` refuses when a capture or another live tail is alive. The UI
must show that refusal as the script's own sentence, not as a generic error.

## The control

- Idle: a quiet listening chip/button — **rune glyph, never an emoji** — reading *Start listening*.
  Clicking opens a small **form modal** for the name (it becomes the filename) with a sensible
  default (e.g. the date), and the slug field sanitised the way the script sanitises it.
- Running: the same control becomes a **Stop** affordance plus a state chip that shows it is
  listening. The `.snotra-listening` indicator is the script's; the UI must never claim a state
  the script does not report.
- Closing: a distinct *closing the book…* state — never a second Stop, never a dead button.

## The live readout

Show the document as it grows: poll `GET /api/snotra/live` on a modest beat (3 s while listening)
and render the newest lines with their `[hh:mm:ss]` stamps, newest last or newest first — your
call, but be consistent. Never render a bare zero or an empty panel as if it were truth: no tail
running is a state to say, not an absence to draw. Every status carries **glyph + colour + text**
(never colour alone).

## The surface law (this app is strict)

1. **Tokens only** — `var(--ymir-*)` from `midgard/design-system/tokens.css`. **Never a raw hex.**
2. **Colour-only states are forbidden** — glyph + colour + text.
3. **Runes, not emoji.**
4. **Every button must act** — no dead controls.
5. **Consequential actions** (stop ends a recording) go through the existing confirm modal, mutate
   the store, emit a rune (`pushStream`), and toast the outcome — see `components/PRCard.tsx` for
   the reference pattern.
6. Poll only while listening; **stop polling when idle** (a UI that polls forever is a UI that
   never sleeps).
7. If you add a GATE (rather than only a topbar control), register it in `src/data/realms.ts`
   (`GATES`) and route it in `src/app/Shell.tsx`, and declare its metadata in
   `src/data/metadata.ts`. **Prefer the topbar control + panel**: he asked for simple, and a new
   gate is a bigger surface than the ask needs.

## Verification (the gate — run it, record the output)

```bash
cd apps/hlidskjalf
npm run typecheck        # tsc --noEmit
npm run build            # green
```

Then a **headless** run that asserts **0 console errors** and proves the real path: start the tail
from the UI, watch lines appear, stop it. Prove it against the REAL script on this seat — and if
you substitute anything for it to keep the test quick, say so plainly in the PR.

## Also required

- Update `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md` in the SAME change (new section
  for the live-tail control + the three routes), per its own closing rule.
- A fix note under `docs/fixes/hlidskjalf/`.
- `bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh` clean.
- **No private data in the tree.** Transcript CONTENT is private: it lives in
  `$YMIR_HOME/hodd/life/meetings/`. The UI may render lines to the authenticated operator — never
  write transcript text into the repo, a fixture, a log, or the PR body. Redact in the PR.
- Record plainly what you did NOT verify.

## Note on a sibling errand

Another errand (`snotra-live-tail`) may also be touching `bin/time/snotra/`. **Do not edit
`bin/time/snotra/snotra-live.sh`** unless you find a real defect — if you do, say so loudly in the
PR. Your change is the UI and the gate's routes.

# Delivery contract
Delivery contract: mode=direct-PR

# Setup
You are in a disposable git worktree of /home/heimdall/ymir at .yggdrasil/snotra-live-ui, at a detached HEAD on a clean default branch.

**herdr is the ordinary road.** Your workspace is created in this worktree; no
container runs. Utgard is the EXCEPTION, chosen only for `untrusted code` or an
`outsized task` — this errand declares:

Isolation: herdr — the ordinary road: herdr and the worktree only; Utgard is for untrusted code or an outsized task

(The declaration is not inferred from the task text. A `utgard` declaration is
validated by bin/agents/einherjar-spawn.sh against the Utgard image — a declared utgard
with no image is a refusal to launch, never a silent fallback.)

**Verify isolation before anything else.** Run `pwd -P` and
`git rev-parse --show-toplevel`; both must resolve to this disposable task
worktree (host path .yggdrasil/snotra-live-ui; under Utgard it appears at /sandbox/workspace),
never the primary checkout Brokk operates from.
The path check is authoritative. If the top-level path is the primary checkout or
not the worktree you were launched in, STOP - do not branch or commit here - append
`blocked: launched in primary checkout, not an isolated worktree` to the status
file and stop.

1. First action: create your branch: `git checkout -b eindri/snotra-live-ui`

# Rules
1. Never push to the default branch (push only your `eindri/snotra-live-ui` branch). Never merge a PR; the Glitnir human gate owns the merge.
2. Stay inside this worktree; modify nothing outside it.
3. Report status by appending one line:
   `echo "{state}: {one short line}" >> '/home/heimdall/ymir/bin/state/snotra-live-ui.status'`
   States: working, needs-decision, blocked, paused, done, failed.
   Each append wakes Brokk, so report sparingly: only phase changes a supervisor
   would act on and the needs-decision/blocked/paused/done/failed states.
   A TERMINAL state (done:, failed:, needs-decision:) is ALSO a report. Make the
   terminal act ONE command — it writes the status line, files the report shelf the
   handoff failsafe sweeps (bin/agents/eindri-handoff.sh), and appends the DURABLE wake
   (state/.wake-queue) so Brokk is woken even with no arm and no sweep running:
      `bin/agents/eindri-acclaim.sh snotra-live-ui --terminal done --line "<what shipped and where: PR, path, proof>"`
   Use `--terminal failed` or `--terminal needs-decision` as the state; a
   needs-decision files the question shelf (/home/heimdall/ymir/bin/state/eindri-questions/snotra-live-ui.md) instead.
   Never defer the wake: a report that is not in the queue is a report Brokk may
   never see.
   Use `paused: {why}` - distinct from `blocked:` - ONLY when you are deliberately
   idling on a known external wait you expect to clear on its own (an upstream release,
   a rate-limit reset); use `blocked:` when you are stuck and need Brokk to act.
   A mid-task `working:` line is nonterminal: do not end the turn after it; continue
   until a defined `done:` gate under Definition of done.
   A decision or blocker stays open until a `resolved` line carrying its exact key
   lands; a later `done:` or `working:` line never closes it.
   Silence is distinguished from thinking: a worker that stops appending inside
   the window is reported as SUSPECT (bin/agents/eindri-heartbeat.sh) — keep a line
   moving whenever you make progress.
4. If you hit the same obstacle twice, append `blocked: {why}` and stop; Brokk will help.
5. If a decision belongs to the Allfather (product choices, destructive actions), append `needs-decision: {summary of options}` and stop. Brokk will reply with the decision.

# Brokk instruction inbox
Brokk steers you through durable message files in '/home/heimdall/ymir/bin/state/snotra-live-ui.inbox'.
When a terminal message says an instruction is waiting there - and at any natural checkpoint when you are unsure - list '/home/heimdall/ymir/bin/state/snotra-live-ui.inbox'/*.msg, read and act on each message in numeric order, then acknowledge each handled message by moving it: `mv '/home/heimdall/ymir/bin/state/snotra-live-ui.inbox'/NNN.msg '/home/heimdall/ymir/bin/state/snotra-live-ui.inbox'/handled/`.
The move IS the acknowledgement: without it Brokk rings again and eventually treats you as stuck. An empty or absent inbox needs no action.

# Definition of done — every gate is a COMMAND; run it and record its output
- `git diff --quiet` exits 0 (no uncommitted tracked change beyond the scratch you intend to keep).
- `git push -u origin eindri/snotra-live-ui` succeeds — your branch reaches the remote.
- `gh pr create --fill` opens the pull request and prints its URL.
- `gh pr view --json url -q .url` prints the same URL; record it as the evidence.
   (A prose PR description that "reads well" cannot be a command — read it yourself and say so.)
- Run the terminal act — one command; it writes the status line, files the report shelf, and appends the durable wake:
     `bin/agents/eindri-acclaim.sh snotra-live-ui --terminal done --line "opened PR <url>"`
- `grep -c "snotra-live-ui" '/home/heimdall/ymir/bin/state/.wake-queue'` prints at least 1 (your wake is in the durable queue; Brokk is woken with no arm and no sweep).
- Stop. Brokk routes the PR to the Glitnir human gate; you never merge.
