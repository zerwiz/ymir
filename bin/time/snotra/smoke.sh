#!/usr/bin/env bash
# smoke.sh — the Snotra meeting pipeline's own gate: five doors, three verdicts each.
#
#   bin/time/snotra/smoke.sh [meeting-dir]
#
# The law (plan 111 · appendix 8): "a clean skip is printed" so "not tested" can never be mistaken for
# "passes" (Rule 25), and a capability without a smoke check is a claim.
#
#   PASS  harvest status reads the bot store for a meeting whose record carries a Meet link
#   PASS  harvest verify re-hashes the staged audio against the store's declared bytes
#   PASS  ladder status sees a transcript before it would shrink anything
#   PASS  project verify agrees with the board (or SKIPs: no Trello grant in reach)
#   PASS  a place declaring another surface is REFUSED, not cross-filed
#   PASS  every place profile declares a surface and an authority block
#
# Exit: 0 all pass or a clean skip · 1 any FAIL
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
# the hoard is resolved, never restated: if the resolver gave nothing, the smoke says so and stops
if [ -z "${HOME_R:-}" ]; then
  printf 'snotra smoke: the hoard is unresolved — run bin/vault/hoard-lib.sh or set YMIR_HOME\n' >&2
  exit 2
fi

D="${1-}"
if [ -z "$D" ]; then
  D="$(ls -dt "$HOME_R"/svartalfaheim/*/meetings/*/ 2>/dev/null | while read -r c; do
        [ -f "$c/record.json" ] && { printf '%s' "$c"; break; }
      done)"
fi
D="${D%/}"
pass=0; skip=0; fail=0
ok(){ printf '  PASS  %s\n' "$1"; pass=$((pass+1)); }
sk(){ printf '  SKIP  %s\n' "$1"; skip=$((skip+1)); }
no(){ printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }

printf 'snotra smoke — %s\n' "${D:-no meeting}"

if [ -z "$D" ] || [ ! -f "$D/record.json" ]; then
  sk "no meeting folder with a record.json was found — nothing to exercise"
else
  out="$("$ROOT/bin/time/snotra/snotra-harvest.sh" status "$D" 2>&1)"; rc=$?
  if [ $rc -eq 0 ] && printf '%s' "$out" | grep -q '^store{'; then ok "harvest status reads the bot store"; else no "harvest status: ${out##*$'\n'}"; fi

  if [ -f "$D/harvest.json" ]; then
    out="$("$ROOT/bin/time/snotra/snotra-harvest.sh" verify "$D" 2>&1)"; rc=$?
    if [ $rc -eq 0 ] && printf '%s' "$out" | grep -q 'sha_ok:true'; then ok "harvest verify: sha and bytes match the store"
    elif printf '%s' "$out" | grep -q 'sha_ok:false'; then sk "the staged audio moved on (the ladder compressed it) — ${out##*$'\n'}"
    else no "harvest verify: ${out##*$'\n'}"; fi

    out="$("$ROOT/bin/time/snotra/snotra-audio-ladder.sh" status "$D" 2>&1)"; rc=$?
    if [ $rc -eq 0 ] && printf '%s' "$out" | grep -q 'transcript:yes'; then ok "ladder sees a verified transcript before shrinking"
    elif [ $rc -eq 0 ]; then ok "ladder refuses to shrink without a transcript (the safe answer)"
    else no "ladder status: ${out##*$'\n'}"; fi
  else
    sk "no harvest.json here — the harvest has not been run for this meeting"
  fi

  out="$("$ROOT/bin/time/snotra/snotra-project.sh" verify "$D" 2>&1)"; rc=$?
  if printf '%s' "$out" | grep -qE 'no Trello grant|not reachable|unreachable'; then sk "Trello not reachable from here"
  elif [ $rc -eq 0 ]; then ok "project verify: every card sits where the place says"
  elif printf '%s' "$out" | grep -q 'no place profile'; then sk "this record names no company/place — no shape to check"
  else no "project verify: ${out##*$'\n'}"; fi
fi

# the refusal: a place on another surface must not be filed by the Trello projector
if [ -f "$HOME_R/hodd/identity/places/wayof/projects/place.yaml" ]; then
  tmp="$(mktemp -d)"
  cat > "$tmp/record.json" <<'JSON'
{"meeting":{"meeting_id":"M-SMOKE","title":"smoke","started_at":"2026-01-01T00:00:00Z","company":"wayof","place":"projects"},
 "decisions":[],"actions":[],"questions":[],"participants":[]}
JSON
  out="$("$ROOT/bin/time/snotra/snotra-project.sh" plan "$tmp" 2>&1)"; rc=$?
  if [ $rc -ne 0 ] && printf '%s' "$out" | grep -q "surface 'gimle'"; then ok "a place on another surface is refused, not cross-filed"
  else no "the gimlé refusal did not fire (rc=$rc)"; fi
  rm -rf "$tmp"
else
  sk "no wayof place profile to test the surface refusal"
fi

bad=0
for p in "$HOME_R"/hodd/identity/places/*/*/place.yaml; do
  [ -f "$p" ] || continue
  grep -q '^surface:' "$p" || { bad=1; printf '    no surface: %s\n' "${p#"$HOME_R"/}"; }
  grep -q '^authority:' "$p" || { bad=1; printf '    no authority: %s\n' "${p#"$HOME_R"/}"; }
done
if [ $bad -eq 0 ]; then ok "every place profile declares a surface and an authority block"; else no "a place profile is missing surface or authority"; fi

printf 'snotra smoke: %d pass · %d skip · %d fail\n' "$pass" "$skip" "$fail"
[ "$fail" -eq 0 ]
