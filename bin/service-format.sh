#!/usr/bin/env bash
# service-format.sh — the process a service runs is never bash.
#
# A systemd unit's ExecStart execs the REAL runtime (python3 · node · bun · a
# binary). A shell shim is allowed only as a THIN door (env + args, ending in
# `exec`), never as the service body: long-running shell has no structured error
# handling, no graceful shutdown, no backpressure, and cannot be tested alone —
# which is what `Restart=on-failure` papers over. Audited 2026-09-25: `nornir` is
# a `while :` loop under `Type=oneshot`; `mill-worker` is a `while true` under
# `Type=simple`; `mimir`/`bifrost` are 126/140-line shims that only `exec` python.
#
# Known debt is DECLARED in SERVICE-FORMAT.allow (`unit:rule  # reason`). A new
# finding is a failure, so the debt can be paid down but cannot grow.
#
# Usage:
#   bin/service-format.sh check          # the ward
#   bin/service-format.sh check --json   # the findings, machine-readable
#   bin/service-format.sh --version
# Exit: 0 clean (or only declared debt) · 1 a new finding · 2 usage.
set -u

VERSION="1.0.0"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ALLOW="$ROOT/SERVICE-FORMAT.allow"

for a in "$@"; do case "$a" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; esac; done
case "${1-}" in
  -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  check) ;;
  *) printf 'error: use check\nhelp: bin/service-format.sh check [--json]\n' >&2; exit 2 ;;
esac
JSON=0
[ "${2-}" = "--json" ] && JSON=1

allowed() {  # <unit> <rule> — declared debt
  [ -r "$ALLOW" ] || return 1
  awk -v u="$1" -v r="$2" '
    /^[[:space:]]*#/ { next }
    NF < 1 { next }
    { line=$0; sub(/[[:space:]]*#.*/,"",line); split(line,f,":"); if (f[1]==u && f[2]==r) found=1 }
    END { exit found ? 0 : 1 }' "$ALLOW"
}

findings=""
add() { findings="${findings}$1|$2|$3\n"; }

for unit in "$ROOT"/tools/*/systemd/*.service; do
  [ -f "$unit" ] || continue
  name="$(basename "$unit")"
  type="$(sed -nE 's/^Type=//p' "$unit" | head -1)"; type="${type:-simple}"
  exec_line="$(sed -nE 's/^ExecStart=//p' "$unit" | head -1)"
  [ -n "$exec_line" ] || continue
  # shellcheck disable=SC2086
  set -- $exec_line
  exe=""; arg1=""
  for tok in "$@"; do
    case "$tok" in *=*) continue ;; esac
    if [ -z "$exe" ]; then exe="$tok"; elif [ -z "$arg1" ]; then arg1="$tok"; fi
  done
  # When the process is an interpreter, the SCRIPT is the next token.
  base_script="$(basename -- "${arg1:-}")"
  script=""
  [ -n "$base_script" ] && [ -f "$ROOT/bin/$base_script" ] && script="$ROOT/bin/$base_script"

  # A shell that `exec`s a runtime is a thin DOOR (a handoff), not a service body.
  unit_handoff=0
  printf '%s' "$exec_line" | grep -qE '(^|[[:space:]])exec[[:space:]]' && unit_handoff=1
  script_handoff=0
  if [ -n "$script" ] && \
     grep -qE '^[[:space:]]*exec[[:space:]]' "$script" 2>/dev/null && \
     ! grep -qE '^[[:space:]]*exec[[:space:]]+(/bin/|/usr/bin/)?(bash|sh)([[:space:]]|$)' "$script" 2>/dev/null; then
    script_handoff=1
  fi

  # Rule A — a long-running service whose process STAYS a shell (no handoff).
  case "$exe" in
    */bash|*/sh|bash|sh)
      if [ "$type" != oneshot ] && [ "$unit_handoff" = 0 ] && [ "$script_handoff" = 0 ]; then
        add "$name" "daemon-in-bash" "ExecStart $exe with Type=$type — exec the real runtime, or declare it oneshot"
      fi ;;
  esac

  # Rule B — a oneshot whose body holds a foreground loop (a contradicting contract).
  if [ "$type" = oneshot ] && [ -n "$script" ] && \
     grep -qE '^[[:space:]]*while[[:space:]]+(:|\$\{?true\}?|true|1)([[:space:]]|;)' "$script" 2>/dev/null; then
    add "$name" "oneshot-loop" "$(basename -- "$script") holds a foreground loop under Type=oneshot"
  fi

  # Rule C — a long shell shim that only execs another runtime (a service hiding in a door).
  if [ -n "$script" ] && [ "$script_handoff" = 1 ]; then
    lines="$(wc -l <"$script" 2>/dev/null || printf 0)"
    if [ "${lines:-0}" -gt 40 ]; then
      add "$name" "service-in-shim" "$(basename -- "$script") is a ${lines}-line shell shim that only execs a runtime"
    fi
  fi

done

total=0; blocked=0; rows=""
while IFS='|' read -r u r d; do
  [ -n "$u" ] || continue
  total=$((total+1))
  if allowed "$u" "$r"; then st="declared"; else st="blocking"; blocked=$((blocked+1)); fi
  [ "$JSON" = 1 ] && printf '{"unit":"%s","rule":"%s","state":"%s","detail":"%s"}\n' "$u" "$r" "$st" "$d" \
    || rows="${rows}  \"$u\",\"$r\",\"$st\",\"$d\"\n"
done <<EOF
$(printf '%b' "$findings")
EOF

if [ "$JSON" != 1 ]; then
  printf 'service-format[1]{findings,blocking}:\n  %s,%s\n' "$total" "$blocked"
  printf 'units[%s]{unit,rule,state,detail}:\n' "$total"
  printf '%b' "$rows"
fi
[ "$blocked" = 0 ]
