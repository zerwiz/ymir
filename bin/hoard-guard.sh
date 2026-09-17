#!/usr/bin/env bash
# hoard-guard.sh — the ward for the PRIVATE HOME repo ($YMIR_HOME).
#
# Why this exists: the public repo has six guards, the home had none — yet the
# home is where every private byte lives. The one real leak of 2026-09-17
# (platform.env.prev-fill, 44 credentials) happened HERE, in a scratch backup
# swept up by `git add -A`. Nothing was watching.
#
# This is not a script an agent must remember to run. It is seated as
# .git/hooks/pre-commit in the home repo, so GIT runs it on every commit —
# including the ones made in a hurry, by a loop, or by an agent that has never
# heard of it.
#
#   bin/hoard-guard.sh            # scan the staged change (used as pre-commit)
#   bin/hoard-guard.sh --install  # seat it in $YMIR_HOME/.git/hooks/pre-commit
#   bin/hoard-guard.sh --all      # scan every tracked file in the home
#   bin/hoard-guard.sh --log-bypass <reason>   # record a --no-verify commit
#
# Exit 1 on any hit, so the commit is blocked before the secret is committed.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/hoard-lib.sh
. "$SCRIPT_DIR/hoard-lib.sh"
hoard_root HOARD
HOME_REPO="$(cd "$HOARD/.." && pwd)"
LEDGER="$HOARD/memory/runes_audit.md"

case "${1:-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --install)
    [ -d "$HOME_REPO/.git" ] || { printf 'hoard-guard: not a git repo: %s\n' "$HOME_REPO" >&2; exit 1; }
    hook="$HOME_REPO/.git/hooks/pre-commit"
    mkdir -p "$(dirname "$hook")" || exit 1
    printf '#!/usr/bin/env bash\n# seated by bin/hoard-guard.sh --install — the ward for the private home\nexec "%s/hoard-guard.sh" "$@"\n' "$SCRIPT_DIR" >"$hook"
    chmod +x "$hook"
    printf 'hoard-guard[1]{action,path}:\n  "install","%s"\n' "$hook"
    exit 0 ;;
  --log-bypass)
    # Called when a --no-verify commit is detected, so a bypass is visible after
    # the fact rather than silent.
    mkdir -p "$(dirname "$LEDGER")" 2>/dev/null || true
    printf '%s | hoard-guard BYPASS | %s | %s\n' \
      "$(date -Is)" "${1:-no reason given}" "$(git -C "$HOME_REPO" log -1 --format=%h 2>/dev/null || echo unknown)" >>"$LEDGER" 2>/dev/null || true
    printf 'hoard-guard[1]{action,logged}:\n  "bypass","%s"\n' "$LEDGER"
    exit 0 ;;
esac

# ── The checks ────────────────────────────────────────────────────────────────
# Every shape that caused, or could cause, a real leak.
SECRET_SHAPES='(AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|-----BEGIN OPENSSH PRIVATE KEY-----|(ghp|gho|ghs|ghr)_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]+|AIza[0-9A-Za-z_-]{35}|npm_[A-Za-z0-9]{30,})'

# Filenames that must never be tracked: plaintext vault files, scratch backups,
# anything that is a copy of a secret under another name.
BAD_NAME_RE='(^|/)(platform\.env|id_rsa|id_ed25519|\.env\.local|\.env\.realm)$'
SCRATCH_RE='(\.prev-|\.prev\.|\.bak$|\.orig$|\.scratch$|\.save$|~$|\.env\.[0-9])'
# Deliberately allowed: age.key IS the vault key and is committed by decision
# (see hodd/docs/secrets-vault.md). It is exempt BY NAME, in one place, so the
# exception is auditable rather than accidental.
ALLOWED_RE='^hodd/secrets/age\.key$'

why() { printf 'hoard-guard: %s: %s\n' "$2" "$1" >&2; }

# A base64 blob whose DECODE contains a PEM header — the evasion that would have
# hidden a key. The data arrives on fd 3, NOT stdin: a heredoc on stdin would
# otherwise consume the pipe and the checker would read nothing.
check_base64_pem() {  # <path-in-repo>; data on fd 3
  local f=$1
  python3 - "$f" /dev/fd/3 3<&3 <<'PY'
import base64, re, sys
try:
    data = open(sys.argv[2], 'rb').read()
except OSError:
    sys.exit(0)
for m in re.finditer(rb'[A-Za-z0-9+/=]{120,}', data):
    chunk = m.group(0)
    for cand in (chunk, chunk + b'=' * (-len(chunk) % 4)):
        try:
            dec = base64.b64decode(cand, validate=True)
        except Exception:
            continue
        if b'PRIVATE KEY' in dec or b'BEGIN OPENSSH' in dec:
            print(f"hoard-guard: possible secret in {sys.argv[1]} (base64-encoded key)", file=sys.stderr)
            sys.exit(1)
sys.exit(0)
PY
}

scan_list() {
  local hit=0 f blob
  while IFS= read -r f; do
    [ -n "$f" ] || continue

    case "$f" in
      */.gitignore|.gitignore) continue ;;
    esac
    if printf '%s' "$f" | grep -Eq "$ALLOWED_RE"; then continue; fi

    if printf '%s' "$f" | grep -Eq "$BAD_NAME_RE"; then
      why "$f" "plaintext secret file"; hit=1; continue
    fi
    if printf '%s' "$f" | grep -Eq "$SCRATCH_RE"; then
      why "$f" "scratch/backup file — this is the shape that leaked on 2026-09-17"
      hit=1; continue
    fi

    # Text only — a binary (sqlite, engram, image) has no secret shape to read
    # and would only emit null-byte noise.
    case "$f" in
      *.engram|*.engram-wal|*.engram-shm|*.db|*.db-wal|*.db-shm|*.png|*.jpg|*.jpeg|*.gif|*.pdf|*.zip|*.gz|*.tar|*.woff|*.woff2|*.ttf|*.ico|*.icns) continue ;;
    esac
    blob="$(git -C "$HOME_REPO" show ":$f" 2>/dev/null | head -c 400000 | tr -d '\000')" || continue
    [ -n "$blob" ] || continue

    if printf '%s' "$blob" | grep -Eq "$SECRET_SHAPES"; then
      why "$f" "possible secret"; hit=1; continue
    fi
    if ! check_base64_pem "$f" 3< <(printf '%s' "$blob"); then hit=1; fi
  done
  return "$hit"
}

if [ "${1:-}" = "--all" ]; then
  scan_list < <(git -C "$HOME_REPO" ls-files)
else
  scan_list < <(git -C "$HOME_REPO" diff --cached --name-only --diff-filter=ACM)
fi || {
  printf '\nhoard-guard: BLOCKED — the home repo is the vault. Do not commit this.\n' >&2
  printf '  move the secret to hodd/secrets/platform.env.age (encrypted)\n' >&2
  printf '  or delete the scratch file; see hodd/docs/secrets-vault.md\n' >&2
  exit 1
}
exit 0
