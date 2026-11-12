# gates · 2026-11-12 — the NDA gate: company and client names never reach the public repo

**Status:** phase 1 of plan 268, done on branch `eindri/nda-gate`. History is **not** rewritten; that is the Allfather's call.

**In three sentences.** An inventory of the operator's project folders, `home-codep.txt`, was committed to `main` by
accident on 2026-11-05 and no ward could tell it was private. The file is now removed, a new ward refuses any
company, client or NDA-project name in a commit, a push or a write, and the tree was swept clean. The names the ward
checks are read from the operator's home at run time and never enter this repository.

## What was wrong

The wards read secrets, document hashes, markers and people. None knew a company's or a client's name is private
data, and nothing watched the repo root for stray files. The file rode in beside an unrelated change in commit
`5ec44380`.

## What changed

| What | Where |
|---|---|
| The matcher, one module | `bin/gates/guards/ndalib.py` |
| The guard and its commands | `bin/gates/guards/nda-guard.py`, `nda-guard.sh` |
| Words allowed, each with a reason | `config/nda-allow.yaml` |
| Git hooks | `.githooks/pre-commit` (staged diff), `.githooks/commit-msg` (message), `.githooks/pre-push` (pushed range) |
| The tree ward | `bin/gates/guards.sh` (`WARDS` and `SCOPED`) |
| The Claude Code write hook | `.claude/hooks/nda-write.sh`, seated by `bin/seat/harness-extensions-install.sh` |
| Hook install for plain checkouts | `bin/gates/guards/fixes-guard.sh --install` also copies the two new hooks |
| Inventory shapes ignored | `.gitignore`: `/home-*.txt`, `/*-inventory.txt`, `/*-inventory.md` |
| The law | `RULES/04-hoard.md`, section appended 2026-11-12 |
| The test | `bin/gates/tests/test_nda_guard.sh` (a fake home, invented names only) |

Where the names come from: `companies.yaml`, `clients.yaml`, `projects.yaml` (not Ymir's own, not public), the realm
folders under `svartalfaheim/`, and an `nda:` list in `confidential.yaml` for names added by hand. See
`docs/features/the-nda-gate.md`.

## The sweep

The matcher over the whole tree found 279 hits in 113 files before the allow list and the sweep. Nothing needed to be
moved; every hit was a name inside a test, a doc or a fix note, and each was replaced by a neutral token
(`example-N` or `ExampleN`, one number per name, the same in every file so tests stay consistent). The 112 files
that changed are mostly tests, fix notes and feature pages. Fix notes are append-only; this redaction is a
deliberate, format-only exception recorded here, because a name in them is a leak. The ward now reads zero hits.
The file `home-codep.txt` was removed with `git rm`; the command that wrote it was not found in `bin/` or
`scripts/` — it was a one-off. The `.gitignore` rules stop the shape coming back.

> [!IMPORTANT]
> Tests in swept files were checked for shell and Python syntax only, not run. The helm should let CI judge them.
> One email-body file under `midgard/` carries a person's name in its path; that is for `people-guard`, not this ward.

## History: the Allfather's decision

The file is still in history after it is deleted. Do nothing until the Allfather decides.

| Item | Where |
|---|---|
| Commit on `main` | `5ec44380` |
| Commit on `rescue/local-main-2026-11-06` | `fe4d3281` |

**The command** (on a fresh mirror clone, never in a working checkout):

```bash
git clone --mirror git@github.com:zerwiz/ymir.git ymir-purge.git && cd ymir-purge.git
git filter-repo --path home-codep.txt --invert-paths
git push --force --mirror origin
```

**What a force push does.** Every commit after `5ec44380` gets a new hash. Every clone and fork must be re-cloned or
reset; any local work must be rebased onto the new history. Every open PR is orphaned and must be reopened from a
rebased branch. Forks already taken keep their own copy and we cannot clean them. Pinned runtimes, seat checkouts and
any recorded commit id (`pin`, `gen`) drift and need refreshing. Branch protection on `main` must be lifted for the
push, then restored.

**GitHub keeps cached views.** Commit URLs and PR diffs stay reachable by hash after a rewrite. Ask GitHub Support
to run garbage collection and to purge cached views and the PR references (`refs/pull/*`) that carry the file.

**The honest option.** Delete now, gate forever, and purge only if an audit or a client needs the history clean.
The full-history audit is phase 4 of plan 268.

## How it was proved

`bash bin/gates/tests/test_nda_guard.sh` passes 25 of 25: names from every registry, whole-word and case rules, the
allow list (a reasonless entry is ignored), a loud `UNARMED`, the three git hooks refusing in a throwaway repo, and the
write hook denying and allowing. The whole-tree scan reads zero hits.

## CHANGE LOG

- 2026-11-12 — written with the gate (plan 268, phase 1).
