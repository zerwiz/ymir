#!/usr/bin/env bash
# test_sender_direct.sh — every worker talks back DIRECTLY to whoever sent it, on every dispatch road.
#
# A stand-in worker is dispatched by each road (eindri-start on herdr and on the engine, herdr-run, einherjar-spawn
# on its own road and on the engine, a dispatch carried in from another machine). It reads the brief the road wrote,
# runs the commands that brief names, and ends. The sender must receive a direct message holding the question and
# then the result, and the question and report files must still be written.
#
# FENCED: a scratch HOME and state, a fake herdr, tmux, ssh and nohup. No real pane, seat, arm or home is touched.
set -u
ROOT="$(CDPATH='' command cd -- "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ok=0; fail=0
good() { ok=$((ok+1)); printf 'ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ -n "${2-}" ] && printf '     %s\n' "$(printf '%s' "$2" | tail -c 1200)"; }
has()  { grep -qF -- "$2" <<<"$1"; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# nothing of the caller's seat is inherited
while IFS= read -r v; do unset "$v"; done < <(env | sed -n 's/^\(\(YMIR\|BROKK\|HERDR\|HERMES\|FLEET\)[A-Z0-9_]*\)=.*/\1/p')
unset TMUX
export HOME="$T/home" XDG_STATE_HOME="$T/home/.local/state" XDG_CONFIG_HOME="$T/home/.config" YMIR_HOME="$T/home/ymir"
export YMIR_STATE_DIR="$YMIR_HOME/state" YMIR_DATA_DIR="$YMIR_HOME/hodd/data" YMIR_SETTINGS_DIR="$YMIR_HOME/config"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
mkdir -p "$YMIR_STATE_DIR" "$YMIR_DATA_DIR" "$YMIR_SETTINGS_DIR" "$YMIR_HOME/hodd/identity" "$XDG_CONFIG_HOME" "$T/bin" "$T/doors" "$T/briefs"
ME="$(hostname -s 2>/dev/null || uname -n)"
printf '{"hosts":{"%s":{"user":"u","tailnet":"here.example"},"faraway":{"user":"u","tailnet":"far.example"}}}' "$ME" >"$YMIR_DATA_DIR/fleet.json"
export YMIR_FLEET_REGISTRY="$YMIR_DATA_DIR/fleet.json" FLEET_TELL_REGISTRY="$YMIR_DATA_DIR/fleet.json" YMIR_RUNTIME_DIR="$ROOT"
export SENTLOG="$T/sent" DOORS="$T/doors.log" BRIEFS="$T/briefs"
export EINDRI_SEND_WAIT=0 YMIR_NO_INJECT=1 YMIR_CLAIMS=off YMIR_HERDR_AGENT_WAIT=0 YMIR_AGENT_SCOPE=0 YMIR_DISPATCH_NO_HELM=1
export YMIR_ACCLAIM_WELL=/bin/true WELL_BRIEF_DOOR=/bin/true YMIR_AUTO_REVIEW=off VEIL_ARM=off VEIL_PR_CHECKS=off YMIR_SEAT_SETTLE=1 YMIR_BUILDER_BUDGET_ENFORCE=0

cat >"$T/bin/herdr" <<'S'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "agent --help"|"agent ") printf '  herdr agent prompt <t> <text>\n  herdr agent start --kind K --pane P\n  herdr agent wait --until S\n' ;;
  "agent get") printf '{"result":{"agent":{"agent":"claude","agent_status":"working","interactive_ready":true}}}\n' ;;
  "agent prompt") case "$3" in w1:pS|w2:pZ) printf '%s\t%s\n' "$3" "$4" >>"$SENTLOG" ;; *) printf '%s\n' "$4" >"$BRIEFS/$3" ;; esac ;;
  "agent list") echo '{"result":{"agents":[{"agent":"claude","pane_id":"w1:pS","name":"boss"}]}}' ;;
  "pane list") echo '{"result":{"panes":[{"pane_id":"w1:pS"}]}}' ;;
  "pane process-info") [ "${4:-}" = w1:pS ] && [ -n "${SENDER_PID:-}" ] && printf '{"result":{"process_info":{"shell_pid":%s}}}\n' "$SENDER_PID" ;;
  "pane read") r="$(printf '─%.0s' $(seq 1 70))"; printf ' t\n%s\n❯ \n%s\n  ⏵⏵ auto mode on\n' "$r" "$r" ;;
  "tab create") echo '{"result":{"tab":{"tab_id":"w9:t1"},"root_pane":{"pane_id":"w9:p9"}}}' ;;
  "pane split") exit 1 ;;
  *) exit 0 ;;
esac
S
cat >"$T/bin/tmux" <<'S'
#!/usr/bin/env bash
case "${1:-}" in new-window) echo "@7" ;; list-windows) : ;; *) exit 0 ;; esac
S
cat >"$T/bin/ssh" <<'S'
#!/usr/bin/env bash
for a in "$@"; do case "$a" in *@*) printf 'ssh %s\n' "$a" >>"$DOORS" ;; esac; done
eval "${@: -1}"
S
printf '#!/usr/bin/env bash\nexit 0\n' >"$T/bin/nohup"   # no background bridge is left behind
printf '#!/usr/bin/env bash\necho "${HOLDER:-not-found}"\n' >"$T/doors/holder"
printf '#!/usr/bin/env bash\nprintf "arm %%s\\n" "$*" >>"$DOORS"\n' >"$T/doors/arm"
chmod +x "$T/bin"/* "$T/doors"/*; export PATH="$T/bin:$PATH"
export YMIR_REPLY_ARM="$T/doors/arm" YMIR_REPLY_HOLDER="$T/doors/holder" YMIR_REPLY_FOREGROUND=1

PROJ="$T/project"; git init -q "$PROJ"; echo x >"$PROJ/README.md"; git -C "$PROJ" add README.md; git -C "$PROJ" commit -qm base
TASK="# Task

Forge the stand-in thing in the project: write the file, prove it with a command, and report what you found."

cat >"$YMIR_HOME/hodd/identity/projects.yaml" <<YAML
projects:
  - id: standin
    name: Standin
    realm: work
    local_clone: $PROJ
YAML

# the sender's session: its pane is PROVED from the process tree, as on a real machine
sender() { env HERDR_ENV=1 HERDR_PANE_ID=w1:pS SENDER_PID=$$ "$@"; }
reset() { : >"$SENTLOG"; : >"$DOORS"; rm -f "$BRIEFS"/*; }
ORIGIN="agent boss (claude) · herdr pane w1:pS · $ME"

# the stand-in worker: it knows ONLY its brief. It asks, then ends.
worker() { # <brief-file> <errand>
  local brief="$1" id="$2" door
  door="$(grep -oE "bash [^ ]+/reply\.sh --ask --errand $id" "$brief" | head -1 | awk '{print $2}')"
  [ -n "$door" ] || { echo "the brief names no ask command for $id"; return 1; }
  ( cd "$PROJ" && export YMIR_REPLY_PANE=w9:p9 YMIR_REPLY_ORIGIN="agent $id · herdr pane w9:p9 · $ME" BROKK_STATE_OVERRIDE="$T/seat-$id" \
    && bash "$door" --ask --errand "$id" "which branch for $id?" \
    && BROKK_STATE_OVERRIDE="$YMIR_STATE_DIR" bash "$(dirname "$door")/eindri-acclaim.sh" "$id" "$PROJ" --terminal done --evidence true --line "done: verdict PASS for $id, found 3 faults — https://github.com/acme/widget/pull/7" )
}
proves() { # <road> <errand> <brief-file>
  local road="$1" id="$2" brief="$3" out sent
  [ -s "$brief" ] || { bad "$road: no brief reached the worker" "$brief"; return; }
  head -1 "$brief" | grep -qF "[from $ORIGIN]" && good "$road: the brief opens with the sender's stamp" || bad "$road: stamp" "$(head -1 "$brief")"
  grep -qF "origin=$ORIGIN" "$XDG_STATE_HOME/ymir/replies/errands/$id" 2>/dev/null \
    && grep -qF "sender_address=w1:pS" "$YMIR_STATE_DIR/$id.sender" 2>/dev/null \
    && good "$road: the sender and the reply road are recorded with the errand" || bad "$road: record" "$(cat "$YMIR_STATE_DIR/$id.sender" 2>&1)"
  : >"$SENTLOG"
  out="$(worker "$brief" "$id" 2>&1)"; sent="$(cat "$SENTLOG")"
  has "$sent" "w1:pS	[reply from agent $id" && has "$sent" "QUESTION from errand $id" && has "$sent" "which branch for $id?" \
    && good "$road: the question reaches the sender directly" || bad "$road: question" "$out $sent"
  grep -qF "which branch for $id?" "$YMIR_STATE_DIR/eindri-questions/$id.md" 2>/dev/null \
    && good "$road: the question file is still written" || bad "$road: question file" "$out"
  has "$sent" "errand $id done: done: verdict PASS for $id, found 3 faults" \
    && good "$road: the result reaches the sender as a message, with the verdict and findings" || bad "$road: result" "$out $sent"
  grep -qF "found 3 faults" "$YMIR_STATE_DIR/eindri-reports/$id.md" 2>/dev/null \
    && good "$road: the report file is still written" || bad "$road: report file" "$out"
  # the turn-end hook of the same turn adds no second copy of the answer
  local n; n="$(wc -l <"$SENTLOG")"
  python3 -c 'import json,sys; print(json.dumps({"session":"s","answer":"final words","messages":[{"id":sys.argv[2],"text":sys.argv[1],"since":1}]}))' \
    "$(cat "$brief")" "$id" | YMIR_REPLY_PANE=w9:p9 bash "$ROOT/bin/agents/reply.sh" --turn-end >/dev/null 2>&1
  [ "$(wc -l <"$SENTLOG")" = "$n" ] && good "$road: the turn-end hook sends no second copy" || bad "$road: double" "$(tail -1 "$SENTLOG")"
}

# ── 1 · eindri-start, the herdr road ───────────────────────────────────────────
reset
o="$(cd "$PROJ" && sender bash "$ROOT/bin/agents/eindri-start.sh" "$TASK" --main --kind pi --role sindri 2>&1)"
b="$(ls "$BRIEFS"/* 2>/dev/null | head -1)"; id="${b##*/}"
if [ -n "$b" ]; then proves "eindri-start (herdr)" "$id" "$b"; else bad "eindri-start (herdr): nothing was seated" "$o"; fi

# ── 2 · herdr-run eindri ───────────────────────────────────────────────────────
reset
o="$(cd "$PROJ" && sender bash "$ROOT/bin/seat/herdr-run.sh" eindri --main --kind pi --role sindri road-herdr -- "$TASK" 2>&1)"
if [ -s "$BRIEFS/road-herdr" ]; then proves "herdr-run" road-herdr "$BRIEFS/road-herdr"; else bad "herdr-run: nothing was seated" "$o"; fi
grep -qF "sender=$ORIGIN" "$YMIR_STATE_DIR/road-herdr.meta" 2>/dev/null \
  && good "herdr-run: the errand's meta names the sender" || bad "herdr-run: meta" "$(cat "$YMIR_STATE_DIR/road-herdr.meta" 2>&1)"

# ── 3 · einherjar-spawn, its own road and the engine's ─────────────────────────
for eng in off auto; do
  id="road-spawn-$eng"; reset
  mkdir -p "$YMIR_DATA_DIR/$id"; printf '%s\n' "$TASK" >"$YMIR_DATA_DIR/$id/brief.md"
  o="$(cd "$PROJ" && sender env YMIR_ENGINE="$eng" bash "$ROOT/bin/agents/einherjar-spawn.sh" "$id" "$PROJ" --scout --backend tmux --harness "standin-harness __BRIEF__" 2>&1)"
  p="$YMIR_DATA_DIR/$id/prompt.md"
  if [ -s "$p" ]; then proves "einherjar-spawn (engine $eng)" "$id" "$p"; else bad "einherjar-spawn (engine $eng): no prompt" "$o"; fi
  grep -qF "sender=$ORIGIN" "$YMIR_STATE_DIR/$id.meta" 2>/dev/null \
    && good "einherjar-spawn (engine $eng): the errand's meta names the sender" || bad "einherjar-spawn (engine $eng): meta" "$o"
done

# ── 4 · eindri-start --id, handed to the engine ────────────────────────────────
reset; id=road-engine
# the engine seats this tree's own errands, so it runs from a COPY of the tree: its worktree is cut in the copy
OWN="$T/own"; mkdir -p "$OWN"
( cd "$ROOT" && git ls-files -z -co --exclude-standard | while IFS= read -r -d '' f; do [ -e "$f" ] && printf '%s\0' "$f"; done | tar --null -T - -cf - ) | tar -xf - -C "$OWN"
git init -q "$OWN"; git -C "$OWN" add -A >/dev/null 2>&1; git -C "$OWN" commit -qm base
o="$(cd "$OWN" && sender env YMIR_HERDR_PANES=0 BROKK_BACKEND=tmux YMIR_RUNTIME_DIR="$OWN" bash "$OWN/bin/agents/eindri-start.sh" "$TASK" --id "$id" --kind "standin-harness __BRIEF__" --model standin/model --role sindri 2>&1)"
p="$YMIR_DATA_DIR/$id/prompt.md"
if [ -s "$p" ]; then
  proves "eindri-start (engine)" "$id" "$p"
  grep -qF "sender=$ORIGIN" "$YMIR_STATE_DIR/$id.meta" && good "eindri-start (engine): the errand's meta names the sender" || bad "eindri-start (engine): meta" "$o"
else bad "eindri-start (engine): no prompt" "$(grep -E "^(error|help|refused|engine)" <<<"$o")"; fi

# ── 5 · another machine: a worker sent from there answers there ────────────────
reset
far="agent helm (claude) · herdr pane w2:pZ · faraway"
o="$(cd "$PROJ" && sender bash "$ROOT/bin/seat/herdr-run.sh" eindri --main --kind pi --role sindri --sender "$far" road-far -- "$TASK" 2>&1)"
out="$(worker "$BRIEFS/road-far" road-far 2>&1)"
has "$(cat "$DOORS")" "ssh u@far.example" && has "$(cat "$SENTLOG")" "w2:pZ" && has "$(cat "$SENTLOG")" "verdict PASS for road-far" \
  && has "$(cat "$SENTLOG")" "which branch for road-far?" \
  && good "cross-machine: question and result travel to the sender's pane on its machine" || bad "cross-machine" "$out $(cat "$DOORS" "$SENTLOG")"

# a sender with no pane (a script, an arm outside herdr) is answered through that machine's arm holder
reset
o="$(bash "$ROOT/bin/agents/sender.sh" record road-arm --sender "agent seat (faraway) · arm faraway · faraway" 2>&1)"
cat >"$T/bin/fake-fleet" <<'S'
#!/usr/bin/env bash
printf 'fleet %s\n' "$*" >>"$DOORS"
S
chmod +x "$T/bin/fake-fleet"
YMIR_REPLY_FLEET="$T/bin/fake-fleet" bash "$ROOT/bin/agents/reply.sh" --errand road-arm "done: verdict PASS" >/dev/null 2>&1
has "$(cat "$DOORS")" "fleet --arm-only --to faraway" && has "$(cat "$DOORS")" "verdict PASS" \
  && good "cross-machine: an arm sender is answered through that arm's queue" || bad "arm road" "$o $(cat "$DOORS")"
got="$(bash "$ROOT/bin/agents/sender.sh" origin --sender "script cron · $ME")"
[ "$got" = "script cron · arm $ME · $ME" ] && good "a script dispatch is answered by this machine's arm holder" || bad "script sender" "$got"

# ── 6 · fleet-tell: the line to another machine carries a road back ────────────
got="$(bash "$ROOT/bin/agents/reply.sh" --parse "[from agent Ada ($ME) · arm $ME · $ME] go")"
has "$got" "\"from\",\"arm\",\"$ME\"" && good "fleet-tell's paneless stamp names a road back" || bad "fleet stamp" "$got"

# ── by hand ────────────────────────────────────────────────────────────────────
reset
bash "$ROOT/bin/agents/sender.sh" record road-bare --sender "$ORIGIN" >/dev/null
( cd "$PROJ" && YMIR_ERRAND_ID=road-bare YMIR_REPLY_PANE=w9:p8 bash "$ROOT/bin/agents/reply.sh" "bare answer" ) >/dev/null 2>&1
has "$(cat "$SENTLOG")" "bare answer" && good "a bare reply.sh in a worker resolves to the recorded sender" || bad "bare" "$(cat "$SENTLOG")"
o="$(bash "$ROOT/bin/agents/reply.sh" --ask --errand no-such "q" 2>&1)"; rc=$?
[ "$rc" = 3 ] && has "$o" "Nothing was sent" && good "an ask with no recorded sender is refused in words" || bad "no sender" "$rc $o"

printf 'test_sender_direct: %s ok, %s failed\n' "$ok" "$fail"; [ "$fail" = 0 ]
