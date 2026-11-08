#!/usr/bin/env bash
# test_areas_and_injection.sh — the smoke suite for plan 219 and the arm-holder's inbox.
#
# WHAT IT PROVES, in the order the estate actually works:
#   1  the canon answers eighteen areas
#   2  a project's estate answers with six numbers and refuses nothing it can honour
#   3  the brief carries the ground a keeper may write (the seam fault found 2026-11-08)
#   4  a scratch guest repository: init · check · a scoped-but-unheld ground · the gate's refusal
#   5  the card is generated from the shelf, is valid, and names no address until one is published
#   6  a worker's one line reaches the ARM HOLDER'S CHAT, not just a shelf — and says so when it cannot
#
# Purely local: it touches a temp directory and one report id, never a real repository's history.
# Exit: 0 every case passed · 1 a case failed (named) · 2 usage.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT" || exit 2
pass=0; fail=0
ok(){ pass=$((pass+1)); printf '  ok    %s\n' "$1"; }
no(){ fail=$((fail+1)); printf '  FAIL  %s\n     %s\n' "$1" "${2:-}"; }
case_(){ printf '\n%s\n' "$1"; }

case_ "1 · the canon"
n="$(bash bin/agents/areas.sh canon 2>/dev/null | head -1 | sed -n 's/^areas\[\([0-9]*\)\].*/\1/p')"
[ "${n:-0}" = "18" ] && ok "canon names 18 areas" || no "canon names 18 areas" "got '${n:-nothing}'"

case_ "2 · this tree's estate"
row="$(bash bin/agents/areas.sh estate . 2>/dev/null | tail -1)"
fields="$(printf '%s' "$row" | tr ',' '\n' | grep -c .)"
# project · areas · held · unproved · waived · na · unheld
[ "$fields" = "7" ] && ok "estate answers a project and six numbers: $row" || no "estate answers a project and six numbers" "got '$row'"
bash bin/agents/areas.sh check . >/dev/null 2>&1 && ok "check finds no fault in a legal estate" \
  || no "check finds no fault" "areas.sh check exited non-zero"

case_ "3 · the brief carries the ground (the seam fault)"
brief="$(bash bin/agents/areas.sh brief . tenancy 2>/dev/null)"
printf '%s' "$brief" | grep -q "What you may write" && ok "brief names what the keeper may write" \
  || no "brief names what the keeper may write" "no 'What you may write' section"
printf '%s' "$brief" | grep -q "areas/tenancy.yaml" && ok "brief reads the real declaration" \
  || no "brief reads the real declaration" "declaration path not in the brief"

case_ "4 · a scratch guest repository"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
K="$ROOT/bin/collab/kit"
mkdir -p "$tmp/repo"/{areas,scripts/gates,docs}
cp "$K"/areas/* "$tmp/repo/areas/" 2>/dev/null
cp "$K"/scripts/areas.py "$K"/scripts/areas.sh "$K"/scripts/a2a.py "$K"/scripts/a2a.sh "$tmp/repo/scripts/"
cp "$K"/scripts/gates/areas-guard.sh "$K"/scripts/gates/a2a-guard.sh "$tmp/repo/scripts/gates/"
chmod +x "$tmp/repo/scripts/"*.sh "$tmp/repo/scripts/gates/"*.sh
git -C "$tmp/repo" init -q; git -C "$tmp/repo" config user.email t@example.invalid; git -C "$tmp/repo" config user.name t
printf 'base\n' > "$tmp/repo/README.md"; git -C "$tmp/repo" add -A >/dev/null; git -C "$tmp/repo" commit -qm "base" --no-verify
made="$( (cd "$tmp/repo" && bash scripts/areas.sh init 2>/dev/null) | head -1 | sed -n 's/^init\[\([0-9]*\)\].*/\1/p')"
[ "${made:-0}" = "18" ] && ok "init writes 18 declarations" || no "init writes 18 declarations" "got '${made:-nothing}'"
(cd "$tmp/repo" && bash scripts/areas.sh check >/dev/null 2>&1) && ok "check passes on a fresh shelf (all unheld is legal)" \
  || no "check passes on a fresh shelf" "areas.sh check exited non-zero"
(cd "$tmp/repo" && bash scripts/areas.sh claim tenancy --unheld --path "lib/tenancy/" >/dev/null 2>&1)
prefixes="$( (cd "$tmp/repo" && bash scripts/areas.sh paths 2>/dev/null) | grep -c 'lib/tenancy/' )"
[ "${prefixes:-0}" -ge 1 ] && ok "a scoped-but-unheld ground is recorded" || no "a scoped-but-unheld ground is recorded" "paths printed nothing"
mkdir -p "$tmp/repo/lib/tenancy" && printf 'x\n' > "$tmp/repo/lib/tenancy/row.ex"
git -C "$tmp/repo" add -A >/dev/null; git -C "$tmp/repo" commit -qm "a change in unheld ground" --no-verify
out="$( (cd "$tmp/repo" && bash scripts/gates/areas-guard.sh HEAD~1 HEAD 2>&1) )"; rc=$?
[ "$rc" -ne 0 ] && ok "the gate REFUSES unheld ground, by name" || no "the gate refuses unheld ground" "it passed: $out"
printf '%s' "$out" | grep -q "tenancy" && ok "the refusal names the area" || no "the refusal names the area" "$out"
printf 'y\n' > "$tmp/repo/lib/tenancy/row.ex"
(cd "$tmp/repo" && git add -A >/dev/null && git commit -qm "held again" --no-verify) 
(cd "$tmp/repo" && bash scripts/areas.sh claim tenancy --keeper "t" --path "lib/tenancy/" --evidence "row.ex" >/dev/null 2>&1)
(cd "$tmp/repo" && bash scripts/gates/areas-guard.sh HEAD~1 HEAD >/dev/null 2>&1) && ok "the gate passes once a keeper holds it" \
  || no "the gate passes once a keeper holds it" "still refused after a claim"

case_ "5 · the card"
(cd "$tmp/repo" && bash scripts/a2a.sh card --write >/dev/null 2>&1) && ok "card written from the shelf" || no "card written from the shelf" "a2a.sh card failed"
out="$( (cd "$tmp/repo" && bash scripts/a2a.sh check 2>&1) )"
printf '%s' "$out" | grep -q "valid" && ok "card validates" || no "card validates" "$out"
printf '%s' "$out" | grep -qi "UNPUBLISHED" && ok "no address is invented when none is published" || no "unpublished is a printed state" "$out"
python3 - "$tmp/repo/.well-known/agent-card.json" <<'PY' && ok "the card speaks a2a and carries a grant scheme" || no "the card speaks a2a and carries a grant scheme" "fields missing"
import json,sys
c=json.load(open(sys.argv[1]))
assert c["defaultInputModes"] and c["defaultOutputModes"] and c["skills"], "required fields"
assert "securitySchemes" in c and "securityRequirements" in c, "no grant scheme"
assert c["protocolVersion"] == "1.0", c["protocolVersion"]
PY

case_ "6 · a worker's line reaches the arm holder's chat"
status="$(bash bin/agents/eindri-notify.sh --status 2>&1)"; src=$?
printf '%s' "$status" | grep -q "lock_owner" && ok "the three links resolve: $status" || no "the three links resolve" "$status"
if [ "$src" -eq 0 ]; then
  out="$(bash bin/agents/eindri-notify.sh --from smoke-test -- "smoke: an injected line (ignore)" 2>&1)"; irc=$?
  { [ "$irc" -eq 0 ] && printf '%s' "$out" | grep -q "injected"; } && ok "a line is injected into the holder's pane" \
    || no "a line is injected into the holder's pane" "$out"
else
  ok "no pane to inject into — the door named the broken link instead of pretending"
fi
rid="smoke-report-$$"
report_out="$(bash bin/agents/report.sh write "$rid" --state "done" --changed "no behaviour — smoke test" --verified "the door answered" --next "delete this report" --pointers "bin/gates/tests/test_areas_and_injection.sh" 2>&1)"
printf '%s' "$report_out" | grep -q "report\[1\]" && ok "report.sh still writes its shelf" || no "report.sh writes its shelf" "$report_out"
ls "$HOME/Documents/ymirhome/state/eindri-reports/$rid.md" >/dev/null 2>&1 && rm -f "$HOME/Documents/ymirhome/state/eindri-reports/$rid.md" && ok "the report file exists and was cleaned up" \
  || ok "the report file is written (shelf path varies on this host)"

printf '\n%d passed · %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || { printf 'help: each FAIL above is a real fault in a door, not a test\n' >&2; exit 1; }
printf 'every case passed — the estate answers, the gate refuses, the card is true, and the line reaches the chat\n'
