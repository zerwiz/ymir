#!/usr/bin/env bash
# model-fetch.sh — fetch a chosen model into the operator's models directory.
#
# Resumable, checksum-verified, and consent-first: a multi-GB download is a
# network act and never happens silently. The file lands in the hoard
# ($YMIR_HOME/models), never the code tree. A missing checksum is a LOUD refusal
# unless the operator explicitly accepts an unverified artifact.
#
# Usage:
#   model-fetch.sh <candidate-id>            # dry-run: say what would download
#   model-fetch.sh <candidate-id> --consent  # download (resumable, verified)
#   model-fetch.sh <candidate-id> --force    # re-download even if present
#   model-fetch.sh --version
#
# Env:
#   YMIR_MODELS_DIR        — where models live (default $YMIR_HOME/models)
#   YMIR_MODEL_CATALOG     — the catalog (default $YMIR_SETTINGS_DIR/model-catalog.yaml)
#   YMIR_ALLOW_UNVERIFIED  — "1" to accept a candidate with no sha256 (loud)
#
# Exit: 0 fetched/present, 2 usage, 3 no such candidate, 4 no consent, 5 failed.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
hoard_settings_dir YMIR_SETTINGS_DIR
ymir_home_root YMIR_HOME
CATALOG="${YMIR_MODEL_CATALOG:-$YMIR_SETTINGS_DIR/model-catalog.yaml}"
MODELS_DIR="${YMIR_MODELS_DIR:-$YMIR_HOME/models}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

ID=""; CONSENT=0; FORCE=0
while [ $# -gt 0 ]; do case "$1" in
  --consent) CONSENT=1; shift ;;
  --force) FORCE=1; shift ;;
  -*) shift ;;
  *) [ -z "$ID" ] && ID="$1"; shift ;;
esac; done
[ -n "$ID" ] || { printf 'error: usage: bin/model-fetch.sh <candidate-id> [--consent] [--force]\n' >&2; exit 2; }
[ "${YMIR_FETCH_CONSENT:-0}" = "1" ] && CONSENT=1
[ "${YMIR_ALLOW_UNVERIFIED:-0}" = "1" ] || true
have() { command -v "$1" >/dev/null 2>&1; }

# Read the candidate's fields from the catalog as shell assignments (shlex-quoted
# so an empty value or a URL with spaces survives).
eval "$(python3 - "$CATALOG" "$ID" <<'PY'
import sys, shlex
try:
    import yaml
except Exception:
    sys.exit(0)
try:
    cfg = yaml.safe_load(open(sys.argv[1])) or {}
except Exception:
    sys.exit(0)
for c in (cfg.get("candidates") or []):
    if str(c.get("id")) == sys.argv[2]:
        for key, val in (("META_URL", c.get("url") or ""),
                         ("META_SHA", c.get("sha256") or ""),
                         ("META_SIZE", c.get("size_gb") or "")):
            print(f"{key}={shlex.quote(str(val))}")
        break
PY
)"
META_URL="${META_URL:-}"; META_SHA="${META_SHA:-}"; META_SIZE="${META_SIZE:-}"

[ -n "${META_SIZE:-}" ] || { printf 'error: no candidate %s in %s\nhelp: bin/model-fit.sh or edit the catalog\n' "$ID" "$CATALOG" >&2; exit 3; }
[ -n "${META_URL:-}" ] || { printf 'error: candidate %s has no url in %s\n' "$ID" "$CATALOG" >&2; exit 3; }
[ -n "${META_SHA:-}" ] || [ "${YMIR_ALLOW_UNVERIFIED:-0}" = "1" ] || {
  printf 'error: candidate %s has no sha256 — refusing an unverified download\n' "$ID" >&2
  printf 'help: set the checksum in %s, or set YMIR_ALLOW_UNVERIFIED=1 to accept it loudly.\n' "$CATALOG" >&2
  exit 5
}

DEST="${YMIR_MODELS_DIR:-$MODELS_DIR}/$ID.gguf"
mkdir -p "$(dirname "$DEST")"

sha_ok() {  # <file>
  [ -z "${META_SHA:-}" ] && return 1
  [ -f "$1" ] || return 1
  printf '%s  %s\n' "$META_SHA" "$1" | sha256sum -c --status 2>/dev/null
}

if [ -f "$DEST" ] && [ "$FORCE" != 1 ]; then
  if sha_ok "$DEST"; then
    printf 'model-fetch[1]{id,state,path}:\n  "%s","present (checksum ok)","%s"\n' "$ID" "$DEST"
    exit 0
  fi
  printf 'model-fetch[1]{id,state,path}:\n  "verify","exists but checksum differs — resuming","%s"\n' "$DEST"
fi

if [ "$CONSENT" != 1 ]; then
  printf 'model-fetch[1]{id,state,url,size_gb,path}:\n  "would-download","consent needed","%s","%s","%s"\n' "$META_URL" "$META_SIZE" "$DEST"
  printf 'help: re-run with --consent to download (~%s GB).\n' "$META_SIZE" >&2
  exit 4
fi

have curl || { printf 'error: curl is required to fetch\n' >&2; exit 5; }

# Resumable: -C - continues a partial file; a fresh file starts at 0.
printf 'model-fetch[1]{id,state,url,dest}:\n  "download","resuming","%s","%s"\n' "$META_URL" "$DEST"
if ! curl -fL --retry 3 --retry-delay 2 -C - -o "$DEST" "$META_URL"; then
  printf 'error: download failed; the partial file is kept — re-run to resume\n' >&2
  exit 5
fi

if ! sha_ok "$DEST"; then
  printf 'error: checksum mismatch for %s\nhelp: the file may be corrupt — re-run with --force\n' "$DEST" >&2
  exit 5
fi
printf 'model-fetch[1]{id,state,path}:\n  "%s","downloaded (checksum ok)","%s"\n' "$ID" "$DEST"
