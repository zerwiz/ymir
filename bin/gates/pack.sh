#!/usr/bin/env bash
# pack.sh — Ymir's gate pack: one set of gates, kept here, seated byte for byte in every app repository.
#
#   bin/gates/pack.sh seat <repo-dir> [--ref <commit>] [--no-hooks]   copy the pack into a clone, write VENDORED
#   bin/gates/pack.sh check <repo-dir>                                is that clone's pack the same as Ymir's HEAD?
#   bin/gates/pack.sh status [--quiet]                                every app repository: current, behind or absent
#   bin/gates/pack.sh list                                            the files the pack seats
#
# WHAT THE PACK IS. Ymir's wards (bin/gates/pack/files.txt: secret, plaintext secrets, public, public-data, private,
# identity, PR identity, vault, gitleaks through secret-scan) plus the pack's own files (bin/gates/pack/tree/: the
# one door bin/gates/run-gates.sh, the hooks, the CI workflow, vendor-sync.sh, the planted-fault test, the root
# mark). `seat` copies both at a committed Ymir revision and records it in the repository's VENDORED; the
# repository's CI then proves the copies equal Ymir's at that revision (`vendor-sync.sh --check`) and that Ymir's
# main has not moved past them (`--behind`).
#
# THE DENY LIST STAYS IN THE HOME. Nothing here or in a seated repository carries the operator's words, hosts or
# mail domains, and nothing sends them to the hosting service. The hooks on a seat read them from $YMIR_HOME; CI
# judges shapes only.
#
# WHICH REPOSITORIES. `status` reads the app registry (config/app-repos.yaml: every app that is neither archived
# nor kept in Ymir's tree) and, when it exists, the home's own list `$YMIR_HOME/config/gate-pack-repos.txt`
# (one owner/repo per line) for repositories that are not apps.
#
# Exit: 0 done / current · 1 a refusal, or a repository not current · 2 usage.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACK="$ROOT/bin/gates/pack"

usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
wards() { grep -vE '^\s*(#|$)' "$PACK/files.txt"; }
tree_files() {  # paths relative to the tree, as committed at <ref>
  git -C "$ROOT" ls-tree -r --name-only "$1" -- bin/gates/pack/tree/ | sed 's#^bin/gates/pack/tree/##'
}

seat() {
  local dir="" ref=HEAD hooks=1
  while [ $# -gt 0 ]; do
    case "$1" in
      --ref) ref="${2:-}"; shift 2 ;;
      --no-hooks) hooks=0; shift ;;
      -*) usage ;;
      *) dir="$1"; shift ;;
    esac
  done
  [ -n "$dir" ] && git -C "$dir" rev-parse --show-toplevel >/dev/null 2>&1 || { printf 'error: %s is not a git clone\n' "${dir:-<repo-dir>}" >&2; exit 2; }
  dir="$(git -C "$dir" rev-parse --show-toplevel)"
  local full; full="$(git -C "$ROOT" rev-parse --verify "$ref^{commit}" 2>/dev/null)" || { printf 'error: Ymir has no commit %s\n' "$ref" >&2; exit 2; }
  git -C "$ROOT" cat-file -e "$full:bin/gates/pack/files.txt" 2>/dev/null || { printf 'error: Ymir %s carries no gate pack (commit it first)\n' "${full:0:12}" >&2; exit 2; }

  # Never take a file the repository wrote for itself: a pack path may only be new, identical, or already the pack's.
  local owned=() f src refused=0
  [ -r "$dir/VENDORED" ] && mapfile -t owned < <(awk '/^(files|pack):/ {on=1; next} /^[^ #]/ {on=0} on && /^  [^ ]/ {print $1}' "$dir/VENDORED")
  check_free() {  # <here> <ymir-path>
    [ -e "$dir/$1" ] || return 0
    local o; for o in "${owned[@]}"; do [ "$o" = "$1" ] && return 0; done
    git -C "$ROOT" show "$full:$2" | cmp -s - "$dir/$1" && return 0
    printf 'refused: %s already exists in %s and is not the pack'"'"'s — move it, or make it the pack'"'"'s by hand\n' "$1" "$(basename "$dir")" >&2
    refused=1
  }
  while IFS= read -r f; do check_free "$f" "$f"; done < <(git -C "$ROOT" show "$full:bin/gates/pack/files.txt" | grep -vE '^\s*(#|$)')
  while IFS= read -r f; do check_free "$f" "bin/gates/pack/tree/$f"; done < <(tree_files "$full")
  [ "$refused" = 0 ] || exit 1

  local n=0
  {
    printf '# VENDORED — Ymir'"'"'s gate pack in this repository, byte for byte.\n#\n'
    printf '# Ymir (github.com/zerwiz/ymir) owns these files. They are seated here by Ymir'"'"'s bin/gates/pack.sh, unchanged,\n'
    printf '# so a gate here judges exactly as it judges there. Never edit a copy: change it in Ymir, then re-seat with\n'
    printf '#   bin/gates/pack.sh seat <this repo>        (from a Ymir checkout)\n'
    printf '# `bin/gates/vendor-sync.sh --check` (CI) fails when a copy differs from Ymir at ymir_ref, and `--behind` when\n'
    printf '# Ymir'"'"'s main has moved past it. `files:` sit at the same path in Ymir; `pack:` sit under bin/gates/pack/tree/.\n'
    printf 'ymir_ref: %s\nfiles:\n' "$full"
    git -C "$ROOT" show "$full:bin/gates/pack/files.txt" | grep -vE '^\s*(#|$)' | sed 's/^/  /'
    printf 'pack:\n'
    tree_files "$full" | sed 's/^/  /'
  } > "$dir/VENDORED.new"
  while IFS= read -r f; do
    mkdir -p "$dir/$(dirname "$f")"; git -C "$ROOT" show "$full:$f" > "$dir/$f"; n=$((n + 1))
    case "$f" in *.sh|*.py) chmod +x "$dir/$f" ;; esac
  done < <(git -C "$ROOT" show "$full:bin/gates/pack/files.txt" | grep -vE '^\s*(#|$)')
  while IFS= read -r f; do
    mkdir -p "$dir/$(dirname "$f")"; git -C "$ROOT" show "$full:bin/gates/pack/tree/$f" > "$dir/$f"; n=$((n + 1))
    case "$f" in *.sh|*.py|.githooks/*) chmod +x "$dir/$f" ;; esac
  done < <(tree_files "$full")
  mv "$dir/VENDORED.new" "$dir/VENDORED"
  local seeded=""
  if [ ! -e "$dir/.gitleaks.toml" ]; then git -C "$ROOT" show "$full:bin/gates/pack/gitleaks.toml" > "$dir/.gitleaks.toml"; seeded=" · .gitleaks.toml seeded (the repository's own from now on)"; fi
  [ "$hooks" = 1 ] && bash "$dir/bin/gates/install-hooks.sh" >/dev/null 2>&1 || true
  printf 'pack: seated %s files from Ymir %s into %s%s\n' "$n" "${full:0:12}" "$dir" "$seeded"
  printf 'next: bash tests/gates.test.sh && bin/gates/run-gates.sh tree, then commit VENDORED with the files on a branch\n'
}

# A repository's pack is CURRENT when every file it vendors equals Ymir's HEAD. <ledger-file> -> verdict word
judge_ledger() {
  local ledger="$1" ref here there
  ref="$(awk '/^ymir_ref:/ {print $2; exit}' "$ledger")"
  [ -n "$ref" ] || { printf 'no-ref'; return; }
  git -C "$ROOT" cat-file -e "$ref^{commit}" 2>/dev/null || git -C "$ROOT" fetch -q origin "$ref" 2>/dev/null || true
  git -C "$ROOT" cat-file -e "$ref^{commit}" 2>/dev/null || { printf 'unknown-ref'; return; }
  local behind=0
  while IFS=$'\t' read -r here there; do
    [ "$(git -C "$ROOT" rev-parse -q --verify "$ref:$there" 2>/dev/null)" = "$(git -C "$ROOT" rev-parse -q --verify "HEAD:$there" 2>/dev/null)" ] || behind=1
  done < <(awk '/^files:/ {l="f"; next} /^pack:/ {l="p"; next} /^[^ #]/ {l=""}
               l && /^  [^ ]/ { if (l == "f") print $1 "\t" $1; else print $1 "\tbin/gates/pack/tree/" $1 }' "$ledger")
  # a ward the pack added since the ledger was written also makes it behind
  local w; while IFS= read -r w; do grep -qxF "  $w" "$ledger" || behind=1; done < <(wards)
  [ "$behind" = 0 ] && printf 'current' || printf 'behind'
}

check() {
  local dir="${1:-}"; [ -n "$dir" ] && [ -d "$dir" ] || usage
  [ -r "$dir/VENDORED" ] || { printf 'pack: %s carries no VENDORED — not seated\n' "$dir"; exit 1; }
  local v; v="$(judge_ledger "$dir/VENDORED")"
  printf 'pack: %s is %s against Ymir %s\n' "$dir" "$v" "$(git -C "$ROOT" rev-parse --short=12 HEAD)"
  [ "$v" = current ]
}

repos() {  # owner/repo, one per line
  awk '/^- id:/ {if (r) print r; r=""; skip=0}
       /status: *archived/ || /stays_in_ymir: *true/ {skip=1}
       /git: *\{/ { match($0, /owner: *[^,}]+/); o=substr($0, RSTART+6, RLENGTH-6); gsub(/ /, "", o)
                    match($0, /repo: *[^,}]+/); p=substr($0, RSTART+5, RLENGTH-5); gsub(/ /, "", p)
                    if (!skip) r=o "/" p }
       /status: *archived/ || /stays_in_ymir: *true/ {r=""}
       END {if (r) print r}' "$ROOT/config/app-repos.yaml"
  local home="${YMIR_HOME:-}"
  if [ -z "$home" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
    home="$(bash -c '. "$1" 2>/dev/null; ymir_home_root h 2>/dev/null; printf %s "${h:-}"' _ "$ROOT/bin/vault/hoard-lib.sh")"
  fi
  [ -n "$home" ] && [ -r "$home/config/gate-pack-repos.txt" ] && grep -vE '^\s*(#|$)' "$home/config/gate-pack-repos.txt"
  return 0
}

status() {
  local quiet=0; [ "${1:-}" = --quiet ] && quiet=1
  command -v gh >/dev/null 2>&1 || { printf 'pack: gh is not installed here — the repositories cannot be read\n'; exit 1; }
  local tmp r v n=0 bad=0 rows=""
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' RETURN
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    n=$((n + 1))
    if timeout 20 gh api -H 'Accept: application/vnd.github.raw' "repos/$r/contents/VENDORED" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      v="$(judge_ledger "$tmp")"
    else
      v="absent"
    fi
    [ "$v" = current ] || bad=$((bad + 1))
    rows="${rows}  \"$r\",\"$v\"\n"
  done < <(repos | sort -u)
  if [ "$quiet" = 1 ]; then
    printf 'gate pack: %s of %s app repositories current\n' "$((n - bad))" "$n"
  else
    printf 'gate_pack[%s]{repo,state}:\n%b' "$n" "$rows"
    printf 'verdict: %s of %s current against Ymir %s (absent = no pack on the default branch; behind = re-seat it)\n' \
      "$((n - bad))" "$n" "$(git -C "$ROOT" rev-parse --short=12 HEAD)"
  fi
  [ "$bad" = 0 ]
}

case "${1:-}" in
  seat)   shift; seat "$@" ;;
  check)  shift; check "$@" ;;
  status) shift; status "$@" ;;
  list)   wards; tree_files HEAD ;;
  *) usage ;;
esac
