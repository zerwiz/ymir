# collab — Vingólf, the assembly hall

Who collaborates with the house, on which surface, at which rung — and the doors that carry it.

The thinking is plan 154 (`svartalfaheim/whynotproductions/projects/ymir/plans/`); the declared truth is
`$YMIR_HOME/hodd/data/collaboration.yaml`; the code is here.

## The six rungs

| Rung | The surface | What it promises |
|---|---|---|
| L0 | email, through the gate | a decision is recorded and everyone has the same copy |
| L1 | the shelf: `AGENTS.md`, `handoff/`, `tickets/`, PRs | a stranger continues where the last hand stopped |
| L2 | the board: Trello for a client, the Gimlé Board for the team | who owns what, legible to someone who does not read code |
| L3 | the suite: Gimlé — hall, Documents, Whiteboard, Files, Code | one login, company hardware, one membership boundary |
| L4 | the ear: Snotra | a meeting writes its own record, decisions and cards |
| L5 | the agent: the Gimlé MCP, then A2A with a grant | an agent reads the record before a human asks |

## The doors

```sh
bin/collab/collab.sh who                  # the roll: every declared person, every surface, measured
bin/collab/collab.sh who --strict         # exit 1 when a declared account is absent from its surface
bin/collab/collab.sh ladder               # the register: rungs, what each person owes, which projects carry the shelf
bin/collab/collab.sh init <repo>          # put the baton shelf into a repository (or --check the one it has)
bin/collab/collab.sh letter --to <addr> --person "<name>"   # render the letter as a DRAFT in the gate
bin/collab/collab.sh ship --repo P --branch B --message M --path X ...   # branch, commit named paths, merge, push
```

**`who`** reads the register, then measures `zerwizserver`: the gate (users, the authentication log, whether any
second factor is enrolled), the Board (accounts, last sign-in, workspace membership), Documents (accounts, when
created), the forge (accounts, last sign-in, public keys) and the shell. A surface it cannot read is `unread`,
never zero. A sign-in from loopback or from the house's own address is labelled `loopback`/`house` — a house test
is never mistaken for a counterpart using the system.

**`init`** installs five files into any repository — `handoff/README.md`, `TEMPLATE.md`, `CURRENT.md`, `log/`, and
`check.sh` (with `check.py` beside it) — and prints the line that wires the check into that project's gate. It
never overwrites: a repository that already has a baton is checked, not rewritten, and it prefers the project's
own checker (an Elixir `mix` task, a node script) over the shelf's.

**`letter`** renders a letter from `letters/collaboration-files.md` and leaves it as a **draft** in the mail gate.
It has no send path by construction; sending is the operator's word and goes through
`systems/snotra/services/letters/mail-send.sh send <draft-id>`.

**`ship`** is the house's git discipline as one door: it stages only the paths named (never `git add -A`), reports
what it leaves alone, commits, merges into the base branch and pushes.

## Where the state lives

- the register — `$YMIR_HOME/hodd/data/collaboration.yaml` (private; no name is hardcoded in the doors)
- rendered letters — `$YMIR_HOME/hodd/state/collab/letters/`
- the plan and the audit record — plan 154, and `products/gimle/internal/open-items.md`

## Laws it obeys

- **Declared truth beats measurement, and the door proves it.** A person is added to the register, never to code.
- **A door that cannot answer says `unread`**, never zero.
- **Nothing is sent, merged or pushed without an explicit word**, and a draft is not a send.
- **Gimlé mirrors the shelf; it does not replace it.** The repo is the only surface that is checked and versioned.
