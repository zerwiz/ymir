#!/usr/bin/env bash
# workspace-provision.sh — carve one workspace for the operator. Single tenant:
# a workspace is a running scope (personal | work) over a set of knowledge
# domains. A work workspace attaches to its company's container.
#
# Usage:
#   bin/workspace-provision.sh <name> --kind work|personal [--domains a,b,c] [--company <slug>]
#   bin/workspace-provision.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE="$ROOT/workspace"
DEFAULT_WORK="company,marketing,development,life"
DEFAULT_PERSONAL="me,life,development"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

NAME="${1-}"; shift || true
[ -n "$NAME" ] || { printf 'error: workspace needs a name\nhelp: bin/workspace-provision.sh <name> --kind work|personal\n' >&2; exit 2; }
case "$NAME" in *[!a-z0-9-]*|'') printf 'error: name must be a lowercase slug [a-z0-9-]\n' >&2; exit 2 ;; esac

KIND=""; DOMAINS=""; COMPANY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --kind) KIND=${2-}; shift 2 ;;
    --domains) DOMAINS=${2-}; shift 2 ;;
    --company) COMPANY=${2-}; shift 2 ;;
    *) printf 'error: unknown flag %s\n' "$1" >&2; exit 2 ;;
  esac
done
case "$KIND" in work) COMPANY=${COMPANY:-wayof}; DOMAINS=${DOMAINS:-$DEFAULT_WORK} ;; personal) DOMAINS=${DOMAINS:-$DEFAULT_PERSONAL} ;; *) printf 'error: --kind must be work or personal\n' >&2; exit 2 ;; esac

mkdir -p "$WORKSPACE"
made=0
IFS=',' read -ra DOMARR <<<"$DOMAINS"
for d in "${DOMARR[@]}"; do
  d="$(printf '%s' "$d" | tr -d ' ')"
  [ -n "$d" ] || continue
  if [ ! -d "$WORKSPACE/$NAME/$d" ]; then mkdir -p "$WORKSPACE/$NAME/$d"; made=$((made+1)); fi
done
mkdir -p "$WORKSPACE/$NAME/memory/daily"

# Register (idempotent) in workspaces.yaml.
reg="$WORKSPACE/workspaces.yaml"
if [ ! -f "$reg" ]; then printf 'workspaces:\n' >"$reg"; fi
if grep -qE "^  - id: ${NAME}$" "$reg" 2>/dev/null; then
  registered="exists"
else
  {
    printf '  - id: %s\n' "$NAME"
    printf '    name: %s\n' "$(printf '%s' "$NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
    printf '    kind: %s\n' "$KIND"
    [ "$KIND" = work ] && printf '    company: %s\n' "$COMPANY"
    printf '    domains: [%s]\n' "$(printf '%s' "$DOMAINS" | sed 's/,/, /g')"
  } >>"$reg"
  registered="added"
fi

# A work workspace attaches to the company's container root.
container="—"
if [ "$KIND" = work ]; then
  container="svartalfaheim/$COMPANY"
  mkdir -p "$ROOT/$container/companies" "$ROOT/$container/workspace"
fi

printf 'workspace[1]{id,kind,company,domains,dirs,registry,container}:\n'
printf '  "%s","%s","%s","%s",%s,"%s","%s"\n' \
  "$NAME" "$KIND" "${COMPANY:-—}" "$DOMAINS" "$made" "$registered" "$container"
