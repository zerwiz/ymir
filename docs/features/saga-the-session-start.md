# Sága — the session start

## What it is

**Sága** is the seeress: the one report a session reads before its first word. She used to
pre-load everything — nineteen sections, 696 lines, about 14,000 tokens — and three hooks
re-injected all of it at every compaction. She is now a **short head** (60 lines at most) plus
**twenty sections you ask for by name**.

The head is, in order: the fixed core every worker must know, who holds the helm, what needs
the Allfather, the live errands, and the next step.

## What you need

- Ymir installed and raised.
- Nothing else — it is the first thing to run.

## Do it

```bash
bin/time/saga-session-start.sh              # a session start: the stages, then the head
bin/time/saga-session-start.sh --head       # the head alone (what a compaction re-injects)
bin/time/saga-session-start.sh --page       # a PAGE reads the head: read-only, holds nothing
bin/time/saga-session-start.sh --list       # the twenty sections, one line each
bin/time/saga-session-start.sh --section wake     # one section, when the work needs it
bin/time/saga-session-start.sh --check      # measure the head; exit 1 over budget
bin/time/saga-session-start.sh --full       # a human wants the whole truth
```

Most harnesses do this for you: OpenCode, Pi, Claude Code, Codex and Cursor each own a
session-start surface that speaks the head. Run it by hand when you want the truth again
mid-session.

The sections are `lock`, `bootstrap`, `wake`, `seats`, `supervision`, `todos`, `agents`,
`update`, `fleet`, `context`, `clock`, `today`, `recall`, `skills`, `models`, `assets`, `tools`,
`cron`, `liveness`, `next`. An unknown name is refused rather than printed empty.

## What you will see

The head carries:

1. **The fixed core** — `~/ymir` is public and delivers by PR; `$YMIR_HOME` is private and is
   edited through `bin/vault/home-sync.sh begin` / `ship`; apps run from the pin
   `~/ymir-runtime`; herdr and the stamped send door (`bin/agents/eindri-send.sh`); the Gná arm
   (`bin/voice/rodd-arm.sh who`) and that a session without it spawns, merges and drains
   nothing; the finding tools; the desk guard; the laws.
2. **The helm** — the lock (held by this session, or read-only and by whom) and the arm holder.
3. **What needs the Allfather** — wakes, decisions, questions and his open todos, as counts.
4. **The live errands** — the errands that still claim life, with pane and age.
5. **The next step.**

## Limits

- **A finished errand is news once.** It appears in the head the first time after it finished,
  then it is folded away. An older one — anything that finished before the last session start —
  never appears again.
- **An UNKNOWN row is reaped once.** A seat record whose pane can never be read here (a tmux
  window on a machine that no longer runs tmux) is reported once and then dropped. The record
  itself is untouched.
- **The head has a budget and it bites.** 60 lines and 8 KiB; `--check` fails over it, and CI
  runs that check as the gate `saga-head`. Move a block into a section instead of growing the
  head.
- **A compaction gets the head only** — no stages, no section bodies. The session start already
  ran.
- **The stages that change the hall are the helm's.** Taking the lock, sweeping finished seats,
  sweeping undelivered reports into the wake queue and raising the cron all happen at the
  **helm's** session start. A worker's session start (a seat takes its own lock) does none of
  it.
- **A page is not a session.** Hlidskjalf's Runtime page runs `--page`: it takes no lock,
  writes no lease and never reports the lock as its own, so a page load cannot look like a
  hand on the helm. The holder it names comes from the arm lease.
- **One hook, for the home you are in.** The user-scope Claude Code hook resolves the home the
  session is actually in (the project, then the pin) instead of three hardcoded paths.

## The warnings it now carries (2026-11-14)

Two questions the digest could not answer before, answered at every session start. Both are measured
against `origin`, read-only, and both are time-bounded.

**A worker branch pushed with no pull request.** A branch named `eindri/<id>` (or `agent/*`,
`claude/*`) that is on `origin`, older than four hours, and carries no PR — or a PR that was closed
without a merge — is named with its age, and the row says the exact command that would gather it.
Twenty-two such branches were found on 2026-11-14, only four merged.

**Commits that exist on no remote.** Every local branch, `main` included, is counted against every
remote. The row names how many commits are stranded, and which branches hold them. A commit on one
disk is a commit nobody can merge, and on 2026-11-14 nineteen of them sat on one machine's local
`main`.

Offline, the digest says the pull-request state was not read, rather than claiming a branch has none.
The rows are printed by `bin/time/saga-land-warnings.sh`, which you can run by hand at any time.

## If it does not work

| What you see | What to do |
|---|---|
| `READ-ONLY: the session lock is held by pid N` | A live primary owns the machine — that is correct for a worker seat. Inspect it with `bin/agents/eir-doctor.sh`. |
| The head is over budget | `--check` names the numbers. Move a block to a section; never raise the budget. |
| A section name is refused | `--list` is the whole list; the error names the command. |
| No digest in the harness | The session-start surface is not seated — `bin/seat/harness-extensions-install.sh --check`, then re-run it without `--check`. |
| Three digests appear at once | A hardcoded per-home hook survived. `bin/seat/harness-extensions-install.sh install` prunes it. |
| `first run of the head: N finished errand(s) folded away` | Not a fault: it is the head seeding its markers so old finished errands are never reported again. |

## CHANGE LOG

- **2026-11-14** — the digest became a 60-line head plus twenty on-demand sections (plan 275,
  item 28): the fixed core in one file, finished errands reported once, UNKNOWN rows reaped,
  the stages the helm's own, and one session-start hook that resolves the current home.
- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history
  (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
- **2026-11-14** — a LANDING section was added: the digest names worker branches pushed with no PR and commits that exist on no remote (plan 293 part 3).
