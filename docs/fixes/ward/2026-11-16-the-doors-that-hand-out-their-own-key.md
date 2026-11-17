# Three doors the ward could not see

**Date:** 2026-11-16 · **Component:** ward · **Door:** `bin/ward/security-audit.sh` · **Test:** `.agents/tests/ward.test.sh`

## What was wrong

The audit judged a wide bind by asking whether the operator had written down a reason for it. It never asked the
service itself. On the heart, that left three kinds of door unreported while the report looked complete:

- **An MCP that answers without a token.** `:8319` (skills) and `:8321` (snotra, the meeting record) both completed a
  full MCP handshake from any tailnet peer, with no credential, and `tools/list` answered too. The report said only
  "an unnamed wide bind — write down why it listens on every interface".
- **An SMB share open to guests.** Samba carried five CasaOS shares with `guest ok = Yes`, `read only = No` and
  `force user = root`. A guest could write into them as root. The report saw `0.0.0.0:445` and nothing else, because
  `testparm` was never read.
- **A tunnel that publishes an ssh door.** Three live tunnels dial `ssh://` — one to this host, two to other machines
  on the LAN. The tunnel parser only understood `http`, so those hosts lost their service line and were reported as
  "configured but not answering" — a MEDIUM about silence, when the truth was a HIGH about a shell.

One more fault fell out of the same measurement: the listener list was deduped by **column 5 of `ss`**, which is the
peer address. Every wide bind shares the same peer address, so two doors could collapse into one. A fixture with
`:8319` and `:8321` proved it — only one survived.

## What was forged

Four judgements, all inside the existing emissions, with every new source fixture-injectable:

| what | how it is judged | severity |
|---|---|---|
| an unauthenticated MCP | a two-second `initialize` to `http://127.0.0.1:<port>/mcp`; a reply carrying `serverInfo` is an open door, a reply carrying `error` is a gated one | HIGH |
| a guest-writable share | `testparm -s`: `guest ok = Yes` with `read only = No` | HIGH |
| a guest-readable share | the same parse, read-only | MEDIUM |
| a tunnel that dials ssh | any `service: ssh://…` in a cloudflared config | HIGH |

The listener dedupe now keys on the **port**, never on an `ss` column, so two services can no longer hide behind one
row.

The three new sources are fixtures when `--fixtures` is given (`mcp-<port>.out`, `smb.out`), so the judgements are
proved without knocking on a live door or reading this machine's samba.

## What was not done

- **No door was closed.** The audit measures and reports; closing samba, binding an MCP to loopback or removing a
  tunnel ingress is the operator's decision, and `bin/ward/harden.sh` still writes the mends out rather than doing
  them.
- **The MCP probe does not enumerate tools.** A handshake is enough to prove the door opens; listing the tools would
  mean exercising someone's record to prove a point already proved.
- **The tunnel parser still judges one hostname per config.** The first `hostname` pairs with the first `service`,
  which is right for every config on this machine and would need a rewrite to pair a many-hostname config correctly.

## Proof

`bash .agents/tests/ward.test.sh` — 24 checks, all pass, including the new negative controls: a gated MCP and a
keyed SMB share are **not** findings. Measured on the heart the same hour: 63 findings, 12 critical, 13 high, with
both MCPs and all five shares named.

## CHANGE LOG

- **2026-11-16** — written with the second heart audit, which found the three doors by hand before the ward could.
