# Worktree housekeeping — what the worktrees cost, and what is safe to forget

> **Status:** shipped 2026-10-20. Read-only by default; reclaiming needs your `--yes`.

## What it is

An audit of every **Yggdrasil worktree** and every **local branch**, with one verdict each —
and, the reason it exists, a loud list of the work that exists **only on this machine**.

Measured on this box when it was written: `.yggdrasil/` held **5.9 GB across 55 worktrees**
and the repo carried **144 local branches**, most of them work long since landed on
`origin/main`.

## The verdicts

| verdict | meaning | what happens on `clean --yes` |
|---|---|---|
| `reclaimable:merged` | every commit is already in `origin/main` | the worktree and branch are removed |
| `reclaimable:pushed` | `HEAD` is exactly the remote branch | the worktree and branch are removed |
| `keep:dirty` | uncommitted changes | **never touched** |
| `keep:unpushed:N` | N commits that exist nowhere but here | **never touched** — push or merge |
| `keep:detached` · `keep:main` · `main-worktree` | review worktrees and the checkout itself | **never touched** |

## The commands

```sh
bin/forge/housekeeping.sh             # the report (TOON)
bin/forge/housekeeping.sh report --json
bin/forge/housekeeping.sh check       # exit 1 when anything is unpushed (cron/gate friendly)
bin/forge/housekeeping.sh clean       # the PLAN — nothing is removed
bin/forge/housekeeping.sh clean --yes # remove only what was proved reclaimable
bin/forge/housekeeping.sh clean --yes --merged-only   # only work already IN origin/main
```

## How it stays safe

- **Prove, then act.** `clean` re-asks each verdict immediately before touching it; if the
  state changed, it says so and moves on.
- **The safe git forms only.** `git worktree remove` (no `--force`) and `git branch -d`.
  `git branch -D` is used ONLY when the tip is proven an ancestor of the base — because `-d`
  judges "merged" against the *current* checkout, which may sit on a feature branch (it did:
  `feat/snotra-letter`), and would otherwise refuse a branch that is fully merged into `main`.
- **`--merged-only`** is the strictest form: only work already in `origin/main` is reclaimed.
  A pushed branch with an open PR is deliberately kept, because you may still be working in it.
- **The main checkout and `main` are never candidates.**
- **The cron row is report-only** (`bin/time/nornir-job-worktree-housekeeping.sh`, `@heart
  00:45`): it writes the reckoning into `hodd/memory/worktrees/<date>.md` and exits non-zero
  when work is unpushed. Reclaiming is always a human's word.

## If it does not work

| symptom | cause | remedy |
|---|---|---|
| `keep:unreadable` | a worktree whose git metadata is gone | `git worktree prune` then re-run the report |
| `refused:"…" changed to keep:dirty` | something wrote into the tree between the plan and the act | commit or discard it, then re-run |
| `kept-branch:"…" (git refused — not merged)` | the branch has unique commits | push it, or merge it into `main` first |
| nothing is reclaimable | everything is genuinely unpushed | push or merge — that is the finding, not a failure |

## What counts as "in use" — corrected 2026-11-10

The report used to ask only whether some **process** stood inside a worktree. An Eindri
exits into a bare shell, and herdr restores that shell after a restart — so the shell's
own working directory kept its worktree `keep:in-use` forever, and 80 trees under
`.yggdrasil/` could never be reclaimed.

Now it asks whether an **agent** stands there (`bin/seat/herdr-agents.py`, the one
reader of `herdr agent list`):

- **a live agent** — `keep:in-use`, never touched;
- **a bare shell, no agent** — the tree is judged by the ordinary verdicts
  (`reclaimable:merged`, `keep:unpushed:N`, …) and the report says
  ``bare shell, no agent`` so you know why it moved;
- **when the agent list cannot be read at all** the old answer stands (`keep:in-use`),
  because assuming a seat is dead is the irreversible direction.

On `clean --yes` a bare shell is closed first — through
`bin/seat/seat-reap.sh --shell`, which refuses a live agent — and if it will not close
the worktree is left alone. The same door closes a finished errand's whole herdr
workspace when the arm takes the helm; see
[the seats and the arm](the-seats-and-the-arm.md).

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
