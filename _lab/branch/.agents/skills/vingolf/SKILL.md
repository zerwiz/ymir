---
name: vingolf
description: Who collaborates with the house and on which surface — the roll of invited people measured against the gate, Board, Documents, forge and shell, the six rungs of collaboration, the baton shelf installed into any repository, the collaboration letter as a draft, and the branch-commit-merge-push ship door. Use when asked who is using Gimlé or has access, whether a partner signed in, to add the handoff files to a project, to ask a counterpart whether every repo may carry them, or to ship named paths to main.
---

# Vingólf — the assembly hall

The house's collaboration system: one roll of who is inside, one ladder of how deep, one shelf of files that
travels into every repository, one letter, and one ship door.

Doors: `bin/collab/collab.sh` (`who` · `ladder` · `init` · `letter` · `ship`). Book: `bin/collab/README.md`.
Declared truth: `$YMIR_HOME/hodd/data/collaboration.yaml`. The thinking: plan 154.

## The one rule that matters

**A person is added to the register, never to code**, and **every claim about access is measured**: a sign-in in
the gate's own log, a `last_login` in the Board's database, an account row in Documents, a key count on the forge.
A surface that cannot be read is `unread`, never zero — and a sign-in from loopback or the house's own address is
a house test, not a counterpart using the system.

## Read before acting

```
assets[3]{file,load_when}
  "bin/collab/README.md","the rungs, the doors, and where the state lives"
  "$YMIR_HOME/hodd/data/collaboration.yaml","who is declared, on which surface, and what they owe"
  "products/gimle/internal/open-items.md","the audit record of the suite — who is in, who is not"
```

## The traps already paid for

1. **The Gimlé MCP is live and its public door is dead.** `127.0.0.1:8489` answers; `mcp.gimle.zerwiz.org` answers
   000. Do not tell anyone the MCP is reachable until the hostname does.
2. **AFFiNE's GraphQL cannot create a document.** There is no `createDoc`/`updateDoc` — only publishing, roles and
   comments. Storing a baton in Documents is an import or a sync client, not an API call.
3. **Plane writes through the database skip its own log.** `gimle-board.sh create` is a dry run unless `--yes`;
   the clean path is an API token, which is still owed.
4. **`who` must read the login rows before querying per-user**, or sqlite's cursor reuse silently returns one row.
