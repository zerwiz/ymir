#!/usr/bin/env bash
# gather-notice.sh — when the LAST errand of a batch finishes, the helm is told to gather it.
#
# WHY (plan 293 part 4, 2026-11-14). A batch errand's brief promises the worker that it never pushes
# and never opens a PR: the helm merges the batch locally and ships it in ONE push and ONE PR
# (RULES/08, the batch road). The brief keeps its side — the branches are clean and pushed-free — but
# nothing ever told the helm the batch was ready. On 2026-11-14 twenty-two such branches were found
# sitting on origin, grown stale, four merged. A batch errand is not done when its worker finishes.
# It is done when the helm has gathered it.
#
# So: an errand reaching its terminal word asks this door whether it was the last of its batch, and if
# it was, the door puts ONE line in the durable wake queue naming the finished ids and the exact
# command that gathers them.
#
# MEMBERSHIP IS THE RECORD, NOT A SECOND REGISTRY. The dispatch already writes `mode=batch` and
# `wave=<wave>` into `state/<id>.meta`; the batch is that set — every errand whose meta says
# `mode=batch` and carries the same `wave`. Nothing new is written to remember a batch, and a batch of
# one is a batch of one (`bin/forge/gather.sh` refuses an empty gather, so nothing is prompted for).
#
# Usage: bin/forge/gather-notice.sh <errand-id>     # silent unless this finished the batch
#        bin/forge/gather-notice.sh --check <id>    # the same, and says what it saw either way
#
# Env (all optional):
#   GATHER_NOTICE_STATE    the state dir (default: the home's state, via bin/vault/hoard-lib.sh)
#   GATHER_NOTICE_REPO     the checkout whose branches are gathered (default: this tree's main checkout)
#   GATHER_NOTICE_REMOTE   the remote (default origin)
#   GATHER_NOTICE_BASE     the base branch (default main)
#   GATHER_NOTICE_DRY     1 = print the notice, queue nothing (tests)
#
# Exit: 0 whatever it found (a notice is not an error) · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERE="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"

case "${1-}" in
  -h|--help) sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
esac
CHECK=0
[ "${1-}" = "--check" ] && { CHECK=1; shift; }
ID="${1-}"
[ -n "$ID" ] || { printf 'usage: bin/forge/gather-notice.sh <errand-id>\n' >&2; exit 2; }

# ── the state, through the one resolver (Rule 04 · Rule 07) ──────────────────
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
STATE="${GATHER_NOTICE_STATE:-${BROKK_HELM_STATE:-${BROKK_STATE_OVERRIDE:-}}}"
if [ -z "$STATE" ] && command -v hoard_state_dir >/dev/null 2>&1; then hoard_state_dir STATE; fi
STATE="${STATE:-$HERE/state}"
[ -d "$STATE" ] || { [ "$CHECK" = 1 ] && printf 'gather-notice: no state dir at %s — nothing to read\n' "$STATE"; exit 0; }

# shellcheck source=bin/agents/eindri-wake-lib.sh
. "$SCRIPT_DIR/../agents/eindri-wake-lib.sh"
EINDRI_STATE="$STATE"

say() { [ "$CHECK" = 1 ] && printf 'gather-notice: %s\n' "$*"; return 0; }

meta_field() { # <id> <key>
  sed -n "s/^$2=//p" "$STATE/$1.meta" 2>/dev/null | tail -1
}
last_line() { # <id> — the last non-empty status line
  [ -r "$STATE/$1.status" ] || return 0
  grep -v '^[[:space:]]*$' "$STATE/$1.status" 2>/dev/null | tail -1
}
terminal() { # <status-line> — an errand that has spoken its last word
  case "$1" in done:*|failed:*|needs-decision:*) return 0 ;; esac
  return 1
}

MODE="$(meta_field "$ID" mode)"
WAVE="$(meta_field "$ID" wave)"
if [ "$MODE" != batch ]; then
  say "$ID is mode=${MODE:-unrecorded}, not one of a batch — no gather is owed"
  exit 0
fi

# ── the batch: the meta records that already say so ──────────────────────────
members=""
open_n=0
done_ids=""
while IFS= read -r meta; do
  [ -r "$meta" ] || continue
  m_id="$(basename "$meta" .meta)"
  [ "$(meta_field "$m_id" mode)" = batch ] || continue
  [ "$(meta_field "$m_id" wave)" = "$WAVE" ] || continue
  members="${members}${m_id}
"
  line="$(last_line "$m_id")"
  if terminal "$line"; then
    case "$line" in done:*) done_ids="${done_ids}${m_id}
" ;; esac
  else
    open_n=$((open_n + 1))
  fi
done <<EOF
$(ls -1 "$STATE"/*.meta 2>/dev/null)
EOF

n_members="$(printf '%s' "$members" | grep -c . || true)"
[ "$n_members" -gt 0 ] || n_members=1
say "$ID is batch wave=${WAVE:-none}: $n_members member(s), $open_n still open"

if [ "$open_n" -gt 0 ]; then
  [ "$CHECK" = 1 ] && printf 'gather-notice: %s of %s batch errand(s) still open — no prompt yet\n' "$open_n" "$n_members"
  exit 0
fi

# ── what is actually gatherable ──────────────────────────────────────────────
REMOTE="${GATHER_NOTICE_REMOTE:-origin}"
BASE="${GATHER_NOTICE_BASE:-main}"
COMMON="$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
REPO="${GATHER_NOTICE_REPO:-$( [ -n "$COMMON" ] && dirname "$COMMON" || printf '%s' "$HERE" )}"

gatherable=""     # ids whose eindri/<id> branch exists here and is not yet on the base
shipped=0
while IFS= read -r m_id; do
  [ -n "$m_id" ] || continue
  case "$(last_line "$m_id")" in
    done:*"shipped in PR"*) shipped=$((shipped + 1)); continue ;;
  esac
  if git -C "$REPO" show-ref --verify --quiet "refs/heads/eindri/$m_id" 2>/dev/null; then
    if git -C "$REPO" rev-parse --verify -q "refs/remotes/$REMOTE/$BASE" >/dev/null 2>&1 \
       && git -C "$REPO" merge-base --is-ancestor "eindri/$m_id" "refs/remotes/$REMOTE/$BASE" 2>/dev/null; then
      shipped=$((shipped + 1)); continue        # already in the base: it shipped another way
    fi
    gatherable="${gatherable}${m_id}
"
  fi
done <<EOF
$done_ids
EOF

n_gather="$(printf '%s' "$gatherable" | grep -c . || true)"
if [ "${n_gather:-0}" -eq 0 ]; then
  if [ "$CHECK" = 1 ]; then
    printf 'gather-notice: batch wave=%s is finished and nothing is left to gather (%s already shipped)\n' "${WAVE:-none}" "$shipped"
  fi
  exit 0
fi

# ── the notice: once per batch, and it names the command ─────────────────────
ids="$(printf '%s' "$gatherable" | tr '\n' ' ' | sed 's/ $//')"
# The PR signature is read from the home's own registry, never written here (Rule 04 · RULES/44).
HOUSE=""; FLEET=""
command -v ymir_home_root >/dev/null 2>&1 && { [ -n "${YMIR_HOME:-}" ] || ymir_home_root YMIR_HOME; }
if [ -n "${YMIR_HOME:-}" ] && [ -r "$YMIR_HOME/hodd/identity/seats.yaml" ] && command -v python3 >/dev/null 2>&1; then
  ident="$(SEATS="$YMIR_HOME/hodd/identity/seats.yaml" python3 - 2>/dev/null <<'PY'
import os
try:
    import yaml
    fleet = (yaml.safe_load(open(os.environ["SEATS"])) or {}).get("fleet") or {}
except Exception:
    fleet = {}
print("%s|%s" % (fleet.get("house") or "", fleet.get("name") or ""))
PY
)"
  IFS='|' read -r HOUSE FLEET <<<"$ident"
fi
case "${HOUSE:-unknown}" in ''|unknown) HOUSE="" ;; esac
case "${FLEET:-unknown}" in ''|unknown) FLEET="" ;; esac
signature=""
[ -n "$HOUSE" ] && [ -n "$FLEET" ] && signature=" --house $HOUSE --fleet $FLEET"

cmd="bin/forge/gather.sh $ids$signature"
notice="batch ${WAVE:-none} is finished — gather it: $cmd (errands: $(printf '%s' "$ids" | tr ' ' ','))"

marker="$STATE/.gather-notice-${WAVE:-none}"
if [ -r "$marker" ] && grep -qxF "$ids" "$marker" 2>/dev/null; then
  [ "$CHECK" = 1 ] && printf 'gather-notice: already prompted for batch %s (%s)\n' "${WAVE:-none}" "$ids"
  exit 0
fi

printf '%s\n' "$notice"
if [ "${GATHER_NOTICE_DRY:-0}" != 1 ]; then
  mkdir -p "$STATE" 2>/dev/null || true
  eindri_queue_wake "$notice"
  printf '%s\n' "$ids" >>"$marker" 2>/dev/null || true
fi
exit 0
