# A far repo becomes a hall — the clone door

**Date:** 2026-11-06 · **Plan:** 210 §P3 · **Component:** forge

## Why it exists

`intake` reads every registered repo with no working tree at all: it asks GitHub. But **fixing** needs
a tree, and the first measurement of the registry found **67 of 78 rows with no clone on this machine**
(`doctor`: 11 `far`, the rest unnamed). A reader with no hands is a library; this door gives it hands.

## What it does

```
bin/forge/mjollnir.sh clone <id> [--dir <path>] [--from <url>]
```

It resolves the row, resolves the destination through **the same resolver** `doctor` uses
(`project-git.sh --field clone`), clones, and prints a `hall[1]{project,path,branch,remote}` row. After
that, `--field path` answers with the same tree and `doctor` moves the row from `far` to `ready`.

The destination is the canonical hall `$YMIR_HOME/halls/<owner>/<repo>` unless the registry row's own
`repo:` path already names a tree. **One resolver, so the diagnosis and the door cannot disagree** —
`doctor` no longer derives clone paths itself; it reads `project-git.sh paths`.

## The three refusals (each one is worse than no clone)

| refused | why |
|---|---|
| cloning over an existing tree | a tree is not a cache; a half-clone over a hand's work loses it |
| a destination **inside the public code tree** | the tree ships (Rule 04); a workspace does not live in a published repo |
| a row that cannot name a remote | a guess about which repository a row means is worse than a named fault |

A **failed** clone removes the directory it created, so a retry is not blocked by a corpse.

## Proved (twelve proofs, no network)

`bin/gates/tests/test_mjollnir_clone.sh` builds a real bare repository on disk and a fixture registry,
then drives the door: the resolver names the hall before any clone; the clone lands there and prints
its row; the resolver then answers `here` with the same path; a second clone is refused; an unnamed row
is refused **and the refusal names `doctor`**; an in-tree destination is refused and leaves nothing; a
failed clone leaves nothing and says so.

```
$ bash bin/gates/tests/test_mjollnir_clone.sh
ok   the resolver names the hall a clone would land in
ok   a row with no tree refuses to name one
ok   the clone lands in the canonical hall
ok   the door prints the path as a TOON row
ok   the resolver now answers with the same path (here)
ok   a second clone is refused, naming the tree
ok   a row with no git{} block is refused
ok   the refusal names the remedy (doctor)
ok   a hall inside the public tree is refused
ok   the refused in-tree clone left nothing
ok   a failed clone leaves nothing behind
ok   a failed clone says so

all proofs held
```

## What this does not do

- **It does not adopt a row.** A row with no `git{}` block is refused, not guessed at — healing the
  remaining unnamed rows is a human-confirmed pass (§P0.2).
- **It does not register the hall back into the registry.** The path is derivable
  (`$YMIR_HOME/halls/<owner>/<repo>`), so there is no second table to fall out of step.
- **It does not fetch later.** Keeping a hall current is `git -C <hall> pull`, or the session-start
  sync — not this door's business.

## Files

- `bin/forge/mjollnir.sh` — the `clone` verb (VERSION 1.1.0)
- `bin/agents/project-git.sh` — `paths` verb and `--field path|clone` (the one resolver)
- `bin/gates/tests/test_mjollnir_clone.sh` — new, twelve proofs
- `.agents/skills/galdr-ymirsystem/assets/mjollnir.md` — the door documented

## CHANGE LOG

- **2026-11-06** — written with the door (plan 210 P3).
