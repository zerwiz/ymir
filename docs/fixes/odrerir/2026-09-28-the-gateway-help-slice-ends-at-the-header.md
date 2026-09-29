# odrerir · 2026-09-28 — the gateway's help slice ends at the header

## Why

Forseti's review of PR #242 (`eindri/gateway-hardens-the-door`)
(`$YMIR_HOME/state/eindri-reports/gateway-hardens-the-door-review.md`) held the
seal on one regression the branch itself carved: `bin/mcp-gateway.sh` printed
`--help` with a hardcoded `sed -n '2,30p'`, and the six header lines the door-pin
change added pushed the usage block to lines 29–36. `--help` then printed only
`serve` and `start|stop`, dropping `status`, `resolve`, `rail`, `sync`, `catalog`
and `--version` — main printed all eight.

## What

- **`bin/mcp-gateway.sh`** — the help slice now ends at the header's own
  terminator, the house idiom `bin/fm-*.sh` already uses:

```
sed -n '2,/^set -u$/p' "$0" | sed '$d; s/^# \{0,1\}//'
```

  It cannot drift again as the header grows.

## Verified

- `bash bin/mcp-gateway.sh --help` → the title plus all eight usage rows
  (`grep -c 'mcp-gateway.sh'` = 9; main was 9, the broken branch was 3).
- `bash -n bin/mcp-gateway.sh` clean.
- `.agents/tests/mcp-gateway.test.sh` — ALL PASS (25/25).
- `bin/guards.sh` — runtime-guard PASS · defaults-guard PASS.

## Files

- `bin/mcp-gateway.sh`
