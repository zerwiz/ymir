# The warden stopped merging

**Date:** 2026-11-14 · **Component:** forge · **Door:** `bin/forge/queue-warden.sh`

## What was wrong

A laptop's clock was deciding what reached `main`. `queue-warden.timer` on heimdall ran
`bin/forge/queue-warden.sh run` every ten minutes, and that door **merged**: it fetched each open PR's
branch into a scratch worktree, merged `main` into it, resolved a generated-file conflict by running
the registers and committing with `--no-verify`, pushed the branch back with `YMIR_SKIP_FIXES_GUARD=1`
under `gh auth token` (the operator's own login), then ran `gh pr merge`. PRs #732–#735 and #742–#743
reached `main` that way: untested major version bumps next in the queue, the `whole-tree` gate red,
and every merge carrying `craigmartin`'s name as if he had done it.

The heart ruled on it on 2026-11-14 at 11:38 CET (plan 290, section *P1 decided by the heart*):

> **heimdall's queue-warden must not merge anything.** Merging under a failing `whole-tree` gate breaks
> the delivery gate and gate parity; merging under `craigmartin`'s login makes authorship false. The
> queue-warden stays for **hygiene only**: cap five open PRs, flag stale ones, re-cut, never merge,
> never force.

## What changed

The merge road is gone, and it was **removed as a recorded change, not a silent deletion** (RULES/11,
RULES/06): what it used to do is written above, and the old fix note `docs/fixes/forge/queue-warden.md`
stands unedited beside this one.

| It used to do | It does now |
|---|---|
| `gh pr merge` every open PR | **no merge call exists in the file at all** — the test asserts the absence |
| merge `origin/main` into the PR's branch, then force the branch to the remote | rebase the PR's head onto `origin/main` and land it on a **NEW** branch, `rehygiene/<pr>-<branch>-onto-main-<date>`; their branch is read, never written |
| push with `YMIR_SKIP_FIXES_GUARD=1` under `gh auth token` | push only under the **machine's own identity** named in the home; the wards are never overridden |
| `git add -A` + `git commit --no-verify` | no blanket add, no `--no-verify`, anywhere |
| delete the branch after merging | closes nothing, deletes nothing, drafts are left alone |
| process every PR silently | **five open at most** (a cap reported, never enforced by closing another hand's work); a stale PR is a **notice**, never a close |
| run under whoever is logged in | identify itself: the home names the identity and the vault key; with no machine credential in the home it makes the re-cut locally and records the push as **owed** |
| `--install-timer` enabled and started the clock | `--install-timer` **seats** the unit; only an explicit `--start` runs it |

The policy now comes from the operator's home, one file per machine (plan 290 §3):
`$YMIR_HOME/config/machines/<machine>/wardens.yaml` —
`max_open_prs`, `stale_hours`, `identity`, `token_ref`. A missing file is not a fault: the defaults
(5, 48 h, unnamed identity) stand, and `status` says which of the two answered.

Notices are append-only: `$STATE/queue-warden.notices.log` (one ISO-stamped line each) and
`$STATE/queue-warden.status` (the latest pass). The old door appended a blocking line to
`queue-warden.status` and nothing read it.

## The proof

`bin/gates/tests/test_queue_warden.sh` — 31 cases, all passing. It judges the **code with every comment
line stripped**, because prose saying "never merges" proves nothing: no `gh pr merge`, no `pr merge`, no
merge through the API, no `git merge`, no `git add -A`, no `--no-verify`, no `YMIR_SKIP_*`, no forced or
mirrored push, no `pr close`. Then it runs a dry run over the live open PRs and reads the pass line:

```
warden-pass[10]{host,read_as,credential,identity,cap,open,over_cap,stale,conflicting,merges}
  "heimdall","zerwiz","absent","unnamed","5","4","0","0","4","0"
```

`merges` is `0`. A real re-cut of PR #741 was run once to prove the road works: the branch rebased onto
`origin/main` locally, the scratch worktree was removed, the local branch was deleted afterwards, and
`git ls-remote --heads origin 'rehygiene/*'` returned nothing — nothing was pushed, nothing merged.

## What is owed, and by whom

- **The machine identity.** `gh` on this box is logged in as the operator, so the home names no
  credential for a warden yet (plan 290 P5). Until one is written, the warden **reads** through that
  login and says so on every pass (`read_as`), and **writes nothing**: no push, no comment, no close.
  A re-cut is made locally and the exact `git push` is recorded as owed.
- **The clock.** `queue-warden.timer` stays **stopped and disabled on heimdall** until the Allfather or
  the heart re-enables it (plan 290 P1). Watching it is not starting it: `systemctl --user is-enabled
  queue-warden.timer` reads `disabled`, `is-active` reads `inactive`.
- **Ownership per machine** (plan 290 P2/P3). `.agents/config/units.yaml` still registers the unit for
  `[heart, forge, dev]`; which machine owns it is the per-machine decision that phase writes.

## Limits

- The cap is **reported, not enforced**: a warden that may not close or merge cannot force a queue
  down, and the house's standing rule is that another hand's PR is that hand's to tend.
- A re-cut whose conflicts are in code is not attempted twice: it reports "two hands disagree in the
  same file" and stops. Only genuine rebases land on a `rehygiene/` branch.
- A bot's branch (`dependabot/*`, any `*[bot]` author) is never re-cut.

## Files

- `bin/forge/queue-warden.sh` — rewritten
- `bin/gates/tests/test_queue_warden.sh` — rewritten
- `.agents/config/units.yaml` — the timer's description
- `docs/features/queue-warden.md`, `docs/features/_catalogue/entries/02-107-queue-warden.md`
- `RULES/08-delivery-gate.md` — a dated correction appended (it named this door as a merger)

## CHANGE LOG

- 2026-11-14 — written with the change, at the heart's ruling (plan 290, P1).

## 2026-11-14 12:40Z — corrected: the road is CLOSED, not absent

The body above says *"no merge call exists in the file at all"*. **That is no longer true, and the
change was decided after it was written** — recorded here rather than edited away (`RULES/06`).

The Allfather, later the same day: *"zerwizserver (the heart) handles the merging of the PRs. So in the
operator's home: `config/machines/zerwizserver/wardens.yaml` is the only file that may say
`merge: on` … every other machine's says `merge: off`, and the template ships `merge: off`. Build to
that."* The heart's PR #747 puts the same rule in its own words: a merge is *"the one act it may not
take on trust"*.

So the warden now carries **one** merge, and it is the heart's, behind three keys and one gate:

| Condition | Where it is written | What happens if it fails |
|---|---|---|
| `merge: on` in **this machine's** wardens file | the operator's home | `closed: merge: off in this machine's wardens file` |
| this machine's role is `heart` | `bin/skuld/role.sh resolve`, read from the fleet registry in the home | `closed: merge: on, but this machine's role is <role> — only the heart may merge` |
| `bin/forge/merge-verdict.sh` is on the tree | the heart's PR #747 | `closed: the gate … is not on this tree` |
| the gate answers `0` for this PR | one sha, one verdict, main green, branch current, no unexplained bypass | `merge-refused: merge-verdict.sh said NO: …` |

No hostname is written in this file for that rule (`RULES/07`, `RULES/39`): the heart's name lives in
the home and `role.sh` prints it. On heimdall every one of the four fails at the first key, so the door
never reaches a merge call — and the test proves the shape rather than the intention: exactly **one**
`gh pr merge` in the whole file, inside `merge_one`, with the gate call in that same function, and
`merge_one` called only where the road answered open.

The old faults stay removed and the test still asserts their absence: no `--no-verify`, no
`git add -A`, no `YMIR_SKIP_*`, no forced or mirrored push, no `pr close` — on the heart's machine as
much as here.

### Also adopted the same day: the shared layout (`wardens-own-only`)

`enabled: on|off` is the per-machine opt-in, the block is **not** wrapped in a `wardens:` key, and the
policy is read through `bin/forge/warden-policy.py` — the shared reader that errand owns. That door is
not on the tree yet, so the warden keeps a six-line fallback reader and **says which answered**
(`reader: local|shared`), because a fallback that cannot be told from the library is a second parser
nobody knows about. When `warden-policy.py` lands, the fallback is deleted in one edit.

`enabled: off` also stops a **scheduled** pass (the door tells systemd from a hand by `INVOCATION_ID`)
and stops `--start` from starting a clock — a hand may still run a pass, which is how the queue gets
inspected.
