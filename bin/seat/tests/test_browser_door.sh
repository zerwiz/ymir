#!/usr/bin/env bash
# test_browser_door.sh — plan 373: the Playwright launcher, the seat writer, and Huginn's door (no docker, no network).
# Usage: test_browser_door.sh · Exit: 0 all pass · 1 a failure.
set -u
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ROOT="$(readlink -f "$HERE/../../..")"
pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
L="$ROOT/bin/seat/playwright-mcp-launch.sh"
printf 'test_browser_door\n'

# launcher: finds the newest revision, refuses when none
mkdir -p "$TMP/b/chromium_headless_shell-1248/x" "$TMP/b/chromium_headless_shell-1254/x"
for r in 1248 1254; do printf '#!/bin/sh\n' >"$TMP/b/chromium_headless_shell-$r/x/chrome-headless-shell"; chmod +x "$TMP/b/chromium_headless_shell-$r/x/chrome-headless-shell"; done
out=$(PLAYWRIGHT_BROWSERS_PATH="$TMP/b" bash "$L" --shell)
case "$out" in *1254*) ok "launcher resolves the newest headless-shell revision" ;; *) bad "newest revision" "$out" ;; esac
out=$(PLAYWRIGHT_BROWSERS_PATH="$TMP/none" bash "$L" --check); rc=$?
{ [ "$rc" = 1 ] && case "$out" in *missing*"npx playwright install chromium-headless-shell"*) true ;; *) false ;; esac; } \
  && ok "missing shell: --check is red and names the fetch command" || bad "missing shell check" "rc=$rc $out"
out=$(PLAYWRIGHT_BROWSERS_PATH="$TMP/none" bash "$L" 2>&1 </dev/null); rc=$?
{ [ "$rc" = 1 ] && case "$out" in *REFUSED*) true ;; *) false ;; esac; } && ok "missing shell: the door refuses to start" || bad "refusal" "rc=$rc $out"
out=$(YMIR_PLAYWRIGHT_SHELL="$TMP/b/chromium_headless_shell-1248/x/chrome-headless-shell" bash "$L" --shell)
case "$out" in *1248*) ok "YMIR_PLAYWRIGHT_SHELL overrides the search" ;; *) bad "override" "$out" ;; esac
grep -q 'playwright/mcp@\$VERSION' "$L" && ! grep -q '@latest' "$L" && ok "the server version is pinned, never latest" || bad "pin"

# seat writer: raw a2abridge becomes the session wrapper; the browser door is in the set
SRC="$TMP/adapter.json"
cat >"$SRC" <<J
{"mcpServers":{"a2abridge":{"command":"/x/.a2abridge/bin/a2abridge","args":["bridge","-bind","100.1.1.1:8391"],"env":{"A2A_DIRECTORY":"http://127.0.0.1:7777"}}}}
J
out=$(YMIR_MCP_ADAPTER="$SRC" YMIR_FIRECRAWL_URL=http://example-heart:3002 bash "$ROOT/bin/bridge/mcp-config.sh" harness claude)
echo "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)["mcpServers"]
assert d["a2abridge"]["command"].endswith("a2a-bridge-session.sh"), d["a2abridge"]
assert d["a2abridge"]["args"]==[] and d["a2abridge"]["env"]["A2A_DIRECTORY"], d["a2abridge"]
assert d["playwright"]["command"].endswith("playwright-mcp-launch.sh"), d["playwright"]
assert d["firecrawl"]["env"]["FIRECRAWL_API_URL"]=="http://example-heart:3002", d["firecrawl"]
' 2>"$TMP/err" && ok "seat set: session-wrapper a2abridge, playwright door, configured Firecrawl address" || bad "seat set" "$(cat "$TMP/err")"

# Huginn's door: down with road none; borrow reported as borrowed; refuses a worktree
H="$ROOT/bin/fleet/huginn-web.sh"
out=$(YMIR_HOME="$TMP/home" YMIR_FIRECRAWL_URL=http://127.0.0.1:9 YMIR_SEARXNG_URL=http://127.0.0.1:9 bash "$H" status)
case "$out" in *'"firecrawl","down","http://127.0.0.1:9","none"'*) ok "status: Firecrawl down, road none" ;; *) bad "down row" "$out" ;; esac
mkdir -p "$TMP/borrow"; ( cd "$TMP/borrow" && python3 -m http.server 18741 --bind 127.0.0.1 >/dev/null 2>&1 & echo $! >"$TMP/pid" ); sleep 1
out=$(YMIR_HOME="$TMP/home" YMIR_FIRECRAWL_URL=http://127.0.0.1:9 YMIR_FIRECRAWL_BORROW_URL=http://127.0.0.1:18741 bash "$H" status)
kill "$(cat "$TMP/pid")" 2>/dev/null
case "$out" in *'"firecrawl","up","http://127.0.0.1:18741","borrowed"'*) ok "status: a borrowed Firecrawl is named borrowed" ;; *) bad "borrowed row" "$out" ;; esac
mkdir -p "$TMP/wt/.yggdrasil/x"; : >"$TMP/wt/.yggdrasil/x/docker-compose.yaml"
out=$(YMIR_HOME="$TMP/home" YMIR_FIRECRAWL_URL=http://127.0.0.1:9 YMIR_FIRECRAWL_DIR="$TMP/wt/.yggdrasil/x" bash "$H" up 2>&1); rc=$?
{ [ "$rc" = 1 ] && case "$out" in *"main checkout"*|*"docker is not installed"*) true ;; *) false ;; esac; } && ok "up refuses a worktree checkout" || bad "worktree refusal" "rc=$rc $out"
printf 'test_browser_door: %s passed, %s failed\n' "$pass" "$fail"; [ "$fail" = 0 ]
