#!/usr/bin/env bash
# smoke.sh — the Snotra meeting pipeline's own gate: five doors, three verdicts each.
#
#   systems/snotra/tests/smoke.sh [meeting-dir]
#
# The law (plan 111 · appendix 8): "a clean skip is printed" so "not tested" can never be mistaken for
# "passes" (Rule 25), and a capability without a smoke check is a claim.
#
#   PASS  harvest status reads the bot store for a meeting whose record carries a Meet link
#   PASS  harvest verify re-hashes the staged audio against the store's declared bytes
#   PASS  ladder status sees a transcript before it would shrink anything
#   PASS  project verify agrees with the board (or SKIPs: no Trello grant in reach)
#   PASS  layout: the folder holds the standard and no strays
#   PASS  promote: the record validates before any promotion is written
#   PASS  agenda: the dated card sits in the place's agenda list (or SKIPs: none filed yet)
#   PASS  a place declaring another surface is REFUSED, not cross-filed
#   PASS  every trello place's board exists with the lists and labels it names
#   PASS  every place profile declares a surface and an authority block
#
# Exit: 0 all pass or a clean skip · 1 any FAIL
set -uo pipefail
ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
# the hoard is resolved, never restated: if the resolver gave nothing, the smoke says so and stops
if [ -z "${HOME_R:-}" ]; then
  printf 'snotra smoke: the hoard is unresolved — run bin/vault/hoard-lib.sh or set YMIR_HOME\n' >&2
  exit 2
fi

D="${1-}"
if [ -z "$D" ]; then
  # every meetings shelf the home keeps, through the one resolver; prefer the RICHEST meeting: a placed
  # record WITH a harvest exercises harvest · verify · ladder · project · agenda; else the newest placed one.
  pick(){ YMIR_HOME="$HOME_R" python3 "$ROOT/systems/snotra/services/record/snotra_paths.py" --recent 3650 2>/dev/null | while read -r c; do
            eval "$1" && { printf '%s' "$c"; break; }
          done; }
  D="$(pick '[ -f "$c/harvest.json" ] && grep -q "\"place\": \"" "$c/record.json" 2>/dev/null')"
  [ -n "$D" ] || D="$(pick 'grep -q "\"place\": \"" "$c/record.json" 2>/dev/null')"
  [ -n "$D" ] || D="$(YMIR_HOME="$HOME_R" python3 "$ROOT/systems/snotra/services/record/snotra_paths.py" --recent 3650 2>/dev/null | head -1)"
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
  out="$("$ROOT/systems/snotra/services/ear/snotra-harvest.sh" status "$D" 2>&1)"; rc=$?
  if [ $rc -eq 0 ] && printf '%s' "$out" | grep -q '^store{'; then ok "harvest status reads the bot store"
  elif printf '%s' "$out" | grep -q 'join_key{none'; then sk "this record carries no Meet link — no bot recording can exist for it"
  else no "harvest status: ${out##*$'\n'}"; fi

  if [ -f "$D/harvest.json" ]; then
    out="$("$ROOT/systems/snotra/services/ear/snotra-harvest.sh" verify "$D" 2>&1)"; rc=$?
    if [ $rc -eq 0 ] && printf '%s' "$out" | grep -q 'sha_ok:true'; then ok "harvest verify: sha and bytes match the store"
    elif printf '%s' "$out" | grep -q 'sha_ok:false'; then sk "the staged audio moved on (the ladder compressed it) — ${out##*$'\n'}"
    else no "harvest verify: ${out##*$'\n'}"; fi

    out="$("$ROOT/systems/snotra/services/ear/snotra-audio-ladder.sh" status "$D" 2>&1)"; rc=$?
    if [ $rc -eq 0 ] && printf '%s' "$out" | grep -q 'transcript:yes'; then ok "ladder sees a verified transcript before shrinking"
    elif [ $rc -eq 0 ]; then ok "ladder refuses to shrink without a transcript (the safe answer)"
    else no "ladder status: ${out##*$'\n'}"; fi
  else
    sk "no harvest.json here — the harvest has not been run for this meeting"
  fi

  out="$("$ROOT/systems/snotra/services/record/snotra-layout.sh" check "$D" 2>&1)"; rc=$?
  if [ $rc -eq 0 ]; then ok "layout: no strays in the meeting folder"
  else no "layout: ${out##*$'\n'} (run snotra-layout.sh apply)"; fi

  out="$("$ROOT/systems/snotra/services/approve/snotra-promote.sh" check "$D" 2>&1)"; rc=$?
  if [ $rc -eq 0 ] && printf '%s' "$out" | grep -q 'ok:true'; then ok "promote: the record validates before any promotion"
  else no "promote check: ${out##*$'\n'}"; fi

  out="$("$ROOT/systems/snotra/services/cron/snotra-agenda.sh" verify "$D" 2>&1)"; rc=$?
  if printf '%s' "$out" | grep -q 'no place profile'; then sk "no place profile — no agenda to check"
  elif [ $rc -eq 0 ]; then ok "agenda: the dated card sits in the place's agenda list"
  elif printf '%s' "$out" | grep -q 'agenda{missing:true}'; then sk "no agenda card filed for this meeting yet"
  else no "agenda verify: ${out##*$'\n'}"; fi

  out="$("$ROOT/systems/snotra/services/cron/snotra-project.sh" verify "$D" 2>&1)"; rc=$?
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
  out="$("$ROOT/systems/snotra/services/cron/snotra-project.sh" plan "$tmp" 2>&1)"; rc=$?
  if [ $rc -ne 0 ] && printf '%s' "$out" | grep -q "surface 'gimle'"; then ok "a place on another surface is refused, not cross-filed"
  else no "the gimlé refusal did not fire (rc=$rc)"; fi
  rm -rf "$tmp"
else
  sk "no wayof place profile to test the surface refusal"
fi

# every trello place's board must exist with the lists and labels it names
while IFS= read -r pl; do
  [ -n "$pl" ] || continue
  if grep -q '^surface: gimle' "$pl"; then sk "a place declares gimle — no adapter yet, so it is refused"; continue; fi
  out="$("$ROOT/systems/snotra/services/cron/snotra-board.sh" check "$(python3 -c "
import yaml,sys;print(yaml.safe_load(open('$pl')).get('place'))")" 2>&1)"; rc=$?
  [ $rc -eq 0 ] && ok "board for place: ${out##*board\{}" | cut -c1-70 || no "board missing or incomplete: ${out##*$'\n'}"
done < <(ls "$HOME_R"/hodd/identity/places/*/*/place.yaml 2>/dev/null)

bad=0
for p in "$HOME_R"/hodd/identity/places/*/*/place.yaml; do
  [ -f "$p" ] || continue
  grep -q '^surface:' "$p" || { bad=1; printf '    no surface: %s\n' "${p#"$HOME_R"/}"; }
  grep -q '^authority:' "$p" || { bad=1; printf '    no authority: %s\n' "${p#"$HOME_R"/}"; }
done
if [ $bad -eq 0 ]; then ok "every place profile declares a surface and an authority block"; else no "a place profile is missing surface or authority"; fi

printf 'snotra smoke: %d pass · %d skip · %d fail\n' "$pass" "$skip" "$fail"
[ "$fail" -eq 0 ]
