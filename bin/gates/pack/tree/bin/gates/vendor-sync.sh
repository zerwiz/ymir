#!/usr/bin/env bash
# vendor-sync.sh — keep Ymir's gate pack in step with Ymir. Part of the pack (see VENDORED): never edit it here.
#
#   bin/gates/vendor-sync.sh --check            every file VENDORED lists equals Ymir's at the recorded commit
#   bin/gates/vendor-sync.sh --behind [<ref>]   every file equals Ymir's at <ref> (default: main) — fails when the
#                                               copy here has fallen behind Ymir
#   bin/gates/vendor-sync.sh --update <commit>  copy the files from a local Ymir checkout at <commit>, record it
#
# VENDORED holds two lists. `files:` are Ymir's wards, at the same path in Ymir. `pack:` are the pack's own files
# (this door, run-gates.sh, the hooks, the workflow, the tests), kept in Ymir under bin/gates/pack/tree/<path>.
#
# Where Ymir is read from, in order: $YMIR_SRC (a checkout), $HOME/ymir, $HOME/ymir-runtime, then the public repository
# over https (raw.githubusercontent.com), which is what CI uses. A copy that differs is a red gate: the fix is in
# Ymir (bin/gates/pack.sh seat), never in the copy.
#
# Exit: 0 in step · 1 a copy differs, is missing or is behind · 2 usage or Ymir cannot be read.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER="$ROOT/VENDORED"
YMIR_REPO="${YMIR_GATES_UPSTREAM:-zerwiz/ymir}"
[ -r "$LEDGER" ] || { printf 'error: %s is missing\n' "$LEDGER" >&2; exit 2; }

ref_of() { awk '/^ymir_ref:/ {print $2; exit}' "$LEDGER"; }
# <here-path> TAB <ymir-path>, for both lists
entries() {
  awk '/^files:/ {l="f"; next} /^pack:/ {l="p"; next} /^[^ #]/ {l=""}
       l && /^  [^ ]/ { if (l == "f") print $1 "\t" $1; else print $1 "\tbin/gates/pack/tree/" $1 }' "$LEDGER"
}

ymir_checkout_with() {
  local sha="$1" c
  for c in "${YMIR_SRC:-}" "$HOME/ymir" "$HOME/ymir-runtime"; do
    [ -n "$c" ] && [ -d "$c" ] || continue
    git -C "$c" cat-file -e "$sha^{commit}" 2>/dev/null && { printf '%s' "$c"; return 0; }
  done
  return 1
}

read_ymir_file() {  # <ref> <path> -> stdout
  local ref="$1" path="$2" c
  if c="$(ymir_checkout_with "$ref")"; then
    git -C "$c" show "$ref:$path"
  else
    curl -fsSL --connect-timeout 10 --max-time 30 --retry 2 "https://raw.githubusercontent.com/$YMIR_REPO/$ref/$path"
  fi
}

compare() {  # <ref> <mode: check|behind>
  local ref="$1" mode="$2" here there bad=0 n=0 tmp
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' RETURN
  printf 'vendor_sync[%s]{file,verdict}:\n' "$(entries | wc -l | tr -d ' ')"
  while IFS=$'\t' read -r here there; do
    n=$((n + 1))
    if ! read_ymir_file "$ref" "$there" > "$tmp" 2>/dev/null; then
      if [ "$mode" = behind ]; then printf '  "%s","not on Ymir %s yet — the pack is newer than it"\n' "$here" "$ref"; continue; fi
      printf '  "%s","cannot read Ymir at %s"\n' "$here" "${ref:0:12}"; bad=2; continue
    fi
    if [ ! -f "$ROOT/$here" ]; then printf '  "%s","MISSING here"\n' "$here"; [ "$bad" = 0 ] && bad=1; continue; fi
    if cmp -s "$tmp" "$ROOT/$here"; then printf '  "%s","same"\n' "$here"
    elif [ "$mode" = behind ]; then printf '  "%s","BEHIND Ymir %s — re-seat it: bin/gates/pack.sh seat <this repo>"\n' "$here" "$ref"; [ "$bad" = 0 ] && bad=1
    else printf '  "%s","DIFFERS from Ymir — change it in Ymir, then re-seat"\n' "$here"; [ "$bad" = 0 ] && bad=1; fi
  done < <(entries)
  [ "$bad" = 0 ] && printf 'verdict: %s files in step with Ymir %s\n' "$n" "${ref:0:12}"
  return "$bad"
}

case "${1:-}" in
  --check)
    sha="$(ref_of)"; [ -n "$sha" ] || { printf 'error: VENDORED names no ymir_ref\n' >&2; exit 2; }
    compare "$sha" check; exit $? ;;
  --behind)
    compare "${2:-main}" behind; exit $? ;;
  --update)
    sha="${2:-}"; [ -n "$sha" ] || { printf 'error: --update needs a Ymir commit\n' >&2; exit 2; }
    c="$(ymir_checkout_with "$sha")" || { printf 'error: no local Ymir checkout has %s (set YMIR_SRC)\n' "$sha" >&2; exit 2; }
    full="$(git -C "$c" rev-parse "$sha^{commit}")"
    while IFS=$'\t' read -r here there; do
      mkdir -p "$ROOT/$(dirname "$here")"
      git -C "$c" show "$full:$there" > "$ROOT/$here" || exit 2
      case "$here" in *.sh|*.py|.githooks/*) chmod +x "$ROOT/$here" ;; esac
    done < <(entries)
    sed -i "s|^ymir_ref:.*|ymir_ref: $full|" "$LEDGER"
    printf 'vendor-sync: copied from Ymir %s — run the tests, then commit VENDORED with the copies\n' "${full:0:12}"
    exit 0 ;;
  *) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
