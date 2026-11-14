# Sága's head fits, and forgets what it already said

**Plan:** 275, item 28. **Date:** 2026-11-14. **Owner:** the errand `digest-head`.

## What was wrong

Sága's session start pre-loaded everything. Measured on one session:

| Measure | Before |
|---|---|
| One injection | 55–57 KB, **696 lines**, about 14,000 tokens |
| Injections in one session | **nine** — the start, then every compaction re-ran it |
| SessionStart hooks | **three**, one per home, each a hardcoded absolute path |
| Of 163 liveness rows | **156 were errands finished days ago** |
| Lines a session could act on | under 40 |

The practice is the opposite: the smallest set of high-signal tokens, and the rest fetched
just in time. A digest nobody can afford to read is not a digest.

## What changed

**One head, on demand for the rest.** `bin/time/saga-session-start.sh` prints a head of ≤ 60
lines and ≤ 8 KiB: the fixed core, who holds the helm, what needs the Allfather, the live
errands, the next step. Every other fact is a section, asked for by name
(`--section <name>`, twenty of them), and the head names them in one line. `--check` measures
the head and exits 1 over budget.

**The fixed core is one file.** `bin/time/saga-head-core.md` carries Ymir-is-public, the
private home and how to edit it, the pin, herdr and the stamped send door, the Gná arm, the
finding tools, the desk guard and the laws. The head prints it; the seat law
(`bin/seat/herdr-run.sh`) and the spawn road (`bin/agents/einherjar-spawn.sh`) append the same
file, so a worker's brief and a session's digest cannot teach different commands.

**Finished is not news.** `bin/time/saga-head-lib.sh` is the policy: a live errand is always
shown; a finished one is shown once and then folded into `state/.saga-head-seen`; an UNKNOWN
row whose pane can never be read here (a tmux window on a machine that no longer runs tmux) is
reaped once; anything older than the head's own last run was already reported, so the first
run seeds the markers instead of reporting 156 errands. A resolved wake drops itself from the
queue in `bin/time/saga-wake-drain.sh` — presented once, subject closed, gone.

**One injection, for the current home.** `.claude/hooks/saga-session.sh` resolves the home the
session is actually in (the project, then the pin, then the source) and hands the payload to
that home's runner. `bin/seat/harness-extensions-install.sh` seats it as one named entry and
**prunes** any entry that still names `saga-session-start.sh` directly — the three per-home
entries were exactly that. A compaction re-injects the head alone, and only when the start
already ran.

**The stages belong to the helm.** Lock, bridges and the well run at a session start; the hall
sweep, the handoff and the cron are the helm's, and a seat (which takes its own lock) no longer
sweeps the hall from its session start.

## How it was proved

- `bin/time/tests/test_saga_head.sh` (gate `saga-head` in `bin/gates/ci-verify.sh`): the head
  fits, `--check` fails over budget, every section answers by name, an unknown section is
  refused, a finished errand is reported once and then gone, an UNKNOWN row is reaped once, a
  compaction injects the head only, the core exists in exactly one file and reaches the seat
  law, and one hook resolves the current home. 36 checks, all green.
- On heimdall, through the real hook: a startup injection is **33 lines / 3,569 bytes**, a
  compaction **34 lines / 3,745 bytes** — from the same home that used to emit 676 lines /
  50,147 bytes.
- The head costs about 1.3 s to print (it was 3.5 s when the record reader spawned a process
  per seat; it now reads with shell builtins and one `find -newer`).

## Not done, and why

- **The pin and the working tree still run the old digest** until this branch becomes a
  release: the installer seats harness hooks from the pin (`RULES/02 §7`), so the deployed hook
  arrives with the next `bin/engine/release.sh build` + `flip`.
- **nidavellir was offline** (tailnet: last seen 1 h ago) when this was proved; the same gate
  and the same hook run there with one command once the machine is up.
- **Hlidskjalf's Runtime page** still shows the digest text; it is item 25's errand
  (`one-hlidskjalf`), not this one.

## CHANGE LOG

- **2026-11-14** — written with the change it describes (plan 275, item 28).
