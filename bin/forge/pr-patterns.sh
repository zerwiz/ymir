#!/usr/bin/env bash
# pr-patterns.sh — the ONE place the forbidden-pattern list lives.
# Sourced by both the door (pr-open.sh) and the ward (pr-identity-guard.sh).
# Usage: pr_pattern_match <text-file-or->  -> prints "label: <match>" on first hit, else nothing; rc 1 if clean.
set -u

pr_pattern_check_line() {
  # prints match label if line forbidden, else empty
  local line="$1"
  # ipv4
  if printf '%s' "$line" | grep -Eq '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'; then echo "ipv4"; return; fi
  # ipv6 (rough)
  if printf '%s' "$line" | grep -Eq '[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:'; then echo "ipv6"; return; fi
  # ts.net
  if printf '%s' "$line" | grep -Eq '[A-Za-z0-9-]+\.ts\.net'; then echo "tsnet"; return; fi
  # tailscale
  if printf '%s' "$line" | grep -Eiq 'tailscale'; then echo "tailscale"; return; fi
  # paths
  if printf '%s' "$line" | grep -Eq '~|/home/|/Users/'; then echo "homepath"; return; fi
  # mailbox (not noreply)
  if printf '%s' "$line" | grep -Eo '[^[:space:]]+@[^[:space:]]+' | grep -vq 'users\.noreply\.github\.com'; then
    # only flag if there IS a mailbox not noreply
    if printf '%s' "$line" | grep -Eq '[^[:space:]]+@[^[:space:]]+'; then
      if ! printf '%s' "$line" | grep -Eq '@users\.noreply\.github\.com'; then echo "mailbox"; return; fi
      # mixed: a non-noreply mailbox alongside noreply
      local m; m=$(printf '%s' "$line" | grep -Eo '[^[:space:]]+@[^[:space:]]+' | grep -v 'users\.noreply\.github\.com' || true)
      [ -n "$m" ] && { echo "mailbox"; return; }
    fi
  fi
  # pane id
  if printf '%s' "$line" | grep -Eq 'w[0-9]+:p[0-9]+'; then echo "paneid"; return; fi
  # token-shaped
  if printf '%s' "$line" | grep -Eiq '(bearer|token|secret|api[_-]?key)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9._-]{8,}'; then echo "token"; return; fi
}

pr_pattern_match() {
  # arg: file path or - for stdin
  local src="${1:--}"
  local f; if [ "$src" = "-" ]; then f=/dev/stdin; else f="$src"; fi
  while IFS= read -r line || [ -n "$line" ]; do
    local r; r=$(pr_pattern_check_line "$line")
    if [ -n "$r" ]; then
      printf '%s: %s\n' "$r" "$line"
      return 0
    fi
  done < "$f"
  return 1
}
