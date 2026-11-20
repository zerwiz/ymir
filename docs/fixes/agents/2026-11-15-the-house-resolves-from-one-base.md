# Fix — the spawn door resolved the operator's records from the code tree

**What was wrong.** No Eindri could be sent from the heart. `bin/agents/eindri-dispatch.sh new …` refused with:

```
error: the house is split — data and config resolve to different bases.
  data:  $HOME/ymir/data
  config:$HOME/Documents/ymirhome/config
```

The guard was right; the resolution was the fault. Four doors — `einherjar-spawn.sh`, `eindri-dispatch.sh`,
`erindi-brief.sh`, `eindri-arm.sh` — derived the records from `BROKK_HOME`, which on this seat is the **code tree**
(`~/ymir`). The operator's records live in the home's hoard (`<home>/hodd/data`); a code root has none of its own. So
with `BROKK_HOME` naming the repo, `DATA` became `<repo>/data` while `CONFIG` stayed `<home>/config`, and the split
guard — correctly refusing one errand with two homes — stopped every spawn before a worker was seated. The backlog file
was written into the repo's empty `data/` for the same reason.

**What was done.**

1. `einherjar-spawn.sh` resolves `DATA`, `CONFIG` and `STATE` through **the one resolver** (`bin/vault/hoard-lib.sh`), as
   every other door does: `<home>/hodd/data`, `<home>/config`, `<home>/state`. The `BROKK_*_OVERRIDE`s still move them,
   and they are validated: **data and config must lie inside the home the resolver named**, which is the real layout
   (`<home>/hodd/data` beside `<home>/config`) and which the old equal-*dirname* rule could never satisfy. With no home
   resolvable the old equal-base rule still stands. A state dir outside the home remains what it always was — a seat's
   own state, announced aloud, never a split.
2. `eindri-dispatch.sh`, `erindi-brief.sh` and `eindri-arm.sh` resolve `DATA` the same way, so the backlog, the brief and
   the arm record live where the rosters are.
3. `eindri-dispatch.sh`'s dry-run line named the **repository** as `worktree=`, which read as "seated in main". The spawn
   door has always cut `<BROKK_HOME>/.yggdrasil/<id>`; the dry run now prints that path, and keeps the repository under
   its own `repo=` word.

**Proof.** Measured on the heart the same morning, with the environment that had split the house:

```
before:  error: the house is split — data … $HOME/ymir/data
after:   armed plans-state · worktree=$HOME/ymir/.yggdrasil/plans-state
         open: plans-state → $HOME/Documents/ymirhome/hodd/data/backlog.md
```

and the errand was then spawned for real (worktree cut, worker seated).

- **2026-11-20** — redacted: a machine, a user or a person named above now reads as a role or an invented example (RULES/04 · plan 287 §3). No fact of the fix changed; the original text stands in the repository's history.
