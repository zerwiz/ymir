#!/usr/bin/env bash
# ymir-validate.sh — verify the installation actually works.
#
# The installer reports what it did; this proves it. Every check is an
# observation of the running system (a live port, a readable store, a running
# process), never a restatement of intent. A FAIL means the install is not
# usable; a WARN means a documented-optional part is off.
#
# Usage:
#   bin/ymir-validate.sh [--json] [--quiet]
#   bin/ymir-validate.sh --version
#
# Exit: 0 all required checks pass, 1 a required check failed, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
JSON=0; QUIET=0

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --quiet) QUIET=1; shift ;;
    *) printf 'error: unknown flag %s\nhelp: bin/ymir-validate.sh [--json|--quiet]\n' "$1" >&2; exit 2 ;;
  esac
done

declare -a IDS STATES DETAILS
add() { IDS+=("$1"); STATES+=("$2"); DETAILS+=("$3"); }
say() { [ "$QUIET" = 1 ] || printf '%s\n' "$1"; }

http_code() {  # <url> -> status code, or 000
  curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$1" 2>/dev/null || printf '000'
}
port_open() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

# ── 1. prerequisites present ────────────────────────────────────────────────
miss=""
for c in git python3 bun docker gh; do command -v "$c" >/dev/null 2>&1 || miss="$miss $c"; done
if [ -z "$miss" ]; then add prereqs PASS "git python3 bun docker gh present"
else add prereqs FAIL "missing:$miss"; fi

# ── 2. Utgard sandbox image ─────────────────────────────────────────────────
if ! command -v docker >/dev/null 2>&1; then
  add sandbox WARN "docker absent — sandbox unavailable"
elif docker image inspect utgard-runner:latest >/dev/null 2>&1; then
  add sandbox PASS "utgard-runner:latest present"
elif ! docker info >/dev/null 2>&1; then
  add sandbox WARN "docker not reachable (log out/in for the docker group)"
else
  add sandbox FAIL "utgard-runner:latest missing — run bin/utgard.sh build"
fi

# ── 3. the gate API (:3889) — the control plane's data face ─────────────────
code="$(http_code http://127.0.0.1:3889/api/health)"
case "$code" in
  200) add gate-api PASS "GET /api/health -> 200" ;;
  401) add gate-api PASS "GET /api/health -> 401 (up, auth enforced)" ;;
  000) add gate-api FAIL "no response on :3889 — run scripts/start.sh" ;;
  *)   add gate-api WARN "unexpected status $code on :3889" ;;
esac

# ── 4. the SPA (:3888) ──────────────────────────────────────────────────────
code="$(http_code http://127.0.0.1:3888/)"
if [ "$code" = 200 ]; then add spa PASS "GET / -> 200"
else add spa FAIL "no 200 on :3888 (got $code) — run scripts/start.sh"; fi

# ── 5. Bifrost model bridge (:4603) — provider-aware, keyless-capable ───────
if port_open 4603; then
  provider="$(curl -s --max-time 5 http://127.0.0.1:4603/v1/models 2>/dev/null | head -c 40)"
  if [ -n "$provider" ]; then add bifrost PASS "bridge up on :4603 (models served)"
  else add bifrost WARN "port 4603 open but /v1/models empty"; fi
else
  add bifrost FAIL "bridge down on :4603 — run bin/bifrost-bridge.sh --start"
fi

# ── 6. Nornir cron running ──────────────────────────────────────────────────
# The scheduler's cmdline is `bash -c <body>` and carries no "nornir" token, so
# ask nornir-cron-start.sh itself (it owns the identity check) instead of pgrep.
if [ -x "$ROOT/bin/nornir-cron-start.sh" ]; then
  cron_out="$("$ROOT/bin/nornir-cron-start.sh" 2>/dev/null || true)"
  if printf '%s' "$cron_out" | grep -q 'cron: running'; then
    add cron PASS "$(printf '%s' "$cron_out" | grep -m1 'cron: running')"
  else
    add cron FAIL "nornir cron not running — run bin/nornir-cron-start.sh"
  fi
else
  add cron SKIP "no nornir-cron-start.sh"
fi

# ── 7. smidja db (visualizer readiness) ─────────────────────────────────────
if [ -f "$ROOT/smidja/smidja_data/smidja.db" ]; then
  add smidja-db PASS "smidja.db present"
else
  add smidja-db FAIL "smidja.db missing — run bin/smidja-bootstrap.sh"
fi

# ── 8. desktop apps (both Electron windows) ─────────────────────────────────
if [ -x "$ROOT/scripts/electron.sh" ]; then
  st="$("$ROOT/scripts/electron.sh" status 2>/dev/null || true)"
  up_h=$(printf '%s' "$st" | grep -c '"hlidskjalf","up"' || true)
  up_s=$(printf '%s' "$st" | grep -c '"smidja","up"' || true)
  if [ "$up_h" = 1 ] && [ "$up_s" = 1 ]; then add desktop PASS "Hlidskjalf + Smíðja both up"
  elif [ "$up_h" = 1 ] || [ "$up_s" = 1 ]; then add desktop WARN "one desktop app up (h=$up_h s=$up_s) — run scripts/electron.sh start --both"
  else add desktop WARN "desktop apps not running — run scripts/electron.sh start --both"; fi
else
  add desktop SKIP "no scripts/electron.sh"
fi

# ── 9. the memory well (:4602) — documented optional ────────────────────────
if port_open 4602; then add memory PASS "Mimir bridge up on :4602"
else add memory WARN "well off (:4602) — needs the engram engine; platform runs without it"; fi

# ── 10. audit ledger intact ─────────────────────────────────────────────────
if [ -r "$ROOT/workspace/memory/runes_audit.md" ]; then
  add runes PASS "audit ledger readable ($(wc -l <"$ROOT/workspace/memory/runes_audit.md" | tr -d ' ') lines)"
else
  add runes FAIL "audit ledger unreadable"
fi

# ── output ──────────────────────────────────────────────────────────────────
fails=0; warns=0
for s in "${STATES[@]}"; do
  [ "$s" = FAIL ] && fails=$((fails + 1))
  [ "$s" = WARN ] && warns=$((warns + 1))
done

if [ "$JSON" = 1 ]; then
  printf '{\n  "checks": [\n'
  first=1
  for i in "${!IDS[@]}"; do
    [ $first = 0 ] && printf ',\n'
    first=0
    printf '    {"id":"%s","status":"%s","detail":"%s"}' "${IDS[$i]}" "${STATES[$i]}" "${DETAILS[$i]}"
  done
  printf '\n  ],\n  "fails": %d,\n  "warns": %d\n}\n' "$fails" "$warns"
else
  say "validate[${#IDS[@]}]{check,status,detail}:"
  for i in "${!IDS[@]}"; do
    say "  \"${IDS[$i]}\",\"${STATES[$i]}\",\"${DETAILS[$i]}\""
  done
fi

if [ "$fails" -gt 0 ]; then
  [ "$QUIET" = 1 ] || printf '\n%s required check(s) failed — the install is not fully usable\n' "$fails"
  printf 'help: %s required check(s) failed, %s warning(s)\n' "$fails" "$warns" >&2
  exit 1
fi
[ "$QUIET" = 1 ] || printf '\nall required checks pass (%s warning(s))\n' "$warns"
exit 0
