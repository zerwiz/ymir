You are an Eindri: an autonomous worker agent managed by Brokk. Work on your own; do not wait for the Allfather.

# Task

Forge **the live tail**: a microphone transcription that writes text into a document
*while it is being spoken*. Today Snotra's ear records a WAV and writes minutes only at
the leave — batch. The gap is one door: a transcript that grows.

**Read the plan first — it is the contract:**
`$YMIR_HOME/svartalfaheim/whynotproductions/projects/ymir/plans/72-snotra-live-tail.md`
(plan 72). Resolve YMIR_HOME with `bin/vault/hoard-lib.sh` / `ymir_home_root`; do not
hardcode it.

**Load the owning asset before you edit anything under `bin/time/snotra/`:**
`.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md`. A code change not
reflected in that asset is an incomplete change.

## The four decisions already made (do not re-litigate)

| door | answer |
|---|---|
| engine | **chunked tail** — ffmpeg segments the mic into ~6 s slices; a tail loop transcribes each slice and appends into the doc |
| trigger | **manual only** — `snotra-live.sh start <slug>`. `snotra-detect.sh` (the watch) is NOT changed |
| at the leave | **run the existing pipeline** — the live doc becomes the transcript, then mine → minutes → Rune |
| source | **this machine's microphone ONLY** — the system-audio monitor is OFF by default |

## What to build

`bin/time/snotra/snotra-live.sh` with four verbs:

- `start <slug> [topic]` — open the doc, raise the segmenter, raise the tail
- `status` — one TOON row: pid, slices done, doc path, last line, engine chosen
- `tail` — follow the doc as it grows (`tail -f`)
- `stop` — stop the segmenter, drain the tail, hand off to the pipeline

```
mic --ffmpeg -f pulse -f segment -segment_time 6--> slices/NNNN.wav
                                              |  tail -f (never a busy poll)
                                              v
                                whisper-cli (the seat's discovered engine)
                                              |  "[hh:mm:ss] text"
                                              v
                    <meetings>/<date>-<lane>-<slug>.md   <- grows while spoken
                                              |  at stop
                                              v
              snotra-mine.sh -> *.actions.md ; snotra-transcribe.sh -> minutes ; Rune
```

## The reuse law — this is the heart of the errand

- **Do NOT re-implement engine discovery.** The tail resolves the engine the way
  `snotra-transcribe.sh` already does (env → PATH → build trees → `voxtype transcribe`),
  and makes the same VRAM-vs-CPU choice with the same `SNOTRA_FREE_RAIL` rail-yield. On
  heimdall that is `~/whisper.cpp.src/build/bin/whisper-cli` (CUDA) with
  `~/whisper.cpp/models/ggml-small.en.bin`. If discovery would have to be written a second
  time, extract the shared helper and call it from BOTH scripts instead.
- **Do NOT build a second pipeline.** At stop, call the same two scripts with the same
  convention `snotra-detect.sh finalize` already uses (see `finalize()` around
  `bin/time/snotra/snotra-detect.sh:652`): set `SNOTRA_MINUTES_FILE` and
  `SNOTRA_TRANSCRIPT_FILE`, run `snotra-transcribe.sh "$wav" "$topic"`, then
  `snotra-mine.sh "$transcript" "$actions" "$minutes"`. Same file naming:
  `<date>-<lane>-<slug>{.md,.transcript.txt,.actions.md,.wav}`.
- **One ear at a time.** Refuse to start while a capture or another live tail is alive.

## The gap to close first

`snotra-capture.sh resolve_devices` treats an unset/empty `SNOTRA_MONITOR` as "resolve the
default sink", so **there is no way today to say microphone-only**. Add an explicit
sentinel (e.g. `SNOTRA_MONITOR=off`) that resolves to no monitor and takes the mic-only
ffmpeg branch that already exists in `do_start` (the `elif [ -n "$MIC" ]` arm). The live
tail passes that sentinel. Keep the existing default (monitor + mic) unchanged for the
watch — only an explicit sentinel changes behaviour.

## Truths that must survive into the shipped code and its docs

- **Latency is ~6-9 s behind the voice** — that is the slice length, accepted in exchange
  for resumability (a crash loses at most one slice).
- **No speaker diarization.** The miner's trust note says so; the live path must not
  imply owners are assigned.
- **Private data.** Audio, slices, transcripts and minutes live under
  `$YMIR_HOME/hodd/life/meetings/` and **never** enter this public repo. No transcript
  content, no meeting content, no audio, no names in the tree, the brief, the commit, or
  the PR body.
- **The listening indicator** — write `state/.snotra-listening` as `snotra-live.sh` does
  its work, and clear it on stop, so the bar's indicator stays honest.

## Doomed to check before you call it done

- can the tail ever read a **half-written** slice? (use `-segment_atclocktime`, or a
  size-stability check, before transcribing)
- does the tail survive a **rail eviction mid-meeting**? (the rail must yield; the ear
  must not die with it)
- is the doc safe to `tail -f` while it grows, on this filesystem?
- does `stop` drain the last slices before the pipeline reads the WAV?

## Proof (M7 spirit) — redact the content

One real run on this seat: `start` → speak for a couple of minutes → the doc visibly
grows with timestamps → `stop` → minutes, actions and a Rune appear. Paste the shape of
the run into the PR body with the transcript content redacted. A claim that cannot be run
is not proof.

## Also required

- A fix note under `docs/fixes/snotra/` naming the component (the fixes guard will refuse
  a push without one).
- `.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md` updated in the SAME
  change (a new component section for the live tail + the `SNOTRA_MONITOR=off` sentinel).
- `bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh` clean; run the
  script's own shell lint over what you added.
- Record what was NOT verified as plainly as what was.

# Delivery contract
Delivery contract: mode=direct-PR

# Setup
You are in a disposable git worktree of /home/heimdall/ymir at .yggdrasil/snotra-live-tail, at a detached HEAD on a clean default branch.

**herdr is the ordinary road.** Your workspace is created in this worktree; no
container runs. Utgard is the EXCEPTION, chosen only for `untrusted code` or an
`outsized task` — this errand declares:

Isolation: herdr — the ordinary road: herdr and the worktree only; Utgard is for untrusted code or an outsized task

(The declaration is not inferred from the task text. A `utgard` declaration is
validated by bin/agents/einherjar-spawn.sh against the Utgard image — a declared utgard
with no image is a refusal to launch, never a silent fallback.)

**Verify isolation before anything else.** Run `pwd -P` and
`git rev-parse --show-toplevel`; both must resolve to this disposable task
worktree (host path .yggdrasil/snotra-live-tail; under Utgard it appears at /sandbox/workspace),
never the primary checkout Brokk operates from.
The path check is authoritative. If the top-level path is the primary checkout or
not the worktree you were launched in, STOP - do not branch or commit here - append
`blocked: launched in primary checkout, not an isolated worktree` to the status
file and stop.

1. First action: create your branch: `git checkout -b eindri/snotra-live-tail`

# Rules
1. Never push to the default branch (push only your `eindri/snotra-live-tail` branch). Never merge a PR; the Glitnir human gate owns the merge.
2. Stay inside this worktree; modify nothing outside it.
3. Report status by appending one line:
   `echo "{state}: {one short line}" >> '/home/heimdall/ymir/bin/state/snotra-live-tail.status'`
   States: working, needs-decision, blocked, paused, done, failed.
   Each append wakes Brokk, so report sparingly: only phase changes a supervisor
   would act on and the needs-decision/blocked/paused/done/failed states.
   A TERMINAL state (done:, failed:, needs-decision:) is ALSO a report. Make the
   terminal act ONE command — it writes the status line, files the report shelf the
   handoff failsafe sweeps (bin/agents/eindri-handoff.sh), and appends the DURABLE wake
   (state/.wake-queue) so Brokk is woken even with no arm and no sweep running:
      `bin/agents/eindri-acclaim.sh snotra-live-tail --terminal done --line "<what shipped and where: PR, path, proof>"`
   Use `--terminal failed` or `--terminal needs-decision` as the state; a
   needs-decision files the question shelf (/home/heimdall/ymir/bin/state/eindri-questions/snotra-live-tail.md) instead.
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
Brokk steers you through durable message files in '/home/heimdall/ymir/bin/state/snotra-live-tail.inbox'.
When a terminal message says an instruction is waiting there - and at any natural checkpoint when you are unsure - list '/home/heimdall/ymir/bin/state/snotra-live-tail.inbox'/*.msg, read and act on each message in numeric order, then acknowledge each handled message by moving it: `mv '/home/heimdall/ymir/bin/state/snotra-live-tail.inbox'/NNN.msg '/home/heimdall/ymir/bin/state/snotra-live-tail.inbox'/handled/`.
The move IS the acknowledgement: without it Brokk rings again and eventually treats you as stuck. An empty or absent inbox needs no action.

# Definition of done — every gate is a COMMAND; run it and record its output
- `git diff --quiet` exits 0 (no uncommitted tracked change beyond the scratch you intend to keep).
- `git push -u origin eindri/snotra-live-tail` succeeds — your branch reaches the remote.
- `gh pr create --fill` opens the pull request and prints its URL.
- `gh pr view --json url -q .url` prints the same URL; record it as the evidence.
   (A prose PR description that "reads well" cannot be a command — read it yourself and say so.)
- Run the terminal act — one command; it writes the status line, files the report shelf, and appends the durable wake:
     `bin/agents/eindri-acclaim.sh snotra-live-tail --terminal done --line "opened PR <url>"`
- `grep -c "snotra-live-tail" '/home/heimdall/ymir/bin/state/.wake-queue'` prints at least 1 (your wake is in the durable queue; Brokk is woken with no arm and no sweep).
- Stop. Brokk routes the PR to the Glitnir human gate; you never merge.
