#!/usr/bin/env bash
# secrets-plaintext-guard.sh — the ward for the vault's own shelf (plan 342).
#
# The home is the vault (Rule 04), and `hodd/secrets/` is the shelf where the vault itself
# lives. Two shapes have already cost this house real secrecy:
#
#   · a **plain-text `*.env`** sitting beside the encrypted vault — measured 2026-11-20:
#     `hodd/secrets/marketing-stack.env` was committed in the clear with four logins in it;
#   · the **key beside the lock** — `hodd/secrets/age.key` was committed in the same
#     repository as the vault it opens, so a reader of the repository held both halves.
#     The vault is now locked to the owner's GitHub SSH keys (plan 342), and that file is
#     retiring; a commit that brings it back re-opens the lock for anyone who can read the
#     repository.
#
# So this ward refuses a commit that:
#
#   1. ADDS a non-empty plain-text `*.env` under `hodd/secrets/`  (an empty scaffold is
#      allowed — the installer seeds one so `hodd.sh emit` resolves on a fresh home);
#   2. ADDS `hodd/secrets/age.key` back;
#   3. MODIFIES a plain-text `*.env` that is already tracked there, which keeps a leak
#      alive in the clear with new content.
#
# It judges the home repository, never this tree — and it is seated in the home's own
# pre-commit hook by `bin/gates/guards/hoard-guard.sh --install`, beside the ward that
# reads for credential shapes.
#
# Usage:
#   secrets-plaintext-guard.sh            # the staged change (run by the home's pre-commit)
#   secrets-plaintext-guard.sh --all      # every tracked file in the home (a census)
#   secrets-plaintext-guard.sh --quiet    # no rows, the exit code is the answer
#
# Environment: YMIR_HOME (through bin/vault/hoard-lib.sh) · YMIR_SECRETS_GUARD_ROOT (the
# home repository, for a test that has no home) — one documented default each.
# Exit: 0 clean (or nothing to judge) · 1 a finding · 2 usage.
set -u
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

# shellcheck source=bin/vault/hoard-lib.sh
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ] && [ -r "$_ROOT/bin/vault/hoard-lib.sh" ]; then
  . "$_ROOT/bin/vault/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1
fi

MODE="staged"; QUIET=0
case "${1-}" in
  -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  --all) MODE="all"; [ "${2-}" = "--quiet" ] && QUIET=1 ;;
  --quiet) QUIET=1 ;;
  "") ;;
  *) printf 'error: unknown action %s\nhelp: secrets-plaintext-guard.sh [--all] [--quiet]\n' "$1" >&2; exit 2 ;;
esac

HOME_REPO="${YMIR_SECRETS_GUARD_ROOT:-}"
if [ -z "$HOME_REPO" ]; then
  h=""; ymir_home_root h 2>/dev/null || h=""
  [ -n "$h" ] && HOME_REPO="$h"
fi
row() { [ "$QUIET" = 1 ] || printf '  "%s","%s","%s"\n' "$1" "$2" "$3"; }

# No home, or a home that is not a git repository: a stated skip, never a silent pass.
if [ -z "$HOME_REPO" ] || ! command -v git >/dev/null 2>&1 || ! git -C "$HOME_REPO" rev-parse --git-dir >/dev/null 2>&1; then
  [ "$QUIET" = 1 ] || printf 'secrets-plaintext-guard[1]{finding,path,detail}:\n'
  row "clean-skip" "${HOME_REPO:-<unresolved>}" "no home repository here — nothing to judge"
  exit 0
fi

findings=0
plain_findings=0
key_findings=0

PLAIN_RE='^hodd/secrets/.*\.env$'
KEY_RE='^hodd/secrets/age\.key$'

# the size of a staged (or tracked) blob, without printing a byte of it
blob_size() {  # <path>
  git -C "$HOME_REPO" cat-file -s ":$1" 2>/dev/null || printf '0'
}

judge_added() {  # <path> — a newly committed file
  local f=$1 size
  if printf '%s' "$f" | grep -Eq "$KEY_RE"; then
    printf 'secrets-plaintext-guard: %s: the vault'"'"'s key is being committed again\n' "$f" >&2
    printf '  the vault is locked to the owner'"'"'s GitHub SSH keys (plan 342) — a key file beside it re-opens it for\n  anyone who can read the repository. Each seat keeps its own private key; nothing here.\n' >&2
    key_findings=$((key_findings + 1)); return 1
  fi
  if printf '%s' "$f" | grep -Eq "$PLAIN_RE"; then
    size="$(blob_size "$f")"
    if [ "${size:-0}" -eq 0 ]; then
      [ "$QUIET" = 1 ] || printf 'secrets-plaintext-guard: %s is an empty scaffold — allowed\n' "$f" >&2
      return 0
    fi
    printf 'secrets-plaintext-guard: %s: a plain-text secret is being committed (%s bytes, not printed)\n' "$f" "$size" >&2
    printf '  put the values in the encrypted vault instead: bin/vault/hodd-set.sh --stdin KEY secrets/platform.env\n' >&2
    plain_findings=$((plain_findings + 1)); return 1
  fi
  return 0
}

judge_modified() {  # <path> — a tracked plain-text env that is changing
  local f=$1 size
  printf '%s' "$f" | grep -Eq "$PLAIN_RE" || return 0
  printf '%s' "$f" | grep -Eq "$KEY_RE" && return 0
  size="$(blob_size "$f")"
  [ "${size:-0}" -eq 0 ] && return 0
  printf 'secrets-plaintext-guard: %s: a tracked plain-text secret is being changed in the clear\n' "$f" >&2
  printf '  retire it: move the values into the encrypted vault, then remove the plain file\n' >&2
  plain_findings=$((plain_findings + 1)); return 1
}

if [ "$MODE" = "all" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s' "$f" | grep -Eq "$KEY_RE" && { printf 'secrets-plaintext-guard: %s is tracked\n' "$f" >&2; key_findings=$((key_findings + 1)); continue; }
    printf '%s' "$f" | grep -Eq "$PLAIN_RE" || continue
    size="$(blob_size "$f")"
    if [ "${size:-0}" -gt 0 ]; then
      printf 'secrets-plaintext-guard: %s is tracked in the clear (%s bytes)\n' "$f" "$size" >&2
      plain_findings=$((plain_findings + 1))
    fi
  done < <(git -C "$HOME_REPO" ls-files 'hodd/secrets/*' 2>/dev/null)
else
  while IFS=$'\t' read -r status f; do
    [ -n "$f" ] || continue
    case "$status" in
      A|C|R*) judge_added "$f" ;;
      M)      judge_modified "$f" ;;
    esac
  done < <(git -C "$HOME_REPO" diff --cached --name-status --diff-filter=ACMR 2>/dev/null)
fi

findings=$((plain_findings + key_findings))
if [ "$findings" -gt 0 ]; then
  [ "$QUIET" = 1 ] || printf 'secrets-plaintext-guard[3]{finding,count,detail}:\n  "plain-text secret",%s,"under hodd/secrets"\n  "vault key",%s,"hodd/secrets/age.key must not come back"\n  "verdict","refused","nothing in this commit was changed by this ward"\n' "$plain_findings" "$key_findings"
  exit 1
fi
[ "$QUIET" = 1 ] || printf 'secrets-plaintext-guard[1]{finding,detail}:\n  "clean","no plain-text secret and no vault key is entering the home"\n'
exit 0
