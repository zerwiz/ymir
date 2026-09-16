#!/usr/bin/env bash
# mimir-ingest.sh — ingest the repo's data material into the well (Mimirsbrunn).
#
# Mímir drinks from the operator's business material — the hoard's
# `docs/business/` (moved there from `assets/data/` by the hoard migration):
# each Markdown section becomes an episode with
# a content hash, tags, source, and timestamp. Episodes are appended to the local
# well store (`.agents/memory/well/episodes.jsonl`) and POSTed to the engram
# bridge (`MIMIRSBRUNN_URL`, default http://127.0.0.1:4602/observe) when it is
# reachable. Idempotent by content hash. Galdr-style: TOON out, structured errors.
#
# Usage: bin/mimir-ingest.sh [--dry-run] [--path <file-or-dir>] [--quiet]
#        bin/mimir-ingest.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOARD="${YMIR_HOARD:-$ROOT/hodd}"
# The business material lives in the hoard (private, untracked). Keep the old
# location as a fallback so a pre-migration home still works.
DATA="${BROKK_DATA_SOURCE:-$HOARD/docs/business}"
[ -e "$DATA" ] || DATA="$ROOT/assets/data"
STORE_DIR="$ROOT/.agents/memory/well"
STORE="$STORE_DIR/episodes.jsonl"
BRIDGE="${MIMIRSBRUNN_URL:-http://127.0.0.1:4602}"

DRY=0; QUIET=0; SRC="$DATA"
while [ $# -gt 0 ]; do
  case "$1" in
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --dry-run) DRY=1; shift ;;
    --quiet) QUIET=1; shift ;;
    --path) SRC=${2-}; shift 2 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/mimir-ingest.sh [--dry-run|--path <p>|--quiet]\n' "$1" >&2; exit 2 ;;
  esac
done

[ -e "$SRC" ] || { printf 'error: data path not found: %s\nhelp: pass --path, or put material in \$YMIR_HOARD/docs/business/\n' "$SRC"; exit 1; }

mkdir -p "$STORE_DIR"
[ -e "$STORE" ] || : >"$STORE"

# Load every hash already in the store once, so dedupe is O(1) per section
# instead of rescanning the whole store for each chunk (O(chunks x store)).
declare -A SEEN_HASH
while IFS= read -r _h; do [ -n "$_h" ] && SEEN_HASH["$_h"]=1; done < <(
  grep -o '"hash":"[^"]*"' "$STORE" 2>/dev/null | cut -d'"' -f4
)

have_bridge=0
if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 2 "$BRIDGE/health" >/dev/null 2>&1; then
  have_bridge=1
fi

declare -a FILE N ADD SKIP
total_add=0; total_skip=0; files=0

ingest_file() {
  local file=$1 rel chunks=0 added=0 skipped=0 heading="" para="" line
  rel="${file#"$ROOT"/}"
  while IFS= read -r line; do
    case "$line" in
      \#*)
        if [ -n "$heading" ] || [ -n "$para" ]; then
          content=$(printf '%s\n\n%s' "$heading" "$para" | sed -e 's/[[:space:]]*$//')
          if [ -n "$para" ]; then
            hash=$(printf '%s' "$content" | sha256sum | cut -d' ' -f1)
            if [ -n "${SEEN_HASH[$hash]:-}" ]; then
              skipped=$((skipped + 1))
            else
              SEEN_HASH[$hash]=1
              added=$((added + 1))
              if [ "$DRY" = 0 ]; then
                ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                json=$(printf '{"timestamp":"%s","source":"%s","tags":["data"],"content":%s,"hash":"%s"}' \
                  "$ts" "$rel" "$(printf '%s' "$content" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')" "$hash")
                printf '%s\n' "$json" >>"$STORE"
                if [ "$have_bridge" = 1 ]; then
                  curl -fsS --max-time 3 -X POST -H 'content-type: application/json' \
                    -d "$json" "$BRIDGE/observe" >/dev/null 2>&1 || true
                fi
              fi
            fi
          fi
          chunks=$((chunks + 1))
        fi
        heading="$line"
        para=""
        ;;
      *) para="${para:+$para$'\n'}$line" ;;
    esac
  done <"$file"
  # trailing section
  if [ -n "$para" ]; then
    content=$(printf '%s\n\n%s' "$heading" "$para" | sed -e 's/[[:space:]]*$//')
    hash=$(printf '%s' "$content" | sha256sum | cut -d' ' -f1)
    if [ -n "${SEEN_HASH[$hash]:-}" ]; then skipped=$((skipped + 1)); else
      SEEN_HASH[$hash]=1
      added=$((added + 1))
      if [ "$DRY" = 0 ]; then
        ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        json=$(printf '{"timestamp":"%s","source":"%s","tags":["data"],"content":%s,"hash":"%s"}' \
          "$ts" "$rel" "$(printf '%s' "$content" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')" "$hash")
        printf '%s\n' "$json" >>"$STORE"
        [ "$have_bridge" = 1 ] && curl -fsS --max-time 3 -X POST -H 'content-type: application/json' -d "$json" "$BRIDGE/observe" >/dev/null 2>&1 || true
      fi
    fi
    chunks=$((chunks + 1))
  fi
  FILE+=("$rel"); N+=("$chunks"); ADD+=("$added"); SKIP+=("$skipped")
  total_add=$((total_add + added)); total_skip=$((total_skip + skipped)); files=$((files + 1))
}

if [ -d "$SRC" ]; then
  while IFS= read -r f; do ingest_file "$f"; done < <(find "$SRC" -name '*.md' | sort)
else
  ingest_file "$SRC"
fi

if [ "$QUIET" = 0 ]; then
  printf 'mimir_ingest[%s]{source,sections,added,skipped}:\n' "${#FILE[@]}"
  for i in "${!FILE[@]}"; do
    printf '  "%s",%s,%s,%s\n' "${FILE[$i]}" "${N[$i]}" "${ADD[$i]}" "${SKIP[$i]}"
  done
fi
printf 'well: store=%s entries=%s bridge=%s\n' "${STORE#"$ROOT"/}" "$(wc -l <"$STORE" | tr -d ' ')" "$([ "$have_bridge" = 1 ] && echo online || echo offline)"
printf 'help[1]: query the well with `bin/rodd-operational-input.sh` kinds / the Mimirsbrunn bridge\n'
