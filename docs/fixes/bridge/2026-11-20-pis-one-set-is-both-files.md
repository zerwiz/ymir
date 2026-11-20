# bridge · unversioned · 2026-11-20 — pi's one set is both of its files

`mcp({ server: "gimle" })` answered **not found** while `~/.pi/agent/mcp.json` plainly named it — url,
`Authorization` header and all. The server was seated; the seater could not see it.

## Why

pi and Ymir read **two** files, and they are one set:

| file | who reads it |
|---|---|
| `~/.pi/agent/mcp.json` | pi 1.3+'s builtin MCP, and the `pi-mcp-adapter` extension when the builtin is on |
| `~/.pi/agent/mcp-adapter.json` | the MCP gateway and Ymir's own tools — the file this seat's session actually loads |

`bin/bridge/mcp-config-seat.py` built its set from **one** of them — the adapter — and wrote the
result to both. A server the operator added where pi's own documentation says to put it (`mcp.json`)
never reached the adapter, so the gateway in this session did not know Gimlé, and every other
harness (opencode, claude, cursor, codex, hermes) was seated from the same half-list.

## What changed

`canonical()` now takes the **union** of the two files: the source keeps its own spec on a shared
name, the sibling fills in everything else. Every harness — and both pi files — is seated from that
union, so a server seated in either place is reachable everywhere and no seat carries half a list.

Nothing else about the writer moved:

- a **retired** name (`gmail`, `drive`, `docs`) is still dropped wherever it is found;
- the record doors (`well`, `bolthorn`, `skuld`) are still re-pointed at this body's gateway;
- a spec carrying a **literal secret is still never copied to another harness** — it is named as
  held, so the operator can move the value to a reference (`"Authorization": "Bearer ${GIMLE_MCP_TOKEN}"`,
  which pi interpolates at load). The token itself is never printed by any face of this door, and a
  case below asserts that.

## Proof

```text
$ bash bin/bridge/tests/test_mcp_pi_union.sh
the drift is reported before anyone seats it
ok   --check names gimle as missing from the adapter
a server seated in EITHER file reaches BOTH
ok   gimle (only in mcp.json) reached mcp-adapter.json
ok   keepme (only in the adapter) reached mcp.json
ok   its Authorization header came with it, intact
on a shared name the SOURCE wins, and a record door is re-pointed
ok   the source spec won for a shared name
ok   the record doors are re-pointed at this gateway
a retired name is dropped wherever it is found
ok   gmail (retired) is not seated
ok   gmail (retired) is not in the adapter either
a literal secret never travels to another harness
ok   opencode is not handed a server whose spec carries a literal secret
ok   the token is never printed in a harness config
ok   the seat report never prints the token
ok   and the set is current after one seat

mcp pi union: 12 ok, 0 failed
```

The fixture is a throwaway config dir with an invented token; this machine's files are not touched.

## What this seat still needs (a home action, not a code one)

The **writer** is mended; this machine's `mcp-adapter.json` still lacks `gimle` until a seat runs.
That is one command, and it is also what install and Eir's `fix` run:

```text
bin/bridge/mcp-config.sh seat        # from the pin, not from this worktree
```

Then `mcp({server: "gimle"})` answers on this seat, and the other harnesses receive the same set —
minus gimle, until its token is a reference rather than a literal in `mcp.json`, which is the
operator's call, not a script's.

## Files

- `bin/bridge/mcp-config-seat.py` — `pi_pair()`, and `canonical()` reads the union of both files
- `bin/bridge/tests/test_mcp_pi_union.sh` — every case above, by command

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #842
