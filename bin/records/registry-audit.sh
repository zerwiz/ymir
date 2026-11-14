#!/usr/bin/env bash
# registry-audit.sh — is every running container named in the services registry, and is every named service alive?
#
# The rule (RULES/the-hosted-services-registry.md) says a service running but unnamed is a FAULT. This is the door that
# checks it, so the rule is not a hope.
#
#   registry-audit.sh            human report + exit 1 on any gap
#   registry-audit.sh --quiet    one line
set -uo pipefail
# The home is resolved, never assumed (RULES/07): the one resolver is bin/vault/hoard-lib.sh.
_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ROOT="$(cd "$_DIR" && while [ ! -d "$PWD/RULES" ] || [ ! -d "$PWD/bin" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOME:-}" ] && [ -r "$_ROOT/bin/vault/hoard-lib.sh" ]; then
  . "$_ROOT/bin/vault/hoard-lib.sh" >/dev/null 2>&1 || true
  if command -v ymir_home_root >/dev/null 2>&1; then _h=""; ymir_home_root _h; [ -n "$_h" ] && export YMIR_HOME="$_h"; fi
fi
[ -n "${YMIR_HOME:-}" ] || { printf '%s: the home could not be resolved (bin/vault/hoard-lib.sh, RULES/07)\n' "$(basename "$0")" >&2; exit 2; }
HOME_DIR="${YMIR_HOME}"
REG="$HOME_DIR/hodd/identity/services.yaml"
[ -f "$REG" ] || { printf 'registry-audit: no registry at %s\n' "$REG" >&2; exit 2; }

named="$(python3 - "$REG" <<'PY'
import sys,yaml
d=yaml.safe_load(open(sys.argv[1]))
for s in d.get('services',[]):
    for c in (s.get('containers') or []): print(str(c))
PY
)"
running="$(docker ps --format '{{.Names}}' 2>/dev/null | sort)"

unnamed="$(comm -23 <(printf '%s\n' "$running") <(printf '%s\n' "$named" | sort -u) | grep -v '^$' || true)"
missing="$(comm -13 <(printf '%s\n' "$running") <(printf '%s\n' "$named" | sort -u) | grep -v '^$' || true)"

quiet=0; [ "${1:-}" = "--quiet" ] && quiet=1
n_running=$(printf '%s\n' "$running" | grep -c . || true)
n_named=$(printf '%s\n' "$named" | sort -u | grep -c . || true)
n_unnamed=$(printf '%s\n' "$unnamed" | grep -c . || true)
n_missing=$(printf '%s\n' "$missing" | grep -c . || true)

if [ "$quiet" -eq 1 ]; then
  printf 'registry-audit: %s running · %s named · %s unnamed · %s named-but-not-running\n' "$n_running" "$n_named" "$n_unnamed" "$n_missing"
  [ "$n_unnamed" -eq 0 ] && exit 0 || exit 1
fi

printf 'REGISTRY AUDIT — %s\n\n' "$(date -u +%FT%TZ)"
printf 'running containers: %s   named entries in the registry: %s\n\n' "$n_running" "$n_named"

printf '== RUNNING BUT NOT NAMED (%s) — each is a fault: write its entry, or stop it\n' "$n_unnamed"
[ "$n_unnamed" -eq 0 ] && printf '   none — every running container is known\n' || printf '%s\n' "$unnamed" | sed 's/^/   /'

printf '\n== NAMED BUT NOT RUNNING (%s) — dormant, stopped, or a promise nobody kept\n' "$n_missing"
[ "$n_missing" -eq 0 ] && printf '   none\n' || printf '%s\n' "$missing" | sed 's/^/   /'

[ "$n_unnamed" -eq 0 ] && exit 0 || exit 1
