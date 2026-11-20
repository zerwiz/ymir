#!/usr/bin/env bash
# pr-patterns.sh — the ONE place the forbidden-pattern list lives.
# Sourced by both the door (pr-open.sh) and the ward (pr-identity-guard.sh).
# Usage: pr_pattern_match <text-file-or->  -> prints "label: <match>" on first hit, else nothing; rc 1 if clean.
set -u

# ── a SHAPE is not a VALUE (2026-11-16) ─────────────────────────────────────────────────────────────
# RULES/04 says it in its own words: "shape, never by value — a literal `/home/<name>/`". The ward
# read the SHAPE as the leak and refused `~` wherever it appeared, so a body or a note explaining
# `~75 commits behind` or `… ~/Documents/ymirhome …` was refused as if it published a home. Measured
# 2026-11-15 on PR #770 and PR #771: both were about code, and the record of the fix was the finding.
#   · `~`, `~/…`, `/home/<name>/`, `/home/example/…`, `$HOME/…`  → a SHAPE. It names nobody. Allowed.
#   · `/home/<a concrete account>/…`, `/Users/<a concrete account>/…` → a VALUE: a real place this
#     house stands, refused in prose and in code alike, because the address is the leak.
PR_HOME_PLACEHOLDER='example|user|username|name|nobody|anonymous|operator|you|me|someone|shared'

# ── a MAILBOX has a DOMAIN, a role token does not (2026-11-20) ─────────────────────────────────────
# The ward read any `word@word` as an address, so a pull-request body quoting a cron row —
# "The Nornir row `@dev 03:05 …` runs" — was refused by pr-identity-guard in CI as if it published
# a mailbox. `@dev` and `@heart` are ROLE tokens in the schedule the house writes; an address is a
# local part and a DOT-SEPARATED domain (`example.org`, `sub.example.co.uk`). The dot is the test:
# without it there is no address to publish, and refusing one teaches the hand to hide the schedule.
PR_MAILBOX='[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+'

# pr_homepath_value <line> — prints the concrete home path the line carries, or nothing.
pr_homepath_value() {
  local line="$1" p u
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    u="${p##*/}"
    case "$u" in
      '<'*'>') continue ;;                 # /home/<name>/ — the shape the rule asks for
      '$'*|'${'*) continue ;;              # $HOME/runtime — a variable, not a place
    esac
    printf '%s' "$u" | grep -Eqi "^($PR_HOME_PLACEHOLDER)$" && continue
    printf '%s' "$p"; return 0
  done < <(printf '%s\n' "$line" | grep -Eo '/(home|Users)/[^/[:space:]`"'"'"',;)]+' || true)
  return 1
}

# pr_line_is_code <line> <in_fence 0|1> — is this line code, or is it prose?
# A document is both: the sentence that describes a fault, and the command it quotes. The ward that
# refuses a PLACE (a home path, an address, a host) must read the code; the prose is the record.
pr_line_is_code() {
  local line="$1" fence="${2:-0}"
  [ "$fence" = 1 ] && return 0
  case "$line" in
    '```'*|'~~~'*) return 0 ;;
    '    '*|$'\t'*) return 0 ;;
    '#!/'*) return 0 ;;
  esac
  printf '%s' "$line" | grep -Eq '`[^`]+`' && return 0
  printf '%s' "$line" | grep -Eq '^[[:space:]]*(\$|sudo|bash|sh|env|curl|wget|ssh|scp|git|python3?|node|npm|pnpm|cd|export|source|ln|cp|mv|mkdir|chmod|systemctl|launchctl|docker|podman|\./|/)' && return 0
  return 1
}

pr_pattern_check_line() {
  # prints match label if line forbidden, else empty
  local line="$1" hp
  # ipv4
  if printf '%s' "$line" | grep -Eq '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'; then echo "ipv4"; return; fi
  # ipv6 (rough)
  if printf '%s' "$line" | grep -Eq '[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:'; then echo "ipv6"; return; fi
  # ts.net
  if printf '%s' "$line" | grep -Eq '[A-Za-z0-9-]+\.ts\.net'; then echo "tsnet"; return; fi
  # tailscale
  if printf '%s' "$line" | grep -Eiq 'tailscale'; then echo "tailscale"; return; fi
  # paths — a VALUE only: `~` is a shape and names nobody (2026-11-16)
  if hp=$(pr_homepath_value "$line"); then echo "homepath ($hp)"; return; fi
  # mailbox (not noreply) — an address carries a dot-separated domain; `@dev` is a role token
  local m; m=$(printf '%s' "$line" | grep -Eo "$PR_MAILBOX" | grep -v 'users\.noreply\.github\.com' || true)
  if [ -n "$m" ]; then echo "mailbox"; return; fi
  # pane id
  if printf '%s' "$line" | grep -Eq 'w[0-9]+:p[0-9]+'; then echo "paneid"; return; fi
  # token-shaped
  if printf '%s' "$line" | grep -Eiq '(bearer|token|secret|api[_-]?key)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9._-]{8,}'; then echo "token"; return; fi
}

# pr_maker_match <file> -> prints the refusal and returns 0 when prose names an AI maker or product
# (RULES/53). The word list lives in bin/forge/maker-names.py — one matcher, never a second.
pr_maker_match() {
  local here; here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local out; out="$(python3 "$here/maker-names.py" scan "$1" "${@:2}" 2>&1)" && return 1
  printf '%s\n' "$out" | head -1
  return 0
}

pr_pattern_match() {
  # arg: file path or - for stdin
  local src="${1:--}"
  local f; if [ "$src" = "-" ]; then f=/dev/stdin; else f="$src"; fi
  if [ "$f" != /dev/stdin ] && m=$(pr_maker_match "$f"); then printf '%s\n' "$m"; return 0; fi
  while IFS= read -r line || [ -n "$line" ]; do
    local r; r=$(pr_pattern_check_line "$line")
    if [ -n "$r" ]; then
      printf '%s: %s\n' "$r" "$line"
      return 0
    fi
  done < "$f"
  return 1
}
