## forge · unversioned · 2026-11-07 — three seats, three places, and one door that seats all of them

The Allfather, watching the repair smith and the reviewer appear in different places: *"why did you not
spawn the repair smith and reviewer in the same?"*, then *"now they spawn in a three. are that correct"*.

**They must not be in the same place, and they were wrong in a different way than he could see.** The
plan has said this since 203 §12.1 — *"a judge reviews a CLONE of the delivered commit, never a smith's
worktree"* — and the two hands are seated by two different doors, only one of which worked:

| seat | where it must sit | why | before this note |
|---|---|---|---|
| **the judge** | `~/review/ymir` — a clone | it judges the commit that will be merged, never a hand's working copy | correct (seated by `review-seat.sh`, which creates its own workspace) |
| **a smith** | `.yggdrasil/<errand>` — a worktree | isolated branch work, and it must never edit the tree an agent is branching in | **wrong twice**: the door (`herdr-run.sh eindri`) needed an ALREADY-OPEN shell pane, which this seat never has, so every repair died with *"the pane must sit at an interactive shell prompt"*; and the one call site that did fire passed `--cwd $ROOT` — the main tree |
| **the loop itself** | `~/ymir-runtime` — the pinned runtime | a unit must not run a tree an agent checks out | correct since the pinned deploy |

### What changed

| file | change |
|---|---|
| `bin/forge/smith-seat.sh` (new) | **one door for any figure**: create a workspace at the working directory → take its pane → `herdr agent start` with the figure's role file and the errand brief → **verify the agent reached a live state** → hand it the prompt. This is the reviewer's proven sequence, extracted so a smith travels the same road |
| `bin/forge/repair-errand.md` (new) | the brief a refusing verdict dispatches: read the verdict, fix exactly what it names, run the wards, plain-push, stop |
| `bin/forge/conflict-errand.md` (new) | the brief a CONFLICTING head dispatches: merge main in (never rebase, never force), resolve by rule, wards, plain-push, stop |
| `bin/forge/review-verdict.sh` | on REFUSE/NEEDS-REWORK, seats a repair smith **in `.yggdrasil/repair-smith-<pr>`** at the judged head, and records it |
| `bin/forge/review-watch.sh` | a CONFLICTING head seats a conflict smith **in `.yggdrasil/conflict-smith-<n>`**, once per head |

### The fault that made the smith door silently useless

`herdr agent start pi …` uses **`pi` as the agent name**, and herdr requires names unique among live
agents — so once the reviewer was seated, every later smith was refused with `agent_name_taken`. The
door now names each seat after its label (`repair-smith-552`, `conflict-smith-566`). **Proven:**

```
smith-seat[5]{figure,workspace,pane,model,state}:
  "sindri","w7","w7:p1","opencode-go/beam-free","idle"
```

and the refusal before it, in herdr's own words: `agent_name_taken … candidates: pane_id=w4:p1
workspace_id=w4 … cwd=/home/zerwizserver/review/ymir` — the reviewer's own pane.

### Not done

- The dispatch still needs a herdr server (the heart has one). Where herdr is absent, `smith-seat.sh`
  refuses and says so; no silent fallback is invented.
- The reviewer's seat names itself `pi` too, so two judges cannot be seated at once — the same
  collision, waiting for the same one-line fix in `review-seat.sh`.

## CHANGE LOG

- 2026-11-07 · one seat door for every figure; smiths seated in worktrees, judges in the clone, the
  loop in the pinned runtime; the name collision that made the smith door useless, proven and fixed.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: the fleet's always-on heart. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
