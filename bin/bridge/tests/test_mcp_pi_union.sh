#!/usr/bin/env bash
# test_mcp_pi_union.sh — pi's ONE set is BOTH of its files, and a token travels nowhere.
#
# Why this test exists (measured 2026-11-20): `mcp({ server: "gimle" })` answered not found although
# `~/.pi/agent/mcp.json` named gimle — url and Authorization header and all. The seater took its set
# from `mcp-adapter.json` ALONE (the file the MCP gateway reads when the seat's builtin MCP is off),
# so a server the operator seated where pi's own documentation says to put it never reached the
# gateway, and every harness was seated from half a list. The set is now the union of the two files.
#
# Proved here, in a throwaway config dir (never this machine's):
#   1 · a server seated only in mcp.json reaches BOTH files, header intact
#   2 · a server seated only in mcp-adapter.json reaches BOTH files
#   3 · on a shared name the source's own spec wins
#   4 · a retired name found in either file is dropped
#   5 · `--check` reports the drift BEFORE anyone seats it
#   6 · a literal secret stays in pi's own files and is NEVER copied to another harness,
#       and never printed in the report
#
#   bash bin/bridge/tests/test_mcp_pi_union.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOOR="$ROOT/bin/bridge/mcp-config-seat.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ok=0; fail=0
good() { ok=$((ok+1)); printf 'ok   %s\n' "$*"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s\n     %s\n' "$1" "${2-}"; }

# The token is invented and must never be printed by the door; that is one of the cases.
TOKEN="TOK-$RANDOM-$RANDOM-secret-value"
PI="$T/pi"; mkdir -p "$PI"

[ -f "$DOOR" ] || { printf 'FAIL the seat door is missing: %s\n' "$DOOR"; exit 1; }

write_pi() {
  cat > "$PI/mcp-adapter.json" <<JSON
{"mcpServers": {"well": {"url": "http://127.0.0.1:1/mcp/well"}, "keepme": {"command": "adapter-only"},
                "shared": {"command": "from-adapter"}}}
JSON
  cat > "$PI/mcp.json" <<JSON
{"mcpServers": {"well": {"url": "http://127.0.0.1:2/mcp/well"},
                "gimle": {"url": "https://mcp.example.org/mcp", "headers": {"Authorization": "Bearer $TOKEN"}},
                "gmail": {"url": "https://retired.example.org/mcp"},
                "shared": {"command": "from-pi-json"}}}
JSON
}
seat() { env YMIR_RUNTIME_DIR="$T/no-pin" YMIR_MCP_RETIRED=gmail,drive,docs \
             python3 "$DOOR" 8399 "$PI/mcp-adapter.json" pi "$@" 2>&1; }
names() { python3 -c 'import json,sys;print(" ".join(sorted(json.load(open(sys.argv[1]))["mcpServers"])))' "$1"; }

write_pi
printf 'the drift is reported before anyone seats it\n'
out="$(seat --check)"
case "$out" in *gimle*) good '--check names gimle as missing from the adapter' ;;
  *) bad '--check names gimle as missing from the adapter' "$out" ;; esac

seat >/dev/null

printf 'a server seated in EITHER file reaches BOTH\n'
case " $(names "$PI/mcp-adapter.json") " in *" gimle "*) good 'gimle (only in mcp.json) reached mcp-adapter.json' ;;
  *) bad 'gimle (only in mcp.json) reached mcp-adapter.json' "$(names "$PI/mcp-adapter.json")" ;; esac
case " $(names "$PI/mcp.json") " in *" keepme "*) good 'keepme (only in the adapter) reached mcp.json' ;;
  *) bad 'keepme (only in the adapter) reached mcp.json' "$(names "$PI/mcp.json")" ;; esac
hdr="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]))["mcpServers"]["gimle"];print(d.get("headers",{}).get("Authorization",""))' "$PI/mcp-adapter.json")"
[ "$hdr" = "Bearer $TOKEN" ] && good 'its Authorization header came with it, intact' \
  || bad 'its Authorization header came with it, intact' "header=$([ -n "$hdr" ] && echo present || echo missing)"

printf 'on a shared name the SOURCE wins, and a record door is re-pointed\n'
cmd="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["mcpServers"]["shared"].get("command",""))' "$PI/mcp.json")"
[ "$cmd" = "from-adapter" ] && good "the source spec won for a shared name" \
  || bad "the source spec won for a shared name" "command=$cmd"
url="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["mcpServers"]["well"]["url"])' "$PI/mcp.json")"
case "$url" in *":8399/mcp/well") good 'the record doors are re-pointed at this gateway' ;;
  *) bad 'the record doors are re-pointed at this gateway' "url=$url" ;; esac

printf 'a retired name is dropped wherever it is found\n'
case " $(names "$PI/mcp.json") " in *" gmail "*) bad 'gmail (retired) is not seated' "$(names "$PI/mcp.json")" ;;
  *) good 'gmail (retired) is not seated' ;; esac
case " $(names "$PI/mcp-adapter.json") " in *" gmail "*) bad 'gmail (retired) is not in the adapter either' ;;
  *) good 'gmail (retired) is not in the adapter either' ;; esac

printf 'a literal secret never travels to another harness\n'
out="$(env YMIR_RUNTIME_DIR="$T/no-pin" python3 "$DOOR" 8399 "$PI/mcp-adapter.json" harness opencode 2>&1)"
case "$out" in *gimle*) bad 'opencode is not handed a server whose spec carries a literal secret' 'it was' ;;
  *) good 'opencode is not handed a server whose spec carries a literal secret' ;; esac
case "$out" in *"$TOKEN"*) bad 'the token is never printed in a harness config' 'the token appeared' ;;
  *) good 'the token is never printed in a harness config' ;; esac
out_seat="$(seat --check)"
case "$out_seat" in *"$TOKEN"*) bad 'the seat report never prints the token' 'the token appeared' ;;
  *) good 'the seat report never prints the token' ;; esac
case "$out_seat" in *gimle*) bad 'and it lands, so a second --check finds the set seated' "$out_seat" ;;
  *) good 'and the set is current after one seat' ;; esac

printf '\nmcp pi union: %s ok, %s failed\n' "$ok" "$fail"
[ "$fail" = 0 ]
