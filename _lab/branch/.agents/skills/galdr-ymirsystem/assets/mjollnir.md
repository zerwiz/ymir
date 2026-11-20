# Mjollnir — the hammer, its eye, and the hall of verdicts

**What this asset owns:** the issue → pull-request pipeline in its four stops — the **registry** that
names a repo, **intake** (the read), the **audit** (the verdict), and the **run** (the hammer) — plus
Glitnir, the board where every result waits for the Allfather's hand. Load it before touching
`bin/forge/mjollnir.sh`, `bin/forge/intake.py`, `bin/forge/mjollnir-webhook.sh`,
`bin/agents/project-git.sh`, or the Reviews/Issues surface of Hlidskjalf.

## The one-line law

**A smith never ships and this door never merges.** The hammer prepares; a different hand reviews; the
Allfather merges on GitHub (plans 203 · 205 · 206 · `RULES/08`).

## The five doors

| door | what it answers | writes |
|---|---|---|
| `bin/agents/project-git.sh doctor [--probe] [--strict] [--json]` | which registry rows can name a remote, which have a clone, which are unreachable | nothing |
| `bin/forge/mjollnir.sh intake [--repo <id>]… [--ttl <s>] [--limit <n>] [--cache-only] [--json]` | what is open across every registered repo: issues, PRs, base health, alerts | a cache under `$YMIR_HOME/state/intake/` |
| `bin/forge/mjollnir.sh clone <id> [--dir <path>] [--from <url>]` | a far repo becomes a workable one, in the canonical hall | a tree |
| `bin/forge/mjollnir.sh run --project <id> --issue <n>` | one issue becomes one worktree, one branch, one PR | a worktree, a branch |
| `bin/forge/mjollnir.sh status` | what is prepared and not yet shipped | nothing |
| `bin/forge/mjollnir-webhook.sh` | a verified GitHub `issues/opened` becomes a run (needs a public endpoint) | like `run` |

## The registry is the floor (plan 210 P0)

`$YMIR_HOME/hodd/identity/projects.yaml` holds one row per project with a `git{}` block —
`host · owner · repo · remote · default_branch · auth`. `auth` is a **reference** to the vault, never a
value.

Measured on 2026-11-06 (the day P0 was written): **78 rows, 56 unable to name a remote, 11–14 with a
local clone**. Every door that claims "the user's repos" therefore starts from a registry that cannot
answer — so `doctor` exists to say so out loud, in one table, with a `findings[]` row per fault.

**Verdicts:** `ready` (names a remote and has a clone) · `far` (readable, not workable) · `no-git` (cannot
be read at all) · `unreachable`/`archived` (only with `--probe`). `--strict` exits 1 when any row is
`no-git` or `unreachable`, so it can be a gate once the remainder is healed.

Clone resolution order for a relative `repo:` — the code tree, `$HOME`, then `$YMIR_HOME`. Never guessed
beyond those three.

## Intake — the senses (plan 210 P1)

Five sources per repo, each failing alone:

| source | call | what it answers |
|---|---|---|
| `repo` | `gh api repos/{o}/{r}` | default branch, issues enabled, archived, private |
| `issues` | `gh issue list -R … --limit 100` | what is reported, its age, labels, comments |
| `prs` | `gh pr list -R … --limit 50` | what is in flight, review decision, mergeability, failing checks |
| `runs` | `gh run list -R … --branch <default> --limit 5` | is the base green before anyone branches from it |
| `alerts` | `gh api …/vulnerability-alerts`, `…/dependabot/alerts` | what is burning without an issue |

**The four laws of an honest read:**

1. **A source that did not answer is named with its reason.** `0` never means "I did not look".
2. **A count that is a cap is not a count** — `--limit 100` returning 100 prints `100+`.
3. **A credential gap is one fact, not N faults.** A missing `security_events` scope prints one short
   line per repo and one `needs[]` row with the fix (`gh auth refresh -h github.com -s security_events`).
4. **The cache is a cache.** `--ttl` (default 300 s) decides freshness, `--ttl 0` always re-reads,
   `--cache-only` never touches the network (not even `gh auth status` — the auth probe is lazy).

State is `read` · `partial` (something did not answer) · `unread` (the repo itself). GitHub stays the
authority; nothing here is a second copy of an issue body.

**Budget.** `--limit` (default 20) caps repos read per run; the rest are `deferred` and named. A run over
22 readable repos takes ~85 s cold and 0 calls warm.

## Reading a repo without a clone, and cloning it (P3)

`intake` needs no working tree — it reads through `gh`. **Fixing** does: `run --project <id>` refuses an
id with no clone and names the road.

`bin/forge/mjollnir.sh clone <id>` gives it hands. The destination is resolved by **one** resolver,
`project-git.sh paths`, which `doctor` also reads — so the diagnosis and the door can never disagree:

1. the registry row's own `repo:` path, under the code tree, `$HOME`, then `$YMIR_HOME`;
2. else the canonical hall `$YMIR_HOME/halls/<owner>/<repo>`.

Three refusals, each worse than no clone: cloning over an existing tree; a destination **inside the
public code tree** (Rule 04 — the tree ships, a workspace does not); and a row that cannot name a
remote (a guess is worse than a named fault). A failed clone removes what it created.

**The fault this door found:** `project-git.sh` read only the *inline* `git: {…}` shape, so every field
of every nested-block row returned `""` and four consumers carried on with nothing. It now reads both
shapes, and `--field path|clone` **refuses** rather than printing a blank line
(`docs/fixes/runtime/2026-11-06-the-registry-fields-read-both-shapes.md`).

## The webhook vs the clock

`mjollnir-webhook.sh` is HMAC-verified and correct, but it needs a public endpoint and a secret per repo.
For a **private** repo the default trigger is the clock: a Nornir row running `intake`, waking only on a
change. A webhook is an option where a public door already exists — never the assumption.

## Glitnir is a view, not a second reader

`apps/hlidskjalf/server/index.ts` `reviews()` is the only PR reader today, and it reads **one** repo
(`--repo` from this tree's origin, default `zerwiz/ymir`). Plan 210 P2 makes the board a **view over
intake**: cards gain `project` + `repo`, a filter and a group-by-project layout, and an **Issues** stage
beside Reviews. The tiles keep their rule: **only real PRs count** (number > 0), and a dead read is
shown, never swallowed.

## Failure shapes and what they mean

| message | meaning |
|---|---|
| `no usable git{} block` | the registry row is incomplete — `project-git.sh doctor` names it |
| `denied — the token has no scope for dependabot alerts` | credential, not repo: one `needs[]` row carries the fix |
| `HTTP 502 …graphql` | GitHub's own fault; the read of that source is retried on the next pass |
| `deferred — this run reads N` | budget honoured; raise `--limit` or wait for the next pass |
| `gh is not installed` / `gh auth status` failed | the door has no key; every repo reports it, none is guessed |

## Change log

- **2026-11-06** — carved with plan 210 P0/P1: `doctor` on the registry door, `intake` reading every
  registered repo, `run --project <id>`, and the honest-read laws above.
