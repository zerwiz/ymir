# Queue warden

Keeps the pull-request queue **tidy** — and never merges anything.

It reports the five-at-most rule, flags a PR that has gone stale, and re-cuts a branch that
conflicts onto `main` under a new name. Every one of those is a notice or a new branch. **It never
merges, never force-pushes, never closes another hand's work, and never writes to GitHub as a
person's login.** Merging is the Allfather's, executed by the heart's hand (plan 290).

## What it does on a pass

| Act | What happens |
|---|---|
| **The cap** | Counts the open PRs. Above five, it names the oldest ones that put the queue over. It reports them; it never closes one. |
| **A stale PR** | A PR older than the stale limit (48 hours by default) gets a notice. A notice is never a close. |
| **A conflicting PR** | Re-cuts the branch: rebases it onto `origin/main` in a scratch worktree and lands the result on a **new** branch, `rehygiene/<pr>-<branch>-onto-main-<date>`. The PR's own branch is read and never written, so nothing is force-pushed. |
| **A draft, a bot's branch, or a protected branch** | Left alone, with the reason written down. |
| **A merge** | There is no such act. The door contains no merge call at all, and a test asserts that absence. |

## Commands

```sh
bin/forge/queue-warden.sh run                 # one pass over the open PRs
bin/forge/queue-warden.sh run --dry-run       # say what it would do; writes nothing
bin/forge/queue-warden.sh run --pr 741        # one PR
bin/forge/queue-warden.sh run --cap 3 --stale-hours 24 --no-recut
bin/forge/queue-warden.sh status              # the policy it resolved, and the clock's state
```

## The clock

```sh
bin/forge/queue-warden.sh --install-timer     # seat the unit — it does NOT start it
bin/forge/queue-warden.sh --install-timer --start   # seat it and start it
bin/forge/queue-warden.sh --timer-status
bin/forge/queue-warden.sh --uninstall-timer
```

Seating is not starting. A warden's clock is a decision for **one named machine** (plan 290 rule 1),
so the unit is written and left stopped unless you pass `--start`. On heimdall the clock is
**disabled** until the Allfather or the heart re-enables it.

## The policy: your home, one file per machine

```yaml
# $YMIR_HOME/config/machines/<machine>/wardens.yaml
queue-warden:
  max_open_prs: 5
  stale_hours: 48
  identity: <the machine's own name>     # never a person's login
  token_ref: <VAULT_KEY>                 # the vault key holding that identity's token
```

A missing file is not a fault: the defaults above stand, and `status` says `defaults` rather than
pretending it read a policy.

**The identity is the only thing that lets it write.** With no machine identity in the home, the
warden reads the open PRs through whatever `gh` login the box has — and says which one on every pass
(`read_as`) — but it **writes nothing**: no push, no comment, no close. A re-cut is made locally and
the exact `git push` line is recorded as owed.

## What it writes down

- `$STATE/queue-warden.notices.log` — append-only, one ISO-stamped line per notice.
- `$STATE/queue-warden.status` — the latest pass, rewritten each run.

## Limits

- The cap is **reported, not enforced**. A door that may not merge or close cannot shorten a queue;
  another hand's PR is that hand's to tend.
- A re-cut that conflicts in real code is not attempted twice: it reports "two hands disagree in the
  same file" and leaves the branch as it was.
- It reads the PRs of the repository the checkout points at. Another repository is another seat's work.

## If it does not work

- **`no GitHub door on this machine`** — `gh auth status` failed. The warden refuses rather than
  reporting an empty queue.
- **`push owed`** — that is the identity rule, not a fault: write `identity` and `token_ref` into the
  home's wardens file and the same re-cut will ship itself.
- **`home/state unresolved`** — the hoard is not where the machine expects it; nothing is acted on.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its
  earlier history is its git log; entries are appended below, never rewritten.
- **2026-11-14** — hygiene only, at the heart's ruling (plan 290, P1). It no longer merges, force-pushes,
  commits with `--no-verify`, or acts under a person's login; the cap, the stale notice and the re-cut
  are what remain. See `docs/fixes/forge/2026-11-14-the-warden-stopped-merging.md`.
