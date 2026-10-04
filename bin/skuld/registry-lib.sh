#!/usr/bin/env bash
# registry-lib.sh — the ONE reader for the master project registry's row keys.
#
# Plan 62 renamed a project row's `workspace:` key to `realm:`: a row never named a
# workspace, it named the realm. A registry written before the rename must keep
# working — a silent break here is the whole risk of the rename — so every reader
# resolves the value THROUGH THIS FILE: `realm` first, `workspace` as a deprecated
# alias that is always named out loud when it is used. Never resolve the realm key
# anywhere else.
#
# Usage:
#   . bin/skuld/registry-lib.sh
#   registry_projects_file                 # → the master registry's path
#   registry_realm <block> <id> <file>     # → the realm; warns on the old key
#   registry_deprecated_rows <file>        # → "id<TAB>value" per row on the old key
set -u

# The old key. Named once, so the warning and the ward can never disagree.
REGISTRY_DEPRECATED_KEY="${REGISTRY_DEPRECATED_KEY:-workspace}"

_registry_dir() { cd "$(dirname "${BASH_SOURCE[0]}")" && pwd; }

_registry_load_hoard() {
  [ -z "${REGISTRY_LIB_HOARD_LOADED:-}" ] || return 0
  local d; d="$(_registry_dir)"
  # shellcheck source=bin/vault/hoard-lib.sh
  [ -r "$d/hoard-lib.sh" ] && . "$d/hoard-lib.sh" && REGISTRY_LIB_HOARD_LOADED=1
  return 0
}

# Where the master project registry lives: the explicit env, else the hoard, else
# the repo's shape. Rule 07 — the home is resolved, never restated.
registry_projects_file() {
  _registry_load_hoard
  local d h reg
  d="$(_registry_dir)"
  h=""
  hoard_root h 2>/dev/null || true
  if [ -n "${PROJECTS_YAML:-}" ]; then reg="$PROJECTS_YAML"
  elif [ -n "${h:-}" ]; then reg="$h/identity/projects.yaml"
  else reg="$d/../registry/projects.yaml"; fi
  printf '%s\n' "$reg"
}

# The named warning. A reader that sees the old key always says so, by name.
registry_deprecated_key_warn() {  # <id> <source>
  printf 'deprecated-registry-key: row "%s" carries `%s:` in %s; renamed to `realm:` (plan 62) — the value still resolves, but the row should be renamed.\n' \
    "${1-}" "$REGISTRY_DEPRECATED_KEY" "${2-}" >&2
}

# The realm of one project block. Reads `realm`; falls back to the deprecated
# `workspace:` alias and warns, by name, exactly once per resolution.
registry_realm() {  # <block> <id> <source>
  local block="${1-}" id="${2-}" src="${3-}" v
  v="$(printf '%s' "$block" | sed -nE 's/^[[:space:]]*realm:[[:space:]]*([^,}]+).*/\1/p' | head -1 | tr -d ' ')"
  if [ -n "$v" ]; then printf '%s' "$v"; return 0; fi
  v="$(printf '%s' "$block" | sed -nE "s/^[[:space:]]*$REGISTRY_DEPRECATED_KEY:[[:space:]]*([^,}]+).*/\1/p" | head -1 | tr -d ' ')"
  [ -n "$v" ] || return 0
  registry_deprecated_key_warn "$id" "$src"
  printf '%s' "$v"
}

# Every project row still on the old key, as "id<TAB>value". A row carrying BOTH
# keys is on the new key — it is not listed, because it resolves without warning.
registry_deprecated_rows() {  # <file>
  [ -r "${1-}" ] || return 0
  awk -v old="$REGISTRY_DEPRECATED_KEY" '
    /^[[:space:]]*-[[:space:]]+id:/ { sub(/^[[:space:]]*-[[:space:]]+id:[[:space:]]*/, ""); gsub(/[[:space:]]+$/, ""); id=$0 }
    /^[[:space:]]*realm:/ { realm[id]=1 }
    $0 ~ "^[[:space:]]*" old ":" {
      line=$0; sub("^[[:space:]]*" old ":[[:space:]]*", "", line); gsub(/[[:space:]]+$/, "", line)
      legacy[id]=line
    }
    END { for (i in legacy) if (!(i in realm)) printf "%s\t%s\n", i, legacy[i] }
  ' "${1-}" | sort
}