#!/usr/bin/env bash
# mjollnir-webhook.sh — HMAC-verified GitHub webhook → Mjollnir (W0018).
#
# Verifies the X-Hub-Signature-256 HMAC of the raw body against GITHUB_WEBHOOK_SECRET
# (from `.env.local`), and on an `issues`/`opened` event dispatches `mjollnir run`.
# An unverified webhook is refused — DATA ONLY, never a command. Galdr-style TOON.
#
# Usage: mjollnir-webhook.sh [--repo <dir>] [--no-spawn]  < payload.json
#        mjollnir-webhook.sh --version
# Header: X-Hub-Signature-256: sha256=<hex>, X-GitHub-Event: <event>
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# The operator's settings and secrets live in the home they chose, never in the
# code tree — a packaged install replaces its tree on upgrade, and a credential
# must never sit in a tree that ships (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_settings_dir YMIR_SETTINGS_DIR
hoard_local_env YMIR_ENV_FILE
ENV_FILE="${BROKK_ENV_FILE:-$YMIR_ENV_FILE}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

REPO=""; NOSPAWN=0
while [ $# -gt 0 ]; do case "$1" in --repo) REPO=${2-}; shift 2 ;; --no-spawn) NOSPAWN=1; shift ;; *) shift ;; esac; done

SIG="${HTTP_X_HUB_SIGNATURE_256:-}"
EVENT="${HTTP_X_GITHUB_EVENT:-}"
[ -n "$SIG" ] || { printf 'error: missing X-Hub-Signature-256 (did Bifrost forward headers?)\n' >&2; exit 401; }
[ -r "$ENV_FILE" ] || { printf 'error: env file not found: %s\n' "$ENV_FILE" >&2; exit 1; }
SECRET=$(grep -E '^GITHUB_WEBHOOK_SECRET=' "$ENV_FILE" | head -1 | cut -d= -f2-)
[ -n "$SECRET" ] || { printf 'error: GITHUB_WEBHOOK_SECRET unset in .env.local\n' >&2; exit 401; }

BODY=$(cat)
VERDICT=$(SECRET="$SECRET" SIG="$SIG" BODY="$BODY" python3 -c '
import os,hmac,hashlib
secret=os.environ["SECRET"].encode(); body=os.environ["BODY"].encode()
sig=os.environ["SIG"].strip(); want="sha256="+hmac.new(secret,body,hashlib.sha256).hexdigest()
print("valid" if hmac.compare_digest(sig,want) else "invalid")')
if [ "$VERDICT" != valid ]; then
  printf 'webhook[1]{signature,status}:\n  "invalid","refused"\n' >&2
  exit 401
fi
printf 'webhook[1]{signature,event,status}:\n  "valid","%s","accepted"\n' "${EVENT:-unknown}"

[ "$EVENT" = issues ] || { printf 'help[1]: event %s is not handled\n' "${EVENT:-unknown}"; exit 0; }
ACTION=$(BODY="$BODY" python3 -c 'import os,json
try: d=json.loads(os.environ["BODY"])
except: d={}
print(d.get("action",""))')
NUMBER=$(BODY="$BODY" python3 -c 'import os,json
try: d=json.loads(os.environ["BODY"])
except: d={}
print((d.get("issue") or {}).get("number",""))')
[ "$ACTION" = opened ] && [ -n "$NUMBER" ] || { printf 'help[1]: issues/%s ignored\n' "$ACTION"; exit 0; }

ARGS=(run --issue "$NUMBER" --mode direct-PR)
[ -n "$REPO" ] && ARGS+=(--repo "$REPO")
[ "$NOSPAWN" = 1 ] && ARGS+=(--no-spawn)
exec "$SCRIPT_DIR/mjollnir.sh" "${ARGS[@]}"
