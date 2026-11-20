# The nightly home map ships itself, and an unchanged night writes nothing

**2026-11-20.** Found as a dirty home every morning: the night's own job rewrote the assistant's
fact shelf and committed none of it, so the operator's private repository had to be cleaned by hand.

## What was wrong

The Nornir row `@dev 03:05 systems/skirnir/services/learn-home.sh` writes one fact file per document
the home is made of, under `$YMIR_HOME/hodd/identity/assistant/approved/`. It did two things badly,
and the two faults fed each other.

It **stamped every copy on every run** — `approved_at:` is today's date and `generated_at:` is the
current time — and rewrote the file whether or not one word of the claim had changed. One thousand
three hundred copies, one thousand three hundred writes, on a night when nothing in the home had
changed at all.

And it **never committed what it wrote**. The job ended where the writing ended. Measured the next
morning on a second machine: 489 modified files and 30 untracked ones, nearly all of them a stamp and
nothing else. The home was cleaned by hand in `ymirhome` commit `8aeecb8b`.

## What changed

**A fact is rewritten only when its text changes.** `approved_at:` and `generated_at:` are stripped
from both the file on disk and the file about to be written, and the two are compared. Equal text
means the copy is left exactly as it is, so an unchanged night is a zero diff.

**A non-dry run ships its own output** through the one door for editing the home, with the named
path only: `bin/vault/home-sync.sh ship "<message>" hodd/identity/assistant/approved` (RULES/50). The
message reads `skirnir: the home map, regenerated (N written, M retired)`. A failed ship prints the
reason it already prints and exits non-zero (`4`); a home that is not a git repository is refused
before anything is attempted (`5`).

**A no-change night ships nothing and says so.** The decision is read from the tree, not from the
counters — `git status --porcelain -- hodd/identity/assistant/approved` — so a night that wrote
nothing still ships work an earlier run left uncommitted, and a night whose facts are identical
prints `learn-home{ship,status}:"skipped","no-change"`.

**A retired fact moves instead of vanishing.** A copy is retired only when its source document is
gone (the discipline added on 2026-11-19). It is now moved into `approved/_retired/<name>.md`, inside
the same generated shelf, so git records a rename. `kb-export` reads the top level only, so the fact
stops answering; the record survives.

**Two flags** make a hand run and a test possible: `--no-ship` writes the facts and leaves the commit
unmade, and `--dry-run` writes nothing, commits nothing, pushes nothing.

## Why the removal is a move and not a deletion

The brief asked whether `home-sync.sh ship` accepts a staged deletion of a generated mirror under a
`merge=ours` path. Measured on a throwaway home with a local bare remote:

| named path | result |
|---|---|
| the file, deleted | `home-sync: refusing to delete tracked … (Rule 11 — retire by moving)`, exit `1` |
| the shelf directory, one file deleted inside it | `shipped`, exit `0` — the deletion went through |

So Rule 11 does hold at the door, and it can be walked around by naming a directory. That is a bypass,
not a law, and a generated mirror is not a large enough reason to weaken a rule that governs the whole
home for every seat's cron. The retirement therefore moves the copy inside the generated shelf and
names the directory honestly: the ship carries a rename.

## What proves it

`bash systems/skirnir/tests/test_learn_home_ship.sh` — 20 assertions, all green, on a throwaway git
home with a local bare remote, so the operator's own home is never touched:

- an unchanged second run rewrites 0 facts, makes 0 commits, leaves the tree clean, and says
  `no-change`;
- a changed source document ships exactly one commit, and the tree is clean afterwards;
- `--no-ship` rewrites the changed fact, leaves it uncommitted, and says so;
- a source document that is gone retires its copy into `approved/_retired/`, the copy no longer
  answers at the top level, the ship carries it as one commit, and `git diff --diff-filter=D` is empty
  (Rule 11 held);
- `--dry-run` changes not one file and makes no commit.

The gate that runs it is `bin/gates/checks.d/0540-learn-home-ship.sh`.

The stamp marker in the copies (`generated_by: bin/assistant/learn-home.sh`) is deliberately left at
its historical path: 1,552 copies in the home carry that exact line and the retire pass finds its own
copies by it, so moving the door (plan 149) is not a reason to rewrite the whole shelf for a comment.

## What is not changed

The home's `config/cron.yaml` row is untouched — the fix is in the job, not in the schedule. The
home's own fact shelf is rewritten by the next nightly run, and that run ships it.

## Files

- `systems/skirnir/services/learn-home.sh` — the stamp-free comparison, the ship, the retirement move,
  `--no-ship` and `--dry-run`.
- `systems/skirnir/tests/test_learn_home_ship.sh` — the proof above.
- `bin/gates/checks.d/0540-learn-home-ship.sh` — the gate that runs it in CI.
