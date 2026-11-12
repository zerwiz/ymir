#!/usr/bin/env bash
# test_opencode_launcher.sh — plan 262: an OpenCode worker actually starts, and every door
# that seats one says the same thing.
#
# Measured 2026-11-12 on OpenCode v2.2.7: the interactive TUI refuses --model ("Unrecognized flag:
# --model in command opencode"); only `opencode run` takes -m. Four doors each built their own
# shape and three of them drifted. This test holds the parity:
#
#   door 1  bin/seat/opencode-launcher.sh print        (the generator)
#   door 2  bin/agents/einherjar-spawn.sh --dry-run    (the shell spawner)
#   door 3  src/ymir_runtime/harness.py                (the engine)
#   door 4  bin/agents/eindri-start.sh, tmux fallback  (a fake tmux records what it is told to run)
#   door 5  bin/seat/herdr-run.sh                      (asked, by reading: it must call the launcher
#                                                       and name no opencode flag of its own)
#
# It needs no model turn and no opencode binary (the check is proved against a stub). Exit non-zero
# on any FAIL. A machine without python3 is a clean skip (RULES/25).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fail=0
ok()   { printf 'ok   %s\n' "$1"; }
bad()  { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1"; printf '       want: %s\n       got:  %s\n' "$2" "$3"; fi; }

command -v python3 >/dev/null 2>&1 || { printf 'skip  python3 is absent — the engine door cannot be proved\n'; exit 0; }

LAUNCHER="$ROOT/bin/seat/opencode-launcher.sh"
MODEL="opencode/deepseek-v4.1-flash-free"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
BRIEF="$TMP/brief.md"; printf '# Task\nwrite OK to a file and stop\n' >"$BRIEF"

# ── door 1: the shape itself ────────────────────────────────────────────────────────────────────
want="$("$LAUNCHER" print --model "$MODEL" --brief "$BRIEF")"
case "$want" in
  "env OPENCODE_CONFIG_CONTENT='{\"model\":\"$MODEL\",\"permission\":"*"}' opencode --auto --prompt \"\$(cat '$BRIEF')\"") ok "the launcher prints env + config model + --auto --prompt" ;;
  *) bad "the launcher shape is wrong: $want" ;;
esac
case "$want" in *" --model "*|*"opencode run"*) bad "the shape carries a flag the TUI refuses: $want" ;; *) ok "the shape names no --model flag and no 'opencode run'" ;; esac
bash -n <<<"$want" && bash -n <<<"exec $want" && ok "the shape parses bare and after exec"
cfg="$(printf '%s' "$want" | sed -E "s/^env OPENCODE_CONFIG_CONTENT='([^']*)'.*/\1/")"
python3 -I - "$cfg" <<'PY' && ok "the config is JSON, names the model, and denies a push to main" || bad "the inline config does not carry the worker denials"
import json, sys
c = json.loads(sys.argv[1])
assert c["model"] == "opencode/deepseek-v4.1-flash-free"
assert c["permission"]["bash"]["git push origin main*"] == "deny"
assert c["permission"]["bash"]["gh pr merge*"] == "deny"
PY
nomodel="$("$LAUNCHER" print --brief "$BRIEF")"
case "$nomodel" in *'"model"'*) bad "no model given, yet the config names one" ;; *) ok "no model given -> the config carries no model (OpenCode's own default)" ;; esac
YMIR_OPENCODE_PROFILE="$TMP/absent.json" "$LAUNCHER" print --brief "$BRIEF" >/dev/null 2>&1 \
  && bad "a missing worker profile was not refused" || ok "a missing worker profile is refused"

# ── door 2: the shell spawner's dry run ────────────────────────────────────────────────────────
mkdir -p "$TMP/data/parity" "$TMP/config"; printf '# Task\nwrite OK to a file and stop\n' >"$TMP/data/parity/brief.md"
dry="$(BROKK_HOME="$TMP" timeout 90 "$ROOT/bin/agents/einherjar-spawn.sh" parity "$ROOT" --scout \
        --harness opencode --model "$MODEL" --dry-run 2>/dev/null | sed -n 's/^  launch: cd [^ ]* && //p')"
wantdry="$("$LAUNCHER" print --model "$MODEL" --brief "$TMP/data/parity/brief.md")"
eq "einherjar-spawn --dry-run prints the launcher's shape" "$wantdry" "$dry"

# ── door 3: the engine ──────────────────────────────────────────────────────────────────────────
eng="$(cd "$ROOT/src" && python3 -I - "$MODEL" "$BRIEF" <<'PY'
import sys
sys.path.insert(0, ".")
from ymir_runtime import harness
sel = harness.HarnessSelection("opencode", sys.argv[1], "", "", "")
print(harness.build_launch_command(sel, sys.argv[2]))
PY
)"
eq "the engine (harness.py) prints the launcher's shape" "$want" "$eng"

# ── door 4: eindri-start's tmux fallback ───────────────────────────────────────────────────────
# YMIR_HERDR_PANES=0 makes herdr-run refuse, so the road falls to tmux; a fake tmux records the
# command it is told to open a window with.
if [ -x "$ROOT/bin/agents/eindri-start.sh" ]; then
  mkdir -p "$TMP/bin" "$TMP/state"
  cat >"$TMP/bin/tmux" <<EOF
#!/usr/bin/env bash
case "\$1" in
  has-session) exit 0 ;;
  new-window) shift; for a in "\$@"; do last="\$a"; done; printf '%s\n' "\$last" >"$TMP/tmux-window" ;;
esac
exit 0
EOF
  chmod +x "$TMP/bin/tmux"
  (cd "$ROOT" && PATH="$TMP/bin:$PATH" YMIR_HERDR_PANES=0 BROKK_STATE_OVERRIDE="$TMP/state" \
     timeout 90 bin/agents/eindri-start.sh "write OK to a file and stop, then report done to the coordinator" \
     --role huginn --kind opencode --model "$MODEL" >/dev/null 2>&1)
  if [ -s "$TMP/tmux-window" ]; then
    win="$(cat "$TMP/tmux-window")"
    case "$win" in
      *"opencode --auto --prompt"*"OPENCODE_CONFIG_CONTENT"*|*"OPENCODE_CONFIG_CONTENT"*"opencode --auto --prompt"*) ok "the tmux fallback runs the launcher's shape" ;;
      *) bad "the tmux fallback did not run the launcher's shape: $win" ;;
    esac
    case "$win" in *"exec opencode"*|*"--model"*) bad "the tmux fallback still builds its own opencode line: $win" ;; *) ok "the tmux fallback no longer execs a bare opencode" ;; esac
  else
    bad "the tmux fallback opened no window (the fake tmux heard nothing)"
  fi
fi

# ── door 5: the herdr seat — it must CALL the launcher and own no opencode flag ───────────────
grep -q 'opencode-launcher.sh' "$ROOT/bin/seat/herdr-run.sh" && ok "herdr-run.sh calls the launcher" || bad "herdr-run.sh does not call the launcher"
grep -q 'hdr pane run "\$pane" "\$oc_line"' "$ROOT/bin/seat/herdr-run.sh" && ok "herdr-run.sh runs the shape with hdr pane run (agent start carries no environment)" || bad "herdr-run.sh does not run the shape in the pane"
grep -q 'seat-prove.sh' "$ROOT/bin/seat/herdr-run.sh" && ok "herdr-run.sh proves the agent before counting the seat" || bad "herdr-run.sh counts a seat it never saw"
for f in bin/seat/herdr-run.sh bin/agents/einherjar-spawn.sh bin/agents/eindri-start.sh src/ymir_runtime/harness.py; do
  if grep -nE "opencode (run|--model|--prompt)" "$ROOT/$f" | grep -vE '^[0-9]+:[[:space:]]*#' | grep -vE 'launch: cd' >/dev/null; then
    bad "$f builds its own opencode line"
  else ok "$f builds no opencode line of its own"; fi
done

# ── an explicit --kind wins, and --kind claude gets an Anthropic alias ─────────────────────────
grep -q 'KIND_EXPLICIT' "$ROOT/bin/seat/herdr-run.sh" && grep -q -- '--kind "\$KIND_EXPLICIT"' "$ROOT/bin/agents/eindri-start.sh" \
  && ok "eindri-start passes an explicit --kind to herdr-run, which lets it win over agents.yaml" || bad "an explicit --kind is not carried to the seat"
grep -q 'YMIR_CLAUDE_DEFAULT_MODEL:-sonnet' "$ROOT/bin/agents/eindri-start.sh" && ok "--kind claude without --model defaults to an Anthropic alias" || bad "--kind claude has no Anthropic default"

# ── the version guard, proved against stubs ────────────────────────────────────────────────────
printf '#!/usr/bin/env bash\ncase "$1" in --version) echo "opencode v9.9.9" ;; *) printf "FLAGS\\n  --auto   x\\n  --prompt string  y\\n" ;; esac\n' >"$TMP/oc-good"
printf '#!/usr/bin/env bash\ncase "$1" in --version) echo "opencode v9.9.9" ;; *) printf "FLAGS\\n  --auto   x\\n" ;; esac\n' >"$TMP/oc-bad"
chmod +x "$TMP/oc-good" "$TMP/oc-bad"
YMIR_OPENCODE_BIN="$TMP/oc-good" "$LAUNCHER" check >/dev/null 2>&1 && ok "check: a TUI that lists --prompt and --auto is green" || bad "check: a good TUI was refused"
out="$(YMIR_OPENCODE_BIN="$TMP/oc-bad" "$LAUNCHER" check 2>&1)" && bad "check: a TUI without --prompt was passed" \
  || { case "$out" in *--prompt*) ok "check: a TUI that lost --prompt is red and says so" ;; *) bad "check: red without naming the flag: $out" ;; esac; }

printf '\n%s\n' "$([ "$fail" -eq 0 ] && echo 'all ok' || echo "$fail failed")"
exit "$fail"
