#!/usr/bin/env bash
# garmr-canary.sh — the deletion tripwire: files that must never vanish.
#
# A hound cannot bite a file back into existence. So the one attack the bite CANNOT answer — a
# deletion, or a copy that ends in a delete — is answered by a canary: a small set of files whose
# presence and hash are checked on a cadence, with a written manifest.
#
#   garmr-canary.sh seed      # write the manifest from the canary list (run after a real change)
#   garmr-canary.sh check     # verify every canary exists and hashes the same  → exit 1 on a miss
#   garmr-canary.sh list      # what is watched
#
# The list lives in $YMIR_HOME/config/guardian.yaml under `canary:`, because a path is the
# operator's, not a script's (Rule 07). A miss is CRITICAL and goes to the arm — a deleted canary
# is not a warning, it is a recovery.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
home_or_die() { local h=""; declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root h 2>/dev/null; [ -n "$h" ] || h="${YMIR_HOME:-}"; [ -n "$h" ] || { echo 2; exit 2; }; printf '%s' "$h"; }
H="$(home_or_die)"; CFG="$H/config/guardian.yaml"; MAN="$H/state/garmr/canaries.manifest"
mkdir -p "$H/state/garmr" 2>/dev/null || true

canaries() {
  python3 - "$CFG" "$H" <<'PY'
import sys, os
try:
    import yaml
    d = yaml.safe_load(open(sys.argv[1])) or {}
except Exception:
    print("# no guardian config — nothing is watched"); raise SystemExit(0)
rows = d.get("canary") or []
if not rows:
    # the fallback asks the resolver's home (argv[2]); it never restates where the hoard lives.
    h = sys.argv[2]
    rows = [os.path.join(h, p) for p in ("hodd/memory/runes_audit.md",
                                         "hodd/identity/operator.yaml",
                                         "hodd/identity/companies.yaml")]
for r in rows:
    print(os.path.expanduser(str(r)))
PY
}

case "${1:-check}" in
  list) canaries ;;
  seed)
    : > "$MAN"
    while read -r f; do
      case "$f" in \#*|"") continue ;; esac
      if [ -e "$f" ]; then
        # append-only records are checked for PRESENCE, not for a hash: a ledger that grows by design
        # must not scream every time it is written to.
        case "$f" in */memory/*|*/state/*|*runes_audit*) mode=presence ;; *) mode=hash ;; esac
        printf '%s %s  %s\n' "$mode" "$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)" "$f" >> "$MAN"
        printf '  seeded %s\n' "$f"
      else
        printf '  MISSING AT SEED  %s\n' "$f"
      fi
    done < <(canaries)
    printf 'canary[2]{manifest,entries}:\n  "%s","%s"\n' "$MAN" "$(wc -l < "$MAN" | tr -d ' ')"
    ;;
  check)
    [ -r "$MAN" ] || { printf 'canary[1]{error}: "no manifest — run: garmr-canary.sh seed"\n' >&2; exit 1; }
    miss=0; drift=0
    while read -r mode hash f; do
      if [ ! -e "$f" ]; then
        printf '  "MISSING","%s","CRITICAL — a file that must never vanish is gone"\n' "$f"; miss=$((miss+1)); continue
      fi
      [ "$mode" = "presence" ] && continue
      now=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)
      [ "$now" = "$hash" ] || { printf '  "CHANGED","%s","HIGH — the content moved; if you did not edit it, someone did"\n' "$f"; drift=$((drift+1)); }
    done < "$MAN"
    printf 'canary[3]{checked,missing,changed}:\n  "%s",%s,%s\n' "$(wc -l < "$MAN" | tr -d ' ')" "$miss" "$drift"
    if [ $((miss+drift)) -gt 0 ]; then
      bash "$ROOT/bin/notify/send.sh" --source garmr --severity CRITICAL --key "canary-miss" \
        --message "Vidarr: ${miss} canary file(s) MISSING and ${drift} changed — a deletion is not a warning, it is a recovery" >/dev/null 2>&1 || true
      exit 1
    fi
    ;;
  *) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
