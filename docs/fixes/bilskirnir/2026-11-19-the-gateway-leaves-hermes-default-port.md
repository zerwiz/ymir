## bilskirnir · 2026-11-19 — the hall's gateway leaves Hermes's default port

### What was wrong

With its Electron in place, the hall still would not raise. `start.sh` stopped at the first piece, exit 1:

```
Nanna's gateway :8642        STRANGER on the port: pid 2234598 (~/.hermes/hermes-agent), not this app's — refusing to keep or kill it
```

### The cause

The hall seats Nanna's Hermes gateway on `8642`, and `8642` is also Hermes's own default. The operator runs their own
Hermes on the same machine: the desktop app's gateway, `HERMES_HOME=~/.hermes`. Whichever one starts first holds the
port, and the hall cannot raise beside it. `start.sh` was right to refuse, because that gateway is not the hall's to
lower. The split did not cause this. The earlier split test met the same stranger and worked around it by giving the
test's agent `8742`.

### The fix (in `zerwiz/bilskirnir`, commit `3a87919`)

The hall's default gateway port is now `8649`. That is below the bots' engines (`8650` and up), and is never Hermes's
own default. The change covers `setup.sh`, `start.sh`, `server/src/env.ts`, `app.yaml` and `.env.example`.
`BILSKIRNIR_HERMES_PORT` still overrides it.

An existing data home keeps the port it was seated with, because `setup.sh` never rewrites an engine's `.env`. On this
machine the two lines were moved by hand. The data home is the operator's own local state, ignored by the home's git:

| File | Line |
|---|---|
| `$YMIR_HOME/bilskirnir/data/engines/nanna/.env` | `API_SERVER_PORT=8649` |
| `$YMIR_HOME/bilskirnir/.env` | `HERMES_URL=http://127.0.0.1:8649` |

`docs/features/bilskirnir.md` now says `8649` and tells how to move an existing home.

### Proof, on the dev machine

- `start.sh` printed `Nanna's gateway :8649  raised`, then the server, then `the window  open`. The operator's own
  Hermes kept `8642` with the same pid, and was never touched.
- The room was driven end to end through the real window over DevTools (`:9415`). A message to Nanna through the
  window's `/api/bots/<id>/messages` was answered: `REPLY after 15.1s seq 26: hall answers 74117`. A message typed into
  the window's own composer was answered on screen by the agent it had open: `hall answers 65575`, after 19.1 s.

### Owed

- Push `zerwiz/bilskirnir`. The commit is on the local branch `eindri/e2e-bilskirnir` in the apps home's clone.
- Every other seat with a data home seated on `8642` moves the same two lines, or sets `BILSKIRNIR_HERMES_PORT=8642`
  where no other Hermes runs.

## CHANGE LOG

- 2026-11-19 — written.
