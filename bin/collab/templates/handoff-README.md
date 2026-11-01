# handoff — the baton

One hand stops; another continues. Without a written baton the second one re-derives the state of this
repository from the code and the tickets, and the first one's reasoning is lost — which is the expensive
part, because the reasoning is what the plans carry and the code does not.

**Two files and a shelf:**

```
handoff/
├── CURRENT.md      the live baton — always the last five minutes of the previous hand
├── TEMPLATE.md     the shape every baton must have
├── log/            one file per handoff, dated — append-only, never rewritten
└── check.py        the check (handoff/check.sh runs it)
```

`CURRENT.md` is the only living document in the repository: it is rewritten at every handoff, because a
baton that accumulates is not a baton. Everything it says is also written once into `log/`, which is
append-only — a correction is a new baton that cites the old one.

## The law

| Rule | Why |
|---|---|
| write a baton before you stop | a session that ends without one leaves the next hand to archaeology |
| write it for a stranger | someone who has read the repository's contract and nothing else must be able to continue |
| say where the work is, not what it was like | branch, commit, PR number, deployment, and the command that proves each |
| name what is blocked, and on whom | a blocker nobody wrote down becomes two people waiting |
| check it, do not trust it | a stale baton must fail a gate instead of quietly lying |

**When to write one:** ending a session · handing to a sub-agent · going blocked · handing between
machines · before a merge is sealed. **Not** after every commit — a baton is for a hand, not a habit.

## Use it

```sh
handoff/check.sh --new --from <your-name>     # writes handoff/log/<date>-<from>.md and refreshes CURRENT.md
handoff/check.sh --check                      # complete, dated, fresh, and its paths exist
handoff/check.sh --check --max-age-days 30    # a longer leash for a long quiet stretch
```

The check fails on: a missing baton · a missing section · no date, an unparseable date, or an age over
the limit (default 14 days) · no branch or deployment line · a backticked path under a known shelf that
does not exist · an empty `log/`.

**Wire it into the gate.** The check is worth nothing if nobody runs it:

- Elixir: add `handoff/check.sh` to the `precommit` alias in `mix.exs`.
- Node: add `"handoff": "handoff/check.sh --check"` to `package.json` scripts, and call it from CI.
- Anything else: add `handoff/check.sh --check` to the CI job that must pass before a merge.
