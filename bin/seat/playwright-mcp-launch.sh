#!/usr/bin/env bash
# playwright-mcp-launch.sh — the browser door: Microsoft's Playwright MCP server on Playwright's own
# chrome-headless-shell, for every harness (plan 373).
#
# What the door is: `@playwright/mcp` (open source, Microsoft) speaking MCP over stdio, so it has no
# listening port at all and cannot be reached from the network (RULES/24). The browser is the
# headless shell Playwright installs: no window, and the same engine a frame-by-frame filmer needs.
# The profile is in memory (`--isolated`): the operator's own browser, its logins and its tabs are
# never read or written.
#
# Nothing is hard-coded (RULES/07): the shell is found at run time.
#   YMIR_PLAYWRIGHT_SHELL         the chrome-headless-shell binary (default: found, newest revision)
#   PLAYWRIGHT_BROWSERS_PATH      where Playwright keeps browsers (default ~/.cache/ms-playwright)
#   YMIR_PLAYWRIGHT_MCP_VERSION   the exact server version (default below; never "latest")
#   YMIR_PLAYWRIGHT_VIEWPORT      e.g. 1280x800 (default 1280x800; the tool can resize)
#
# Usage:
#   playwright-mcp-launch.sh            exec the MCP server on stdio (what a harness calls)
#   playwright-mcp-launch.sh --check    one row: shell found or missing, version; exit 0 / 1
#   playwright-mcp-launch.sh --shell    print the resolved shell path (exit 1 if none)
set -u

VERSION="${YMIR_PLAYWRIGHT_MCP_VERSION:-0.0.86}"
BROWSERS="${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}"
VIEWPORT="${YMIR_PLAYWRIGHT_VIEWPORT:-1280x800}"
FETCH="npx playwright install chromium-headless-shell"

find_shell() {
  if [ -n "${YMIR_PLAYWRIGHT_SHELL:-}" ]; then
    [ -x "$YMIR_PLAYWRIGHT_SHELL" ] && printf '%s\n' "$YMIR_PLAYWRIGHT_SHELL"
    return
  fi
  # newest revision first: chromium_headless_shell-1254 beats -1248
  local d f
  for d in $(ls -d "$BROWSERS"/chromium_headless_shell-* 2>/dev/null | sort -t- -k2 -n -r); do
    f="$(find "$d" -maxdepth 2 -type f -name chrome-headless-shell -perm -u+x 2>/dev/null | head -1)"
    [ -n "$f" ] && { printf '%s\n' "$f"; return; }
  done
}

SHELL_BIN="$(find_shell)"

case "${1-}" in
  --shell) [ -n "$SHELL_BIN" ] && { printf '%s\n' "$SHELL_BIN"; exit 0; }; exit 1 ;;
  --check)
    if [ -n "$SHELL_BIN" ]; then
      printf 'playwright-door[1]{state,version,shell}:\n  "ready","%s","%s"\n' "$VERSION" "$SHELL_BIN"; exit 0
    fi
    printf 'playwright-door[1]{state,version,shell}:\n  "missing","%s","no chrome-headless-shell under %s — fetch it: %s"\n' "$VERSION" "$BROWSERS" "$FETCH"
    exit 1 ;;
  -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

if [ -z "$SHELL_BIN" ]; then
  printf '[playwright] REFUSED: no chrome-headless-shell under %s\n[playwright] fetch it with: %s\n' "$BROWSERS" "$FETCH" >&2
  exit 1
fi
command -v npx >/dev/null 2>&1 || { printf '[playwright] REFUSED: npx is not on PATH\n' >&2; exit 1; }

exec npx -y "@playwright/mcp@$VERSION" \
  --headless --isolated --browser chromium \
  --executable-path "$SHELL_BIN" \
  --viewport-size "$VIEWPORT"
