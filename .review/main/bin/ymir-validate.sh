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
# The cloth: colour and marks for the human reading this report; the TOON rows on
# stdout stay the data (bin/ymir-style.sh).
if [ -z "${YMIR_STYLE_LOADED:-}" ]; then
  . "$SCRIPT_DIR/ymir-style.sh"; YMIR_STYLE_LOADED=1
fi
style_init
# Where the smithy's parts live: apps/smidja-factory in a clone, or the
# @zerwiz/smidja-factory package in an npm install (bin/smidja-lib.sh).
if [ -z "${YMIR_SMIDJA_LIB_LOADED:-}" ]; then
  _ys="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_ys/smidja-lib.sh" "$(dirname "$_ys")/bin/smidja-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_SMIDJA_LIB_LOADED=1; break; }
  done
  unset _ys _yc
fi
smidja_visualizer_dir SMIDJA_VIZ
smidja_factory_dir SMIDJA_FACTORY

# shellcheck source=bin/ymir-platform.sh
. "$SCRIPT_DIR/ymir-platform.sh"
# Docker or rootless Podman (Fedora), whichever is present.
CONTAINER_ENGINE="$(ymir_container_engine_name 2>/dev/null || true)"
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
for c in git python3 bun gh; do command -v "$c" >/dev/null 2>&1 || miss="$miss $c"; done
[ -n "$CONTAINER_ENGINE" ] || miss="$miss docker/podman"
if [ -z "$miss" ]; then add prereqs PASS "git python3 bun $CONTAINER_ENGINE gh present"
else add prereqs FAIL "missing:$miss"; fi

# ── 2. Utgard sandbox image ─────────────────────────────────────────────────
if [ -z "$CONTAINER_ENGINE" ]; then
  add sandbox WARN "no container engine (docker/podman) — sandbox unavailable"
elif "$CONTAINER_ENGINE" image inspect utgard-runner:latest >/dev/null 2>&1; then
  add sandbox PASS "utgard-runner:latest present ($CONTAINER_ENGINE)"
elif ! "$CONTAINER_ENGINE" info >/dev/null 2>&1; then
  add sandbox WARN "$CONTAINER_ENGINE not reachable (rootless podman: check login session; docker: check group)"
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
# The same pair scripts/start.sh and bin/smidja-bootstrap.sh resolve: an existing
# $YMIR_HOME/smidja/smidja.db first, then an in-repo copy.
# The operator's home: env -> the recorded choice -> the ONE documented default
# (Rule 07; the default lives in bin/hoard-lib.sh, never in a script).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _ymir_yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _ymir_yc in "$_ymir_yr/hoard-lib.sh" "$(dirname "$_ymir_yr")/bin/hoard-lib.sh"; do
    [ -r "$_ymir_yc" ] && { . "$_ymir_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _ymir_yr _ymir_yc
fi
ymir_home_root YMIR_HOME
SMIDJA_DB_PATH="${SMIDJA_DB:-}"
if [ -z "$SMIDJA_DB_PATH" ]; then
  for c in "$YMIR_HOME/smidja/smidja.db" "$ROOT/apps/smidja/smidja_data/smidja.db"; do
    [ -f "$c" ] && { SMIDJA_DB_PATH="$c"; break; }
  done
  SMIDJA_DB_PATH="${SMIDJA_DB_PATH:-$YMIR_HOME/smidja/smidja.db}"
fi
if [ -f "$SMIDJA_DB_PATH" ]; then
  add smidja-db PASS "smidja.db present"
else
  add smidja-db FAIL "smidja.db missing — run bin/smidja-bootstrap.sh"
fi

# ── 7b. visualizer (built ./dist AND its API actually listening) ────────────
# A PASS must mean the thing is UP. Probe the port, not just the build: a
# built-but-dead visualizer (a bad CMD_DB, a crashed API) is a FAIL, not green.
VIZ="${SMIDJA_VIZ:-}"
VIZ_PORT="${SMIDJA_VIZ_API_PORT:-8437}"
if [ ! -d "$VIZ" ]; then
  add visualizer SKIP "no visualizer tree at $VIZ"
elif [ ! -d "$VIZ/dist" ]; then
  add visualizer FAIL "UI not built (./dist missing) — (cd $VIZ && bun run build)"
elif port_open "$VIZ_PORT"; then
  add visualizer PASS "UI built and served on :$VIZ_PORT"
else
  add visualizer FAIL "UI built but no API listening on :$VIZ_PORT — run scripts/start.sh"
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
RUNES_LEDGER=""
# The ledger follows the hoard (Rule 06): 0004-hoard-and-realms moved it under
# hodd/memory/. Try the hoard first, then the pre-move locations.
for c in "${YMIR_HOME:+${YMIR_HOARD:-$YMIR_HOME/hodd}/memory/runes_audit.md}" \
         "${YMIR_HOME:+$YMIR_HOME/memory/runes_audit.md}" \
         "$ROOT/workspace/memory/runes_audit.md"; do
  [ -n "$c" ] && [ -r "$c" ] && { RUNES_LEDGER="$c"; break; }
done
if [ -r "$RUNES_LEDGER" ]; then
  add runes PASS "audit ledger readable ($(wc -l <"$RUNES_LEDGER" | tr -d ' ') lines)"
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
  # The same rows, rendered for the eye, on stderr: a human reads marks and
  # colour, a pipeline reads the TOON above, and neither parses the other.
  if [ "$QUIET" != 1 ]; then
    printf '\n' >&2
    for i in "${!IDS[@]}"; do
      style_line "${STATES[$i]}" "${IDS[$i]}" "${DETAILS[$i]}"
    done
  fi
fi

if [ "$fails" -gt 0 ]; then
  [ "$QUIET" = 1 ] || {
    style_rule 52
    style_line FAIL "not usable" "$fails required check(s) failed, $warns warning(s)"
    style_hint "mend it: ymir eir   (diagnose every surface, then mend what is broken)"
  }
  printf 'help: %s required check(s) failed, %s warning(s)\n' "$fails" "$warns" >&2
  exit 1
fi
[ "$QUIET" = 1 ] || {
  style_rule 52
  style_line OK "stands" "every required check passes ($warns warning(s))"
}
exit 0
