# 2026-11-01 — the collaboration doors: one roll, one shelf, one letter, one ship

**Component:** collab (Vingólf) · **Doors:** `bin/collab/collab.sh` · **Plan:** 154 · **Skill:** `vingolf`

## Why

The Allfather asked for one thing to be repeatable that had been done by hand: *"all things you did now must be
able to be done over and over simple."* What was done by hand was a fifteen-call audit of who had been invited into
Gimlé and whether anyone used it, a collaboration plan written into the ledger, a letter to a partner, and a
branch-commit-merge on another repository. Each of those is now a verb.

## What landed

| Door | What it does |
|---|---|
| `collab.sh who` | reads the register, measures `zerwizserver` over ssh (gate users and the authentication log, the Board's accounts and last sign-in, Documents' accounts, the forge's accounts and key counts, the shell), and prints one row per person |
| `collab.sh ladder` | the register: the six rungs, who is on which, what each owes, which projects carry the shelf |
| `collab.sh init <repo>` | installs the baton shelf into any repository — `handoff/README.md`, `TEMPLATE.md`, `CURRENT.md`, `log/`, `check.sh` + `check.py` — and prints the line that wires the check into that project's gate; never overwrites; checks the shelf a repository already has |
| `collab.sh letter` | renders `letters/collaboration-files.md` and leaves it as a **draft** in the mail gate; there is no send path in it |
| `collab.sh ship` | branch, commit **named paths only**, merge into the base, push — the house's git discipline as one door |

The register is `$YMIR_HOME/hodd/data/collaboration.yaml`: declared truth, so no person's name appears in code.
The shelf's own check is a portable `python3` file copied into the project, so a repository can gate itself with
no Ymir installed.

## The faults this was built through

1. **A cursor reused inside its own iteration silently returns one row.** `who` reported "no sign-in" for five of
   six people until the login rows were read into a list before the per-user query. The symptom looked like a
   permissions problem; it was a driver behaviour.
2. **A fresh `git init` has no `HEAD`.** `init` died with `set -e` on `git rev-parse --abbrev-ref HEAD` in a
   repository with no commits — a shelf installer must survive the one repository state every new project starts in.
3. **A baton is checked, not rewritten.** The first version of the test expected a second `init` to refuse; the
   right behaviour is to *check* the baton that is there and refuse only to overwrite a stray file.
4. **`grep 'mail-send.sh send'` is not a send-path proof.** The door prints that string in its help text. The test
   now asserts that the only invocation is `args=(draft ...)`, which is what "cannot send" actually means.

## Proofs

`bash bin/collab/tests/test_collab.sh` — 21 checks, no network and no server: install, never overwrite, a check
that refuses an incomplete baton and passes a complete one, `who` from a captured measurement (a house sign-in is
labelled `house+loopback`, a remote sign-in is absent, a missing email is named as a gap), the letter renders and
only drafts, and `ship` refuses a path with nothing at it.

Measured live on 2026-11-01: `who` reproduces the hand audit in ~2.5 s (6 gate accounts entered, 0 remote
sign-ins, 0 second factors, 0 forge keys); `init --check` on `Inmost-ControlTower` finds its own
`mix ct.handoff` checker and passes.
