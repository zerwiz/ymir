# Queue warden

Keeps the pull-request queue **tidy** — and never merges anything.

It reports the five-at-most rule, flags a PR that has gone stale, and re-cuts a branch that
conflicts onto `main` under a new name. Every one of those is a notice or a new branch. **It never
force-pushes, never closes another hand's work, and never writes to GitHub as a person's login.**

**It merges in exactly one place: the heart's machine, behind a gate.** Everywhere else the road is
closed and the door says why. That is the Allfather's word of 2026-11-14: *"the heart handles the
merging of the PRs … every other machine's says `merge: off`."* The heart is whichever machine
`bin/skuld/role.sh` names heart; no page here spells a machine's name.

## What it does on a pass

| Act | What happens |
|---|---|
| **The cap** | Counts the open PRs. Above five, it names the oldest ones that put the queue over. It reports them; it never closes one. |
| **A stale PR** | A PR older than the stale limit (48 hours by default) gets a notice. A notice is never a close. |
| **A conflicting PR** | Re-cuts the branch: rebases it onto `origin/main` in a scratch worktree and lands the result on a **new** branch, `rehygiene/<pr>-<branch>-onto-main-<date>`. The PR's own branch is read and never written, so nothing is force-pushed. |
| **A draft, a bot's branch, or a protected branch** | Left alone, with the reason written down. |
| **A merge** | Closed on every machine but the heart's, and on the heart's it answers to `bin/forge/merge-verdict.sh` first: one sha, one verdict, main green, branch current, no unexplained bypass. A `NO`, or an "I cannot tell", is a NO. |

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
so the unit is written and left stopped unless you pass `--start`. A machine whose wardens file
carries `enabled: off` does not carry a clock at all until the Allfather or the heart re-enables it.

## The policy: your home, one file per machine

```yaml
# $YMIR_HOME/config/machines/<machine>/wardens.yaml
queue-warden:
  enabled: on|off          # the per-machine opt-in: off = no clock, and a scheduled pass refuses
  max_open_prs: 5
  stale_hours: 48
  identity: <the machine's own name>     # never a person's login
  token_ref: <VAULT_KEY>                 # the vault key holding that identity's token
  merge: on|off            # only the heart's file says on
```

The block sits at the top level — there is no `wardens:` wrapper — and the shared reader
`bin/forge/warden-policy.py` is asked first; while that door is not on a tree the warden reads the
file itself and says so (`reader: local|shared`).

A missing file is not a fault: the defaults above stand, and `status` says `defaults` rather than
pretending it read a policy.

**The identity is the only thing that lets it write.** With no machine identity in the home, the
warden reads the open PRs through whatever `gh` login the box has — and says which one on every pass
(`read_as`) — but it **writes nothing**: no push, no comment, no close. A re-cut is made locally and
the exact `git push` line is recorded as owed.

## When it may merge

Three keys and a gate, in this order. On any machine but the heart's the first one stops it.

| Condition | Where it is decided |
|---|---|
| `merge: on` in this machine's own wardens file | the operator's home |
| this machine's role is `heart` | `bin/skuld/role.sh resolve`, from the fleet registry in the home |
| `bin/forge/merge-verdict.sh` exists on the tree | the heart's own work (PR #747) |
| the gate answers `0` for this PR | one sha, one verdict, main green, branch current |

`status` prints the answer in words, for example
`closed: merge: off in this machine's wardens file`.

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
- **`this machine has not opted in`** — `enabled` is off in the home's wardens file, so a scheduled
  pass refuses. Run it by hand, or set `enabled: on` if the machine should carry a clock.
- **`closed: merge: on, but this machine's role is <role>`** — the file asks for a merge this machine
  is not the heart for. It refuses rather than trusting the file.
- **`home/state unresolved`** — the hoard is not where the machine expects it; nothing is acted on.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its
  earlier history is its git log; entries are appended below, never rewritten.
- **2026-11-14** — hygiene only, at the heart's ruling (plan 290, P1). It no longer force-pushes,
  commits with `--no-verify`, or acts under a person's login; the cap, the stale notice and the re-cut
  are what remain. The one merge left is the heart's, behind `merge: on`, the machine's role, and
  `bin/forge/merge-verdict.sh`. The policy also adopted the shared layout (`enabled`, no wrapper,
  `bin/forge/warden-policy.py`). See `docs/fixes/forge/2026-11-14-the-warden-stopped-merging.md`.
