#!/usr/bin/env bash
# test_trouble.sh — the trouble panel's proof, with no real fault (plan 339.5, 341.4).
#
# A planted home: an old question and an answered one, a wake queue with an old tell, an errand that
# reported done with nothing committed, a repository whose branch took the same commit three times, a
# stand-in systemctl that says housewatch failed, a stale hound heartbeat, and a stand-in notice door.
# What is asserted: each planted fault is RED and each healthy twin is not; a signal turning red is said
# ONCE and a red that stays red is quiet; many at once are one line; Níðhöggr's `commits` verb names a
# loop above the line and is silent at it; an unknown signal is a usage error.
set -u
HERE="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TROUBLE="$HERE/../trouble.sh"
NIDHOGG="$HERE/../../gates/nidhogg.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; ok() { printf 'ok   %s\n' "$1"; }; no() { printf 'FAIL %s\n' "$1"; fail=1; }

H="$T/home"; S="$H/state"; mkdir -p "$H/config" "$H/hodd/data" "$S/eindri-questions" "$S/fleet" "$T/bin"
now="$(date +%s)"; old=$((now - 7200))

# ── the machine's stand-ins ─────────────────────────────────────────────────────────────────────────
cat > "$T/bin/systemctl" <<'X'
#!/usr/bin/env bash
case "$*" in
  *housewatch.service*) printf 'LoadState=loaded\nActiveState=failed\nResult=exit-code\n' ;;
  *housewatch.timer*) printf 'LoadState=loaded\nActiveState=active\nResult=success\n' ;;
esac
X
cat > "$T/bin/herdr" <<'X'
#!/usr/bin/env bash
printf '{"result":{"agents":[]}}\n'
X
cat > "$T/send.sh" <<X
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$T/notices.log"
printf 'notify[1]{decision}:\n  "send"\n'
X
chmod +x "$T/bin/"*
: > "$T/notices.log"
touch -d "@$old" "$T/hound.heartbeat"

# ── the planted faults and their healthy twins ──────────────────────────────────────────────────────
printf 'which road?\n' > "$S/eindri-questions/lost.md";      touch -d "@$old" "$S/eindri-questions/lost.md"
printf 'which road?\n' > "$S/eindri-questions/answered.md";  touch -d "@$old" "$S/eindri-questions/answered.md"
printf 'which road?\n' > "$S/eindri-questions/fresh.md"
printf '{"epoch": %s, "to": "answered", "text": "the north road"}\n' "$((old + 60))" > "$S/fleet/messages.jsonl"
printf '%s\t1\tsignal\trodd-%s\tagent w1 to the arm holder: are you there?\n' "$old" "$old" > "$S/.wake-queue"
printf '%s\t2\tsignal\trodd-%s\tagent w2 to the arm holder: just now\n' "$now" "$now" >> "$S/.wake-queue"

R="$T/repo"; git init -q -b main "$R"; git -C "$R" config user.email t@example.org; git -C "$R" config user.name t
GIT_COMMITTER_DATE="@$old" GIT_AUTHOR_DATE="@$old" git -C "$R" commit -q --allow-empty -m base
git -C "$R" update-ref refs/remotes/origin/main HEAD
git -C "$R" branch eindri/lazy                       # a done that committed nothing
git -C "$R" checkout -q -b eindri/judge
for _ in 1 2 3; do git -C "$R" commit -q --allow-empty -m "judge: change-log for #1"; done
git -C "$R" checkout -q main
git -C "$R" checkout -q -b eindri/calm
for _ in 1 2; do git -C "$R" commit -q --allow-empty -m "judge: change-log for #2"; done
git -C "$R" checkout -q main
printf 'project=%s\nworktree=\nlaunched=%s\nmode=batch\n' "$R" "$((now - 60))" > "$S/lazy.meta"
printf 'working: started\ndone: shipped it all\n' > "$S/lazy.status"

state_of() {  # <json> <signal>
  printf '%s' "$1" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(r["state"] for r in d["rows"] if r["signal"]==sys.argv[1]))' "$2" 2>/dev/null
}
note_of() {
  printf '%s' "$1" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(r["note"] for r in d["rows"] if r["signal"]==sys.argv[1]))' "$2" 2>/dev/null
}
trouble() {  # [VAR=value …] -- <verb and flags…> → $out, $rc
  local extra=(); while [ "${1:-}" != "--" ]; do extra+=("$1"); shift; done; shift
  out="$(env PATH="$T/bin:$PATH" YMIR_HOME="$H" YMIR_STATE_DIR="$S" TROUBLE_HOST=testhost TROUBLE_NO_GARMR=1 \
    TROUBLE_HOUND_HEARTBEAT="$T/hound.heartbeat" TROUBLE_SEND="$T/send.sh" YMIR_RUNTIME_DIR="$T/no-pin" \
    TROUBLE_DISK_PATHS="$T" TROUBLE_REPOS="$R" "${extra[@]}" bash "$TROUBLE" "$@" 2>&1)"; rc=$?
}

# 1 · every planted fault is red, and the reading says why
trouble TROUBLE_DISK_PCT=0 -- read --json
[ "$rc" = 1 ] && ok "a red reading exits 1" || no "a red reading exits 1 (rc=$rc: $out)"
for sig in disk guardian questions tells errands loops; do
  [ "$(state_of "$out" $sig)" = RED ] && ok "$sig is RED when planted" || no "$sig is RED when planted ($(note_of "$out" $sig))"
done
case "$(note_of "$out" questions)" in *lost*) ok "the lost question is named" ;; *) no "the lost question is named" ;; esac
case "$(note_of "$out" questions)" in *" answered ("*|*fresh*) no "an answered or fresh question is not counted ($(note_of "$out" questions))" ;; *) ok "an answered or fresh question is not counted" ;; esac
case "$(note_of "$out" questions)" in "1 unanswered"*) ok "exactly one question waits" ;; *) no "exactly one question waits ($(note_of "$out" questions))" ;; esac
case "$(note_of "$out" tells)" in "1 tell"*) ok "only the old tell waits" ;; *) no "only the old tell waits ($(note_of "$out" tells))" ;; esac
case "$(note_of "$out" errands)" in *"lazy false-done"*) ok "a done with nothing committed since launch is false-done" ;; *) no "false-done named ($(note_of "$out" errands))" ;; esac
case "$(note_of "$out" guardian)" in *"housewatch failed"*heartbeat*) ok "guardian names the failed watch and the old heartbeat" ;; *) no "guardian names both ($(note_of "$out" guardian))" ;; esac
case "$(note_of "$out" loops)" in *"#1"*) ok "the loop above the line is named" ;; *) no "the loop is named ($(note_of "$out" loops))" ;; esac
case "$(note_of "$out" loops)" in *"#2"*) no "two commits are not a loop" ;; *) ok "two commits are not a loop" ;; esac
[ "$(state_of "$out" pin)" = SKIP ] && ok "no pin here is SKIP, never a red" || no "no pin is SKIP"

# 2 · a healthy disk line is quiet
trouble TROUBLE_DISK_PCT=100 -- read --json --only disk
[ "$(state_of "$out" disk)" = ok ] && [ "$rc" = 0 ] && ok "a disk under its line is ok and exits 0" || no "disk under line ($out)"

# 3 · a signal turning red is said once; a red that stays red is quiet
trouble -- check --notify --only questions,tells
[ "$(grep -c -- '--source ward' "$T/notices.log")" = 2 ] && ok "two signals turned red: two notices" || no "two notices ($(cat "$T/notices.log"))"
grep -q -- '--button' "$T/notices.log" && ok "a notice carries its buttons" || no "a notice carries buttons"
grep -q -- 'testhost is in trouble' "$T/notices.log" && ok "a notice names its machine" || no "a notice names its machine"
trouble -- check --notify --only questions,tells
[ "$(grep -c -- '--source ward' "$T/notices.log")" = 2 ] && ok "a red that stays red is not said twice" || no "no second notice ($(wc -l < "$T/notices.log"))"
[ -s "$S/trouble/testhost.json" ] && ok "the reading is kept for the hall" || no "the reading is kept"

# 4 · many at once are one line
rm -f "$S/trouble/testhost.json"; : > "$T/notices.log"
trouble TROUBLE_DISK_PCT=0 -- check --notify --only disk,guardian,questions,tells
[ "$(grep -c -- '--source ward' "$T/notices.log")" = 1 ] && ok "four turned red at once: one notice" || no "one notice ($(cat "$T/notices.log"))"
grep -q '4 signals turned red' "$T/notices.log" && ok "the one line counts them" || no "the one line counts them"

# 5 · no notice without --notify
rm -f "$S/trouble/testhost.json"; : > "$T/notices.log"
trouble -- check --only tells
[ ! -s "$T/notices.log" ] && ok "check without --notify sends nothing" || no "check without --notify sends nothing"

# 6 · Níðhöggr names a commit loop, and only above the line
YMIR_HOME="$H" YMIR_STATE_DIR="$S" bash "$NIDHOGG" commits --repo "$R" >/dev/null 2>&1; nrc=$?
[ "$nrc" = 3 ] && ok "nidhogg commits exits 3 on a loop" || no "nidhogg commits exits 3 (rc=$nrc)"
YMIR_HOME="$H" YMIR_STATE_DIR="$S" bash "$NIDHOGG" commits --repo "$R" --max 3 >/dev/null 2>&1; nrc=$?
[ "$nrc" = 0 ] && ok "three commits at a line of three are not a loop" || no "line of three (rc=$nrc)"

# 7 · an unknown signal is a usage error
trouble -- read --only nonsense
[ "$rc" = 2 ] && ok "an unknown signal exits 2" || no "an unknown signal exits 2 (rc=$rc)"

# 8 · the fleet: a row per machine that owes the panel, each read over its road; a dark one is not asked
TREE="${HERE%/bin/ward/tests}"
cat > "$H/hodd/data/fleet.json" <<J
{"hosts": {"testhost": {"roles": ["dev"]},
           "far": {"roles": ["heart"], "user": "u", "tailnet": "far.example.org"},
           "dim": {"roles": ["forge"], "user": "u", "tailnet": "dim.example.org", "state": "dark"},
           "phone": {"roles": ["hand"], "user": "u", "tailnet": "phone.example.org"}}}
J
cat > "$T/bin/ssh" <<X
#!/usr/bin/env bash
# a stand-in road: the far machine is this one, its pin this tree, its name its own
printf '%s\n' "\$*" >> "$T/ssh.log"
exec env YMIR_RUNTIME_DIR="$TREE" TROUBLE_HOST=far bash -s
X
chmod +x "$T/bin/ssh"; : > "$T/ssh.log"
trouble -- fleet --json
hosts="$(printf '%s' "$out" | python3 -c 'import json,sys; print(" ".join(sorted(r["host"] for r in json.load(sys.stdin))))' 2>/dev/null)"
[ "$hosts" = "dim far testhost" ] && ok "the fleet reads every role that owes the panel, never a hand" || no "fleet hosts ($hosts | $out)"
printf '%s' "$out" | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin) if x["host"]=="far"][0]; sys.exit(0 if r.get("rows") else 1)' 2>/dev/null \
  && ok "the far row answered from the far side" || no "the far row answered ($out)"
grep -q 'u@far.example.org' "$T/ssh.log" && ok "the road is the registry's user@tailnet" || no "the road ($(cat "$T/ssh.log"))"
grep -q 'dim.example.org' "$T/ssh.log" && no "a dark machine is not asked" || ok "a dark machine is not asked"

[ "$fail" = 0 ] && printf 'test_trouble: all passed\n' || printf 'test_trouble: FAILED\n'
exit "$fail"
