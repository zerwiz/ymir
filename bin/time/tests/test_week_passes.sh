#!/usr/bin/env bash
# test_week_passes.sh — the three weekly passes keep their four promises, on every path.
#
# What is proved here, once per pass and per kind of week:
#
#   1. a CLEAN week writes its row, carves a no-op Rune, and sends NOTHING
#   2. a DIRTY week writes its row, carves a fault Rune, and sends EXACTLY ONE line
#   3. the row is APPENDED, never rewritten — the first week's line is byte-identical after the second
#   4. the notice carries the ISO-WEEK key, so a second run in the same week is one message, not two
#   5. a door that cannot answer writes a row with `value: null` and exits 2 — never a zero
#   6. the three cron rows are declared, in the ruled order and shape, and the migration that seats
#      them on an existing home is idempotent
#
# Usage: test_week_passes.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
MAIL="$ROOT/bin/time/nornir-job-week-mail.sh"
PIN="$ROOT/bin/time/nornir-job-week-pin.sh"
TUNNELS="$ROOT/bin/time/nornir-job-week-tunnels.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; return 0; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/config" "$H/hodd/state" "$H/hodd/memory" "$T/bin" "$T/state"

# The notice door, recorded instead of sent: the test proves the CALL (one line, one week key), never
# the far end. Real sends are the door's own business and its own tests.
cat >"$T/bin/notify" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${NOTICE_LOG:?}"
exit 0
EOS
chmod +x "$T/bin/notify"

export YMIR_HOME="$H"
export YMIR_WEEK_NOTIFY="$T/bin/notify"
export NOTICE_LOG="$T/notices.log"
export BROKK_RUNES_FILE="$H/hodd/memory/runes_audit.md"
export BROKK_RUNES_LOCK="$T/state/runes.lock"
: >"$NOTICE_LOG"

count_lines() { # <file> -> how many non-empty lines, and 0 rather than the shell's own error
  local n
  n=$(grep -c . "$1" 2>/dev/null)
  printf '%s' "${n:-0}"
}
rows() { count_lines "$H/hodd/state/$1-week.jsonl"; }
count_lines_matching() { # <pattern> <file> -> how many lines carry it, 0 when the file is absent
  local n
  n=$(grep -c -- "$1" "$2" 2>/dev/null)
  printf '%s' "${n:-0}"
}
first_row() { head -n 1 "$H/hodd/state/$1-week.jsonl" 2>/dev/null; }
last_value() { # <name> -> the last row's `value` as JSON text
  python3 - "$H/hodd/state/$1-week.jsonl" <<'PY'
import json, sys
last = None
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.strip()
    if line:
        last = json.loads(line)
print(json.dumps(last["value"]) if last else "")
PY
}
last_detail() {
  python3 - "$H/hodd/state/$1-week.jsonl" <<'PY'
import json, sys
last = None
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.strip()
    if line:
        last = json.loads(line)
print(last["detail"] if last else "")
PY
}
row_keys() { # <name> -> the keys of the last row, sorted, comma-joined
  python3 - "$H/hodd/state/$1-week.jsonl" <<'PY'
import json, sys
last = None
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.strip()
    if line:
        last = json.loads(line)
print(",".join(sorted(last)) if last else "")
PY
}
notices() { count_lines "$NOTICE_LOG"; }
runes_for() { count_lines_matching "\"week\.$1\." "$BROKK_RUNES_FILE"; }
notice_keys() { sed -n 's/.*--key \([^ ]*\).*/\1/p' "$NOTICE_LOG" 2>/dev/null; }

printf 'test_week_passes\n'

# ══ the mail balance ═════════════════════════════════════════════════════════════
NOW="2026-11-17T09:00:00Z"
store="$T/mail-clean.jsonl"
cat >"$store" <<'EOS'
{"id":"m1","thread_key":"t1","direction":"in","received_at":"2026-11-15T10:00:00Z","from":{"name":"Fresh","email":"fresh@example.invalid"},"to":[{"email":"owner@example.invalid"}],"subject":"two days old","classification":"request"}
{"id":"m2","thread_key":"t2","direction":"in","received_at":"2026-10-01T10:00:00Z","from":{"name":"Quiet","email":"quiet@example.invalid"},"to":[{"email":"owner@example.invalid"}],"subject":"an old answered thread","classification":"request","handled_at":"2026-10-02T10:00:00Z"}
EOS
out=$(bash "$MAIL" --now "$NOW" --store "$store" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "mail: a clean week exits 0" || bad "mail: a clean week exits 0" "$out ($rc)"
[ "$(rows mail)" = 1 ] && ok "mail: the clean week writes ONE row" || bad "mail: the clean week writes ONE row" "$(rows mail)"
[ "$(last_value mail)" = 0 ] && ok "mail: the clean row carries value 0" || bad "mail: the clean row carries value 0" "$(last_value mail)"
[ "$(row_keys mail)" = "at,detail,value" ] && ok "mail: the row is exactly {at,value,detail}" || bad "mail: the row is exactly {at,value,detail}" "$(row_keys mail)"
[ "$(runes_for mail)" -ge 1 ] && ok "mail: a clean week carves a no-op Rune" || bad "mail: a clean week carves a no-op Rune"
[ "$(notices)" = 0 ] && ok "mail: a clean week sends NOTHING" || bad "mail: a clean week sends NOTHING" "$(cat "$NOTICE_LOG")"

clean_line="$(first_row mail)"
store="$T/mail-dirty.jsonl"
cat >"$store" <<'EOS'
{"id":"d1","thread_key":"t3","direction":"in","received_at":"2026-10-01T10:00:00Z","from":{"name":"Waiting","email":"waiting@example.invalid"},"to":[{"email":"owner@example.invalid"}],"subject":"still nothing","classification":"request"}
EOS
out=$(bash "$MAIL" --now "$NOW" --store "$store" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "mail: a dirty week still exits 0 (it measured)" || bad "mail: a dirty week still exits 0" "$out ($rc)"
[ "$(rows mail)" = 2 ] && ok "mail: the dirty week APPENDS a second row" || bad "mail: the dirty week APPENDS a second row" "$(rows mail)"
[ "$(first_row mail)" = "$clean_line" ] && ok "mail: the first row is never rewritten" || bad "mail: the first row is never rewritten"
[ "$(last_value mail)" = 1 ] && ok "mail: the dirty row counts the conversation (1)" || bad "mail: the dirty row counts the conversation (1)" "$(last_value mail)"
[ "$(notices)" = 1 ] && ok "mail: a dirty week sends EXACTLY one line" || bad "mail: a dirty week sends EXACTLY one line" "$(notices)"
case "$(tail -n 1 "$NOTICE_LOG")" in
  *"1 conversation(s) whose last word is theirs"*) ok "mail: the line says whose word is last" ;;
  *) bad "mail: the line says whose word is last" "$(tail -n 1 "$NOTICE_LOG")" ;;
esac
case "$(notice_keys | tail -n 1)" in
  week-mail-2026-W47) ok "mail: the line is keyed to the ISO week" ;;
  *) bad "mail: the line is keyed to the ISO week" "$(notice_keys | tail -n 1)" ;;
esac
bash "$MAIL" --now "$NOW" --store "$store" >/dev/null 2>&1
[ "$(rows mail)" = 3 ] && ok "mail: a second run in the same week appends again" || bad "mail: a second run appends again" "$(rows mail)"
[ "$(notice_keys | sort -u | wc -l | tr -d ' ')" = 1 ] && ok "mail: one week, one key — so one message" || bad "mail: one week, one key" "$(notice_keys)"

# ══ the pin's distance ═══════════════════════════════════════════════════════════
pin_clean="$T/pin-clean"; pin_behind="$T/pin-behind"
git init -q --bare "$T/origin.git"
git init -q "$T/seed"; ( cd "$T/seed" \
  && git config user.email t@example.invalid && git config user.name t \
  && printf 'a\n' > a.txt && git add a.txt && git commit -qm one && git branch -M main \
  && printf 'b\n' >> a.txt && git commit -qam two \
  && printf 'c\n' >> a.txt && git commit -qam three \
  && git remote add origin "$T/origin.git" && git push -q origin main ) >/dev/null 2>&1
git clone -q -b main "$T/origin.git" "$pin_clean" 2>/dev/null
git clone -q -b main "$T/origin.git" "$pin_behind" 2>/dev/null
( cd "$pin_behind" && git config user.email t@example.invalid && git config user.name t && git reset -q --hard HEAD~2 )

out=$(YMIR_RUNTIME_DIR="$pin_clean" bash "$PIN" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "pin: a pin at main exits 0" || bad "pin: a pin at main exits 0" "$out ($rc)"
[ "$(last_value pin)" = 0 ] && ok "pin: a clean week records distance 0" || bad "pin: a clean week records distance 0" "$(last_value pin)"
[ "$(rows pin)" = 1 ] && ok "pin: the clean week writes ONE row" || bad "pin: the clean week writes ONE row" "$(rows pin)"

before_dirty="$(notices)"
out=$(YMIR_RUNTIME_DIR="$pin_behind" bash "$PIN" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "pin: a behind pin still exits 0 (it measured)" || bad "pin: a behind pin still exits 0" "$out ($rc)"
[ "$(last_value pin)" = 2 ] && ok "pin: the distance is the number of commits (2)" || bad "pin: the distance is 2" "$(last_value pin)"
[ "$(rows pin)" = 2 ] && ok "pin: the dirty week appends its row" || bad "pin: the dirty week appends its row" "$(rows pin)"
[ "$(( $(notices) - before_dirty ))" = 1 ] && ok "pin: a behind pin sends EXACTLY one line" || bad "pin: a behind pin sends EXACTLY one line" "$(tail -n 1 "$NOTICE_LOG")"
case "$(last_detail pin)" in
  *"2 commit(s) behind main"*) ok "pin: the row says how far behind" ;;
  *) bad "pin: the row says how far behind" "$(last_detail pin)" ;;
esac
case "$(runes_for pin)" in 0) bad "pin: a beaconed week carves a fault Rune" ;; *) ok "pin: the weeks carve their Runes" ;; esac

out=$(YMIR_RUNTIME_DIR="$T/no-such-pin" bash "$PIN" 2>&1); rc=$?
[ "$(last_value pin)" = "null" ] && ok "pin: a missing pin records null, never 0" || bad "pin: a missing pin records null, never 0" "$(last_value pin)"
case "$(last_detail pin)" in *absent*) ok "pin: the row names what it could not measure" ;; *) bad "pin: the row names what it could not measure" "$(last_detail pin)" ;; esac

# ══ the tunnels' uptime ═════════════════════════════════════════════════════════
clean="$T/tunnels-clean.txt"
cat >"$clean" <<'EOS'
SURFACE        HOSTNAME                         ROAD     DNS     HTTP     STATE WHY
gate           auth.example.invalid             yes   yes   200    ok
board          board.example.invalid            yes   yes   302    ok


2 up · 0 failing
EOS
before_clean="$(notices)"
out=$(bash "$TUNNELS" --from "$clean" --rc 0 2>&1); rc=$?
[ "$rc" = 0 ] && ok "tunnels: a clean week exits 0" || bad "tunnels: a clean week exits 0" "$out ($rc)"
[ "$(last_value tunnels)" = 2 ] && ok "tunnels: the row records the surfaces UP (2)" || bad "tunnels: the row records the surfaces up (2)" "$(last_value tunnels)"
[ "$(( $(notices) - before_clean ))" = 0 ] && ok "tunnels: a clean week sends NOTHING" || bad "tunnels: a clean week sends NOTHING"

dirty="$T/tunnels-dirty.txt"
cat >"$dirty" <<'EOS'
SURFACE        HOSTNAME                         ROAD     DNS     HTTP     STATE WHY
gate           auth.example.invalid             yes   yes   200    ok
board          board.example.invalid            yes   no    fail   FAIL dns does not resolve;
documents      affine.example.invalid           yes   yes   404    ok    api surface (no root page)
booking        book.example.invalid             no    no    fail   FAIL no tunnel names it;


2 up · 2 failing
EOS
before_dirty="$(notices)"
out=$(bash "$TUNNELS" --from "$dirty" --rc 1 2>&1); rc=$?
[ "$rc" = 0 ] && ok "tunnels: a dirty week still exits 0 (it measured)" || bad "tunnels: a dirty week still exits 0" "$out ($rc)"
[ "$(last_value tunnels)" = 2 ] && ok "tunnels: up count is recorded on a dirty week too" || bad "tunnels: up count on a dirty week" "$(last_value tunnels)"
[ "$(( $(notices) - before_dirty ))" = 1 ] && ok "tunnels: a dirty week sends EXACTLY one line" || bad "tunnels: a dirty week sends EXACTLY one line" "$(tail -n 1 "$NOTICE_LOG")"
case "$(last_detail tunnels)" in
  *"2 up · 2 failing (board, booking)"*) ok "tunnels: the row names every failing surface" ;;
  *) bad "tunnels: the row names every failing surface" "$(last_detail tunnels)" ;;
esac

silent="$T/tunnels-silent.txt"
printf 'SURFACE HOSTNAME ROAD DNS HTTP STATE WHY\n' >"$silent"
out=$(bash "$TUNNELS" --from "$silent" --rc 0 2>&1); rc=$?
[ "$rc" = 2 ] && ok "tunnels: a door with no summary is UNMEASURED (exit 2)" || bad "tunnels: a door with no summary is UNMEASURED" "$out ($rc)"
[ "$(last_value tunnels)" = "null" ] && ok "tunnels: unmeasured records null, never 0" || bad "tunnels: unmeasured records null" "$(last_value tunnels)"
[ "$(row_keys tunnels)" = "at,detail,value" ] && ok "tunnels: every row keeps the three keys" || bad "tunnels: every row keeps the three keys" "$(row_keys tunnels)"

# ══ the schedule, and the migration that seats it ════════════════════════════════
declared=$(grep -cE '^@heart Mon 0(8:4|8:5|9:0)[05] bin/time/nornir-job-week-(tunnels|mail|pin)\.sh$' "$ROOT/config/cron.yaml.example" 2>/dev/null)
[ "$declared" = 3 ] && ok "cron: the three weekly rows are declared, in the ruled shape" || bad "cron: three weekly rows declared" "found $declared"
order=$(grep -oE 'week-(tunnels|mail|pin)' "$ROOT/config/cron.yaml.example" | tr '\n' ' ')
case "$order" in
  "week-tunnels week-mail week-pin ") ok "cron: 08:40 tunnels · 08:50 mail · 09:00 pin" ;;
  *) bad "cron: the ruled order" "$order" ;;
esac

mig="$ROOT/.agents/migrations/0025-weekly-passes.sh"
mhome="$T/mig-home"; mkdir -p "$mhome/config"
printf '@heart 07:00 bin/time/nornir-job-daily-briefing.sh\n' >"$mhome/config/cron.yaml"
YMIR_HOME="$mhome" bash "$mig" >/dev/null 2>&1
once=$(grep -c 'week-' "$mhome/config/cron.yaml" 2>/dev/null)
YMIR_HOME="$mhome" bash "$mig" >/dev/null 2>&1
twice=$(grep -c 'week-' "$mhome/config/cron.yaml" 2>/dev/null)
[ "$once" = 3 ] && [ "$twice" = 3 ] && ok "migration: seats three rows once, and is idempotent" || bad "migration: seats three rows once, and is idempotent" "once=$once twice=$twice"
[ "$(grep -c '^@heart 07:00' "$mhome/config/cron.yaml")" = 1 ] && ok "migration: the operator's own rows are untouched" || bad "migration: the operator's own rows are untouched"

printf '\n'
if [ "$fail" = 0 ]; then printf 'test_week_passes: PASS (%s assertions)\n' "$pass"; exit 0; fi
printf 'test_week_passes: %s FAILED of %s\n' "$fail" "$((pass + fail))" >&2
exit 1
