## gate · unversioned · 2026-11-16 — the door that required a check that was not there

### Files
- `bin/gates/require-check.sh` — reads the whole protection before writing any of it, adds a check
  without dropping one, and never flips "require branches to be up to date" unless asked
- `bin/gates/tests/test_require_check_keeps_the_checks.sh` — the regression test
- `bin/gates/checks.d/0496-the-door-keeps-the-checks.sh` — the gate that runs it

### Why

the reviewer's first find on 12 November was *"Main has no branch protection"*, with the ask *"one required
review, no direct pushes, admins included"*. That ask is the operator's hand on GitHub — plan 279 §3
says an agent does not change GitHub settings — but the house's own door for the half an agent *may*
touch was wrong in a way that would have made the setting worse.

`bin/gates/require-check.sh` defaulted `CHECK="gates"` and, on `--apply`, PATCHed
`required_status_checks` with `contexts[]=<that one name>`. Measured on 2026-11-16 against
`zerwiz/ymir`:

- the required context is **`whole-tree`**, and the workflow says why in a comment above the job:
  *"THE REQUIRED CHECK. This job name is the contract with branch protection: rename it and the
  protection points at a check that no longer exists, which GitHub reads as satisfied."*
- there is **no `gates` job** in `.github/workflows/ymir-gates.yml`.

So the door, run with its own defaults, would have replaced the only check guarding `main` with a
name GitHub has never seen — trading a working gate for a green tick that means nothing. And because
`strict` was not read, either, a write could re-arm "require branches to be up to date", which was
turned **off on purpose on 2026-11-15** (plan 295 §S2): with it on, every merge moves `main` under
every other pull request and the queue drains one PR per CI run. That starvation is why the setting
is what it is.

### Fix

The door now reads one protection document, reports all of it, and writes with a union:

| Field | Before | Now |
|---|---|---|
| the check it names | `gates` (no such job) | `whole-tree`, overridable by `YMIR_GATES_CHECK` |
| what it writes | `contexts[]=<that one>` | the existing contexts **plus** the named one |
| `strict` (up-to-date) | not read, not preserved | preserved exactly; `--strict on\|off` to change it, and any change is announced |
| reviews / admins / rulesets | invisible | reported: count of required reviews, whether admins are enforced, and every active ruleset by name |
| protection off or unreadable | "would run PATCH" | exit 1, and it names whose hand sets it |

`bin/gates/checks.d/0495…` keeps the companion rule for the container; this note's gate is
`0496`, and it holds the three claims that would have caught the defect: the default name is the
workflow's job, a write keeps every existing context, and a plain `--apply` does not touch
up-to-date.

### Verified

- `bash bin/gates/tests/test_require_check_keeps_the_checks.sh` — 12 ok / 0 fail (a fake `gh` on
  `PATH` answers the reads and records every write, so the door is judged on its own behaviour).
- `bash bin/gates/require-check.sh` against the live repository prints, in full:
  `"now_required","whole-tree"` · `"up_to_date_required","false"` · `"required_reviews","0"` ·
  `"admins_enforced","false"` · `"ruleset","main keeps its history · active"` ·
  `"result","whole-tree is required — a PR cannot merge while it is red"`.
- `bash -n bin/gates/require-check.sh` passes.

### What this note does not claim

The door cannot add the two settings the reviewer asked for that are missing — a required review and admins
included — because they are the operator's decision on GitHub, and the trade-offs (his PRs wait for
the reviewer, the reviewer's for him; the documents road of RULES/08 closes or gains a bypass list) are his to
accept. This change only makes the door honest about what is there, and incapable of taking a check
away by accident.

### CHANGE LOG

- **2026-11-16** — note written with the fix; the reviewer's item 1 of the 12 November review.
