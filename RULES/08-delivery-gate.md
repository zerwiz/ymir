# Rule 08 — Delivery Gate & Worktree Engine

## 08.1 Every Change Leaves by Pull Request

**No direct pushes to `main` or any protected branch.** Every change — code,
config, docs, scripts — must:

1. Be done in a Yggdrasil worktree on a feature branch
2. Pass all local gates (lint, typecheck, tests)
3. Be pushed as a branch
4. Opened as a Pull Request via `gh pr create`
5. Reviewed in Glitnir (human review)
6. Approved by the Allfather
7. Merged via the PR interface — **never locally**

A local merge on a verbal "word" is a decision, not a delivery. It leaves
Glitnir with nothing to review. The gate is only fed by a PR.

**Exception:** None. If work is already on local `main`, ship it as a PR (a
branch at that commit) before doing anything else.

## 08.2 Yggdrasil Worktrees Use treehouse

**All worktree operations go through `treehouse`** (github.com/kunchenguid/treehouse).
Never use raw `git worktree` commands directly.

| Operation | Command |
|-----------|---------|
| Create worktree | `bin/forge/yggdrasil.sh create <branch>` |
| List worktrees | `bin/forge/yggdrasil.sh list` |
| Remove worktree | `bin/forge/yggdrasil.sh remove <branch>` |
| Sync worktree | `bin/forge/yggdrasil.sh sync <branch>` |

The `bin/forge/yggdrasil.sh` script is the Norse shell over the treehouse engine.
It handles:
- Branch creation from correct base
- Worktree path management under `.yggdrasil/<agent-id>/`
- Remote tracking setup
- Cleanup on completion

## 08.3 Utgard Sandboxes Use sandcastle

**All untrusted code, dynamic skills, and sub-agent tasks run inside Utgard**
via `sandcastle` (github.com/mattpocock/sandcastle, @ai-hero/sandcastle).
Never run untrusted code on the host.

| Operation | Command |
|-----------|---------|
| Spawn sandbox | `bin/forge/utgard.sh spawn <profile>` |
| Run in sandbox | `bin/forge/utgard.sh run <profile> <cmd>` |
| Destroy sandbox | `bin/forge/utgard.sh destroy <id>` |

Utgard enforces: CPU/RAM/timeout caps, no host root, no network by default.
A failed Utgard execution never touches main.

## 08.4 Enforcement

- **Pre-push hook** (installed by `bin/engine/ymir-install.sh`) rejects direct pushes
  to protected branches
- **CI gate** (`.no-mistakes.yaml` + `no-mistakes` skill) validates PRs before
  merge
- **Mjollnir pipeline** (`bin/forge/mjollnir.sh`) automates issue → worktree → PR

## 08.5 References

- `bin/forge/yggdrasil.sh` — treehouse wrapper
- `bin/forge/utgard.sh` — sandcastle wrapper
- `bin/forge/mjollnir.sh` — issue→PR pipeline
- `.no-mistakes.yaml` — clean-PR gate config
- `RULES/02-agents.md` — agents are canonical, harness dirs are symlinks
- `RULES/05-platforms.md` — core portable, per-OS layers updated together

---

*Append-only. A correction is a new entry citing the old one.*
---

## 2026-11-05 (appended) — the seat seals its OWN PR, and the word arrives through Gná

The Allfather's word, plan 190 §1:

> *"The arm holder ALWAYS NEED TO GET A NOTIFICATION IN THRU THE ARM on when a PR are done. And merge
> that PR directly. Otherwise main will move and merge will have conflicts"*

§08.1 above remains the law for every other change, and it remains the law for another hand's PR without
exception. What changes is one narrow case: **the seat's own PR, sealed by the seat's own agent, the moment
it is green** — because a PR left open is a branch drifting from a moving `main`, and every hour of delay
buys a rebase. The seal is not "skip review": review happens at open time, by the seat, before the base
moves, and the Glitnir surface still shows every PR; it simply no longer queues them.

```
seal[6]{condition,rule,evidence}
  "whose PR","THE SEAT'S OWN — opened by this seat or an Eindri it dispatched. Another hand's PR is NEVER merged by us","the PR body carries `Arm: <seat host>`, or its head is `eindri/<id>` for an errand this seat dispatched (state/<id>.meta)"
  "what state","CI green and no conflicts","every check concluded SUCCESS/NEUTRAL/SKIPPED, and mergeable MERGEABLE with no DIRTY/BEHIND/BLOCKED state"
  "who merges","the seat's agent — Sindri on nidavellir, Hœnir on heimdall — never a worker, never a timer alone","bin/agents/pr-seal.sh seal <n> is run by the seat; the arm only wakes it"
  "when notified","through Gná's arm, as a WAKE line in state/.wake-queue, naming PR, head, checks and the exact merge command","bin/agents/pr-seal.sh watch, one wake per (PR, head sha)"
  "the record","ONE Runes entry per seal naming the PR, its head and its merge commit","bin/records/runes-append.sh — carved by the seal, not remembered afterwards"
  "the brake","state/.seal-hold present means the seat merges NOTHING and says why","checked immediately before the merge, and again at watch"
```

**No merge on red or conflicted, under any flag.** The seal re-checks all six conditions at the instant of
the merge — a watch that said green an hour ago is not evidence now — and a refusal names the condition that
failed and stops. It never retries blindly. A worker never merges its own PR: the sixth condition's author
is the seat, and a worker that runs `seal` is refused by the one-open-PR and ownership checks it cannot pass.

The arm is Gná's: `watch` raises the word, the seat acts on it. A PR of this seat that was green and is then
superseded raises a new wake at a new head sha, and a wake already carried is never re-raised for the same
head — the flood brake this house has already paid for.

The tool is `bin/agents/pr-seal.sh` (`watch` · `seal <n>`); the law it enforces is this section.

---

## Appended 2026-11-06 — the delivery switch: a project may declare that its reviewer merges

**The Allfather's word, and it settles a contradiction this rule has carried since plan 203 §10:**
*"why aren't the heart reviewing all prs that comes in on the ymir repo and merging them … we have 3 prs
open."* The reviewer merges — on `zerwiz/ymir`, every PR that comes in, not only the seat's own.

**This is a declaration, not a mood, and it lives in one row.** `hodd/identity/projects.yaml` carries a
`delivery:` key per project:

```
delivery[2]{value,meaning}
  "operator-merges","DEFAULT. A PR is delivered when the Allfather merges it, by his own hand. Unchanged."
  "reviewer-merges","the project's reviewer merges, on a green, non-conflicting head, with a merge record — and the Allfather can revert, re-open a review, or withdraw the switch in one line."
```

**The six conditions are not replaced; they are re-owned.** A `reviewer-merges` project keeps every refusal
above — no merge on a red gate, on a conflict, on a missing review record, on an unverified claim, on a head
that moved after the packet, or on the reviewer's own authored work — and adds two of its own:

```
reviewer_merges[4]{rule,why}
  "the reviewer judges in a FRESH context and runs the gates itself","a claim read from a packet is not evidence; the tests run where the merge will land"
  "ONE Runes entry per merge, naming reviewer, reviewed sha, ruleset id, gate output, merge commit and the moment","a main that moved must be explainable without asking anyone"
  "the reviewer's identity can merge and cannot force-push, delete a branch, or administer","a reviewer that can rewrite history is not a gate"
  "the Allfather is told of every merge — MERGED with the record, or ASK with the question","the authority he keeps is the account, the veto, and the rule"
```

**Which projects have said so, and how to unsay it:** the row in `hodd/identity/projects.yaml`. Today
`ymir` reads `reviewer-merges` at his word; every project that does not name the key stays `operator-merges`.
Changing the row back is the whole withdrawal, and it takes effect at the next judgement.

**What this does not permit.** A reviewer that merges its own authored work (it is a reviewer, not an
author); a reviewer acting on a packet it did not read; a watch or a timer that merges without a judgement
(`bin/forge/review-watch.sh` asks, it never merges); and any merge whose record cannot be written — a merge
with no record is refused, because the record is what makes `main` explainable.

The doors are `bin/agents/eindri-review-spawn.sh --pr <url>` (seat the judge once per head),
`bin/forge/review-watch.sh` (the trigger), `bin/seat/lock-ask.sh` (the read-only agent's mouth) and
`bin/notify/mail.sh` (the word reaching him).

---

## Appended 2026-11-12 — two more roads: documents may land on main, and a batch ships once

This section amends §08.1 ("Exception: None") and the 2026-11-05 and 2026-11-06 sections above.
They stay as the record of what was law before. Everything not named here still leaves by PR.

### Road one: a push of documents only may land on `main`

The Allfather's word: *"documents should be able to push on main."* A one-line document fix
does not need a branch, a PR and a merge by his hand.

A push may land directly on `main` when **every file it changes** is a document by this exact
set, and the push is a fast-forward of what `main` already is.

| Path | What may change | Why the limit |
|---|---|---|
| `docs/**/*.md` | added or modified | the person-facing pages |
| `docs/fixes/<component>/*.md` | **added only** | a fix note is never rewritten (Rule 06) |
| `RULES/*.md` | added, or modified with **zero deleted lines** | the rules are append-only (Rule 06) |

Everything else still leaves by PR. That includes:

- code, scripts, config and apps, anywhere;
- `AGENTS.md`, `CLAUDE.md` and any skill, because they change how agents behave;
- `docs/features/_catalogue/**`, because those fragments are woven into `FEATURES.md`;
- any non-Markdown file under `docs/`;
- a deletion or a rename, even of a document (Rule 11);
- a push that is not a fast-forward, or that creates or deletes `main`.

A push that mixes one document with one line of code is a code push. It goes by PR.

> [!IMPORTANT]
> A rule change is a document, so it may land on `main`. But **a rule change still carries its
> fix note** in the same push. A change of law keeps its record. Other document-only pushes owe
> no fix note.

**How it is enforced.** `bin/gates/guards/branch-guard.sh` judges each pushed ref. A push to a
protected branch passes only when `branch-guard.sh --documents <remote-sha> <local-sha>` says
the range is documents only; otherwise it is refused and the refusal names the first file that
is not a document. `bin/gates/guards/fixes-guard.sh` asks the same question, and owes no note for
a document-only range unless a `RULES/` file changed. Every other pre-push ward still runs, and
CI still judges `main` after the push. The tests are
`.agents/tests/branch-guard-documents.test.sh`.

### Road two: errands sent out together ship as one batch

The Allfather's word: *"If multiple agents are sent out at the same time, it's much better to
merge the branches locally into one push, instead of one push per errand, so everybody is going
through the gates."*

When several errands are dispatched together:

1. Each errand's brief says `Delivery contract: mode=batch` (`bin/agents/erindi-brief.sh <id>
   <repo> --mode batch`).
2. Each errand commits on its own `eindri/<id>` branch, runs its own tests, leaves `git status`
   clean, records its work in the well, and acclaims `committed on eindri/<id> (not pushed)`.
   **It never pushes and never opens a PR.**
3. The helm gathers the batch with **one door**: `bin/forge/gather.sh <id…>` or
   `bin/forge/gather.sh --finished`. It makes one integration worktree from fresh
   `origin/main`, merges each branch there, and stops on a conflict, naming the branch and the
   files. The helm resolves the conflict in that worktree and runs `gather.sh --continue
   <batch>`.
4. The door runs the pre-push gates **once** on the gathered head, pushes **one** branch and
   opens **one** PR. The PR body lists every errand with its one-line acclaim.
5. The door records the batch in the well and appends `done: shipped in PR <url>` to each
   errand's status, so no errand is gathered twice.

The PR is still the Allfather's to merge, or the reviewer's where the project says
`reviewer-merges`. Nothing about who merges changes.

**A lone errand may still push its own PR** (`--mode direct-PR` or `no-mistakes`). The batch road
is for errands that run at the same time, where one push per errand would race `main` and
re-run the gates for each.

The how-to is `docs/features/gather-a-batch.md`. The tests are `.agents/tests/gather.test.sh`
and `.agents/tests/erindi-brief-batch.test.sh`.

**A batch merges with a merge commit, not a squash** (appended 2026-11-12). The Allfather asked *"why are we
always squash merging?"* A squash erases each errand's history and leaves git thinking the branches are unmerged.
`bin/forge/merge-method.sh` is the one place the choice is made: a head branch `yggdrasil/gather-*` or `gather/*`,
or a body saying it was gathered by `gather.sh`, takes `--merge`; every other PR keeps `--squash`.
`ship.sh`, `queue-warden.sh` and `pr-seal.sh` ask it. The fix note is
`docs/fixes/forge/2026-11-12-the-merge-method-follows-the-prs-kind.md`.
