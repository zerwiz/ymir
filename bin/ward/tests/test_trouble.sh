#!/usr/bin/env bash
# test_trouble.sh — the trouble panel's proof, with no real fault (plan 339.5, 341.4).
#
# A planted home: an old question and an answered one, a wake queue with an old tell, an errand that
# reported done with nothing committed, a repository whose branch took the same commit three times, a
# stand-in systemctl that says housewatch failed, a stale hound heartbeat, and a stand-in notice door.
# Also planted (rework of PR #874): a Hyprland config error, a pin behind main past its line and hours, an
# errand branch holding an old commit on no remote, a dead errand and a stalled one.
# What is asserted: each planted fault is RED and each healthy twin is not; a signal turning red is said
# ONCE and a red that stays red is quiet; a failed or duplicate notice is tried again until one is sent;
# red, green and red again inside one hour is news twice; many at once are one line; Níðhöggr's `commits`
# verb names a loop above the line and is silent at it; an unknown signal is a usage error; the fleet asks
# every machine in the registry, a hand included.
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
printf '{"result":{"agents":[{"pane_id":"w8:p8","agent_status":"idle"},{"pane_id":"w7:p7","agent_status":"working"}]}}\n'
X
# a stand-in Hyprland: up, classic dialect, and whatever $T/hypr.errors holds as its config errors
cat > "$T/bin/hyprctl" <<X
#!/usr/bin/env bash
case "\$1" in
  monitors) printf '[]\n' ;;
  eval) printf 'unknown request\n'; exit 1 ;;
  configerrors) cat "$T/hypr.errors" 2>/dev/null ;;
esac
X
cat > "$T/send.sh" <<X
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$T/notices.log"
d="\$(cat "$T/send.decision" 2>/dev/null || echo send)"
printf 'notify[1]{decision,source}:\n  "%s","ward"\n' "\$d"
exit "\$(cat "$T/send.rc" 2>/dev/null || echo 0)"
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
# an errand branch holding a two-hour-old commit on no remote; eindri/judge's fresh commits are its twin
git -C "$R" checkout -q -b eindri/stranded
GIT_COMMITTER_DATE="@$old" GIT_AUTHOR_DATE="@$old" git -C "$R" commit -q --allow-empty -m "stranded work"
git -C "$R" checkout -q main
# a dead errand (its pane holds no agent), a stalled one (idle agent, silent two hours), a busy twin
printf 'project=%s\nseat_pane=w9:p9\nlaunched=%s\n' "$R" "$old" > "$S/ghost.meta"
printf 'working: on it\n' > "$S/ghost.status"
printf 'project=%s\nseat_pane=w8:p8\nlaunched=%s\n' "$R" "$old" > "$S/sleepy.meta"
printf 'working: on it\n' > "$S/sleepy.status"; touch -d "@$old" "$S/sleepy.status"
printf 'project=%s\nseat_pane=w7:p7\nlaunched=%s\n' "$R" "$old" > "$S/busy.meta"
printf 'working: on it\n' > "$S/busy.status"; touch -d "@$old" "$S/busy.status"
# Hyprland reports a config error in a named file and line
printf '/home/u/.config/hypr/hyprland.conf:12: config option <general:bogus> does not exist\n' > "$T/hypr.errors"
# a pin: a clone of the repo sitting on base, while origin/main has moved 3 commits on, bad for 3 h
P="$T/pin"; git clone -q "$R" "$P"; git -C "$P" checkout -q --detach "$(git -C "$R" rev-parse main)"
git -C "$R" checkout -q -b pinmove main
for i in 1 2 3; do git -C "$R" commit -q --allow-empty -m "main moves $i"; done
git -C "$R" checkout -q main
git -C "$P" update-ref refs/remotes/origin/main "$(git -C "$R" rev-parse pinmove)" 2>/dev/null \
  || { git -C "$P" fetch -q origin pinmove && git -C "$P" update-ref refs/remotes/origin/main FETCH_HEAD; }

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
    TROUBLE_DISK_PATHS="$T" TROUBLE_REPOS="$R" YMIR_HYPRCTL="$T/bin/hyprctl" HYPRLAND_INSTANCE_SIGNATURE=test \
    "${extra[@]}" bash "$TROUBLE" "$@" 2>&1)"; rc=$?
}

# 1 · every planted fault is red, and the reading says why
trouble TROUBLE_DISK_PCT=0 -- read --json
[ "$rc" = 1 ] && ok "a red reading exits 1" || no "a red reading exits 1 (rc=$rc: $out)"
for sig in disk guardian questions tells errands loops hyprland unpushed; do
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
case "$(note_of "$out" hyprland)" in *hyprland.conf:12*) ok "the Hyprland error names its file and line" ;; *) no "hyprland names file:line ($(note_of "$out" hyprland))" ;; esac
case "$(note_of "$out" unpushed)" in *eindri/stranded*) ok "the stranded branch is named" ;; *) no "stranded named ($(note_of "$out" unpushed))" ;; esac
case "$(note_of "$out" unpushed)" in *eindri/judge*) no "fresh local commits are not stranded" ;; *) ok "fresh local commits are not stranded" ;; esac
case "$(note_of "$out" errands)" in *"ghost dead"*) ok "an errand whose pane holds no agent is dead" ;; *) no "dead named ($(note_of "$out" errands))" ;; esac
case "$(note_of "$out" errands)" in *"sleepy stalled"*) ok "an idle agent silent past the line is stalled" ;; *) no "stalled named ($(note_of "$out" errands))" ;; esac
case "$(note_of "$out" errands)" in *busy*) no "a working agent is neither dead nor stalled" ;; *) ok "a working agent is neither dead nor stalled" ;; esac

# 1b · the pin: behind past its line for longer than its hours is red; inside the hours it is not
mkdir -p "$S/trouble"; printf '{"pin": %s}' "$((now - 3 * 3600))" > "$S/trouble/testhost.since.json"
trouble YMIR_RUNTIME_DIR="$P" TROUBLE_PIN_BEHIND=1 TROUBLE_PIN_HOURS=2 -- read --json --only pin
[ "$(state_of "$out" pin)" = RED ] && ok "a pin 3 behind for 3 h is RED" || no "pin RED ($(note_of "$out" pin))"
case "$(note_of "$out" pin)" in *"3 commits behind"*) ok "the pin says how far behind" ;; *) no "pin count ($(note_of "$out" pin))" ;; esac
trouble YMIR_RUNTIME_DIR="$P" TROUBLE_PIN_BEHIND=5 -- read --json --only pin
[ "$(state_of "$out" pin)" = ok ] && ok "a pin inside its line is ok" || no "pin under line ($(note_of "$out" pin))"
trouble YMIR_RUNTIME_DIR="$P" TROUBLE_PIN_BEHIND=1 TROUBLE_PIN_HOURS=2 -- read --json --only pin
[ "$(state_of "$out" pin)" = ok ] && ok "a pin just gone behind is not red before its hours" || no "pin fresh ($(note_of "$out" pin))"

# 1c · a clean Hyprland is quiet
: > "$T/hypr.errors"
trouble -- read --json --only hyprland
[ "$(state_of "$out" hyprland)" = ok ] && ok "a clean Hyprland config is ok" || no "hyprland clean ($(note_of "$out" hyprland))"
printf '/home/u/.config/hypr/hyprland.conf:12: config option <general:bogus> does not exist\n' > "$T/hypr.errors"

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

# 3b · a notice that was not delivered is tried again, and stops once one is sent
rm -f "$S/trouble/testhost.json" "$S/trouble/testhost.announced.json"; : > "$T/notices.log"
echo 1 > "$T/send.rc"
trouble -- check --notify --only tells
trouble -- check --notify --only tells
[ "$(grep -c -- '--source ward' "$T/notices.log")" = 2 ] && ok "a failed send is retried on the next check" || no "failed send retried ($(wc -l < "$T/notices.log"))"
case "$out" in *"not delivered"*) ok "the check says the notice was not delivered" ;; *) no "not delivered said ($out)" ;; esac
rm -f "$T/send.rc"; echo duplicate > "$T/send.decision"
trouble -- check --notify --only tells
[ "$(grep -c -- '--source ward' "$T/notices.log")" = 3 ] && ok "a duplicate decision is tried again too" || no "duplicate retried"
rm -f "$T/send.decision"
trouble -- check --notify --only tells
trouble -- check --notify --only tells
[ "$(grep -c -- '--source ward' "$T/notices.log")" = 4 ] && ok "once sent, the turn is quiet" || no "quiet after send ($(wc -l < "$T/notices.log"))"
[ "$(grep -o -- '--key [^ ]*' "$T/notices.log" | sort -u | wc -l)" = 1 ] && ok "every retry of one turn carries the same key" || no "one key per turn ($(grep -o -- '--key [^ ]*' "$T/notices.log" | sort -u))"

# 3c · red, green and red again inside one hour is a new turn, and news again under a new key
mv "$S/.wake-queue" "$T/wake-queue.kept"
trouble -- check --notify --only tells
[ "$(state_of "$(cat "$S/trouble/testhost.json")" tells)" = ok ] && ok "the tell answered: green" || no "tells green"
mv "$T/wake-queue.kept" "$S/.wake-queue"
sleep 1
trouble -- check --notify --only tells
[ "$(grep -c -- '--source ward' "$T/notices.log")" = 5 ] && ok "red again inside the hour is said again" || no "red-green-red said twice ($(wc -l < "$T/notices.log"))"
[ "$(grep -o -- '--key [^ ]*' "$T/notices.log" | sort -u | wc -l)" = 2 ] && ok "the second turn has its own key" || no "a key per turn"

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
# a stand-in road: the far machine is this one, its pin this tree, its name the road's host
printf '%s\n' "\$*" >> "$T/ssh.log"
road=""; for a in "\$@"; do case "\$a" in *@*) road="\$a" ;; esac; done
h="\${road#*@}"; h="\${h%%.*}"
exec env YMIR_RUNTIME_DIR="$TREE" TROUBLE_HOST="\$h" bash -s
X
chmod +x "$T/bin/ssh"; : > "$T/ssh.log"
trouble -- fleet --json
hosts="$(printf '%s' "$out" | python3 -c 'import json,sys; print(" ".join(sorted(r["host"] for r in json.load(sys.stdin))))' 2>/dev/null)"
[ "$hosts" = "dim far phone testhost" ] && ok "the fleet reads every machine in the registry, a hand included" || no "fleet hosts ($hosts | $out)"
grep -q 'u@phone.example.org' "$T/ssh.log" && ok "the hand is asked over its road" || no "the hand is asked ($(cat "$T/ssh.log"))"
: > "$T/ssh.log"
trouble TROUBLE_ROLES=heart -- fleet --json
hosts="$(printf '%s' "$out" | python3 -c 'import json,sys; print(" ".join(sorted(r["host"] for r in json.load(sys.stdin))))' 2>/dev/null)"
[ "$hosts" = "far" ] && ok "TROUBLE_ROLES narrows the fleet" || no "TROUBLE_ROLES narrows ($hosts)"
printf '%s' "$out" | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin) if x["host"]=="far"][0]; sys.exit(0 if r.get("rows") else 1)' 2>/dev/null \
  && ok "the far row answered from the far side" || no "the far row answered ($out)"
grep -q 'u@far.example.org' "$T/ssh.log" && ok "the road is the registry's user@tailnet" || no "the road ($(cat "$T/ssh.log"))"
grep -q 'dim.example.org' "$T/ssh.log" && no "a dark machine is not asked" || ok "a dark machine is not asked"

[ "$fail" = 0 ] && printf 'test_trouble: all passed\n' || printf 'test_trouble: FAILED\n'
exit "$fail"
