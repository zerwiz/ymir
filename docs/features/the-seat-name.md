# The seat's name

Every machine can have its own primary agent name. The name is not inherited from
`AGENTS.md`; it is recorded once and read at start.

## Use it

```sh
bin/agents/seat-identity.sh --list                 # every seat and its primary
bin/agents/seat-identity.sh heimdall               # this seat's name
bin/agents/seat-identity.sh set omarchy sindri     # rename (seals it)
bin/agents/seat-identity.sh --ensure               # at install: use or ask for a name
bin/agents/seat-identity.sh --check heimdall       # fails when the seat drifted
bin/agents/seat-identity.sh --render heimdall      # identity + shared contract
```

The record is `hodd/identity/seats.yaml`; the human map is `hodd/identity/seats.md`.
A host with no entry **fails loudly** rather than inheriting another seat's name.

## Limits

- `set` edits the roster, not a running session; re-render and restart to take effect.
- Names are proposals until the Allfather seals them (`status: sealed`).
- The role file is `.agents/agents/<name>.md`; a name with no role file renders a
  warning, not a broken seat.
