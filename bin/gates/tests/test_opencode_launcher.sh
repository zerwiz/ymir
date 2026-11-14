#!/usr/bin/env bash
# test_opencode_launcher.sh — plan 262: an OpenCode worker actually starts, and every door
# that seats one says the same thing.
#
# Measured 2026-11-12 on OpenCode v2.2.7: the interactive TUI refuses --model ("Unrecognized flag:
# --model in command opencode"); only `opencode run` takes -m. Four doors each built their own
# shape and three of them drifted. Main's one door (bin/seat/opencode-launcher.sh, #679) prints
# `opencode run [--model M] --auto "<brief>"`; this test holds every door to exactly that line:
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
  "env OPENCODE_CONFIG_CONTENT='"*"' opencode run --model '$MODEL' --auto \"\$(cat '$BRIEF')\"") ok "the launcher prints env + opencode run --model M --auto <brief>" ;;
  *) bad "the launcher shape is wrong: $want" ;;
esac
case "$want" in *"opencode --model"*|*"opencode --prompt"*) bad "the shape is the dead top-level form: $want" ;; *) ok "the shape is not the dead top-level --model/--prompt form" ;; esac
bash -n <<<"$want" && bash -n <<<"exec $want" && ok "the shape parses bare and after exec"
nomodel="$("$LAUNCHER" print --brief "$BRIEF")"
case "$nomodel" in *"--model"*) bad "no model given, yet the line carries --model" ;; *) ok "no model given -> no --model (OpenCode's own default)" ;; esac
"$LAUNCHER" has "$MODEL" >/dev/null 2>&1 || command -v opencode >/dev/null 2>&1 || ok "has: no opencode here, a clean skip"
if command -v opencode >/dev/null 2>&1; then
  "$LAUNCHER" has no-such-provider/no-such-model >/dev/null 2>&1 && bad "has: a model opencode does not list was passed" || ok "has: a model opencode does not list is refused"
fi

# ── door 2: the shell spawner's dry run ────────────────────────────────────────────────────────
mkdir -p "$TMP/data/parity" "$TMP/config"; printf '# Task\nwrite OK to a file and stop\n' >"$TMP/data/parity/brief.md"
# A dry run only PRINTS its plan, but the spawner still checks that the harness exists — so the door is
# given a stub opencode. Measured 2026-11-14: CI has no opencode on PATH, the spawner refused, and this
# test went red on a correct tree while a developer box stayed green. This file's own contract is that
# it needs no opencode binary; the stub makes that true on every host.
mkdir -p "$TMP/door2bin"; printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/door2bin/opencode"; chmod +x "$TMP/door2bin/opencode"
# The spawner refuses a model the operator's allow-list does not carry, so door 2 uses the one paid model it allows.
ALLOWED="opencode-go/deepseek-v4.1-flash"
# A SEAT EXPORTS ITS OWN ENVIRONMENT, and that is what made this test red on a seat while it stayed
# green on a developer box (measured 2026-11-14): the seat sets BROKK_STATE_OVERRIDE (its own state)
# and BROKK_CONFIG_OVERRIDE (the home's config), and the spawner correctly refuses that as "the house
# is split" before it prints anything. Unsetting YMIR_HOME alone does not move them. This file's own
# contract is that it needs no environment, so the dry run is made in a CLOSED one and proved twice —
# with YMIR_HOME set and with it unset — which is the pair the refusal was actually about.
dry_run() {  # <with|without> YMIR_HOME, in a closed environment -> the launch line
  local mode="$1"
  if [ "$mode" = with ]; then
    env -i PATH="$TMP/door2bin:$PATH" HOME="${HOME:-/tmp}" TMPDIR="$TMP" BROKK_HOME="$TMP" \
      YMIR_HOME="${YMIR_HOME:-${HOME:-/tmp}/Documents/ymirhome}" \
      timeout 90 "$ROOT/bin/agents/einherjar-spawn.sh" parity "$ROOT" --scout \
      --harness opencode --model "$ALLOWED" --dry-run 2>/dev/null \
      | sed -n 's/^  launch: cd [^ ]* && //p'
  else
    env -i PATH="$TMP/door2bin:$PATH" HOME="${HOME:-/tmp}" TMPDIR="$TMP" BROKK_HOME="$TMP" \
      timeout 90 "$ROOT/bin/agents/einherjar-spawn.sh" parity "$ROOT" --scout \
      --harness opencode --model "$ALLOWED" --dry-run 2>/dev/null \
      | sed -n 's/^  launch: cd [^ ]* && //p'
  fi
}
wantdry="$("$LAUNCHER" print --model "$ALLOWED" --brief "$TMP/data/parity/brief.md")"
# The dry run prints a display line (no env prefix, no quotes); the same line, normalised, must match.
wantdry="$(printf '%s' "$wantdry" | sed "s/^env OPENCODE_CONFIG_CONTENT='[^']*' //; s/'//g")"
eq "einherjar-spawn --dry-run prints the launcher's line (opencode run --model M --auto <brief>, YMIR_HOME set)" "$wantdry" "$(dry_run with)"
eq "einherjar-spawn --dry-run prints the same line with YMIR_HOME unset (a seat is not a split)" "$wantdry" "$(dry_run without)"

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
      *"OPENCODE_CONFIG_CONTENT"*"opencode run --model"*"--auto"*) ok "the tmux fallback runs the launcher's shape" ;;
      *) bad "the tmux fallback did not run the launcher's shape: $win" ;;
    esac
    case "$win" in *"exec opencode"*) bad "the tmux fallback still builds its own opencode line: $win" ;; *) ok "the tmux fallback no longer execs a bare opencode" ;; esac
  else
    bad "the tmux fallback opened no window (the fake tmux heard nothing)"
  fi
fi

# ── door 5: the herdr seat — it must CALL the launcher and own no opencode flag ───────────────
grep -q 'opencode-launcher.sh' "$ROOT/bin/seat/herdr-run.sh" && ok "herdr-run.sh calls the launcher" || bad "herdr-run.sh does not call the launcher"
grep -q 'hdr pane run "\$pane" "\$oc_line"' "$ROOT/bin/seat/herdr-run.sh" && ok "herdr-run.sh runs the shape with hdr pane run (agent start carries no environment)" || bad "herdr-run.sh does not run the shape in the pane"
grep -q 'seat-prove.sh' "$ROOT/bin/seat/herdr-run.sh" && ok "herdr-run.sh proves the agent before counting the seat" || bad "herdr-run.sh counts a seat it never saw"
# (the spawner and the engine keep a copy of the line, held to the launcher by doors 2 and 3 above)
for f in bin/seat/herdr-run.sh bin/agents/eindri-start.sh; do
  if grep -nE "opencode (run|--model|--prompt)" "$ROOT/$f" | grep -vE '^[0-9]+:[[:space:]]*#' | grep -vE 'launch: cd' >/dev/null; then
    bad "$f builds its own opencode line"
  else ok "$f builds no opencode line of its own"; fi
done

# ── an explicit --kind wins, and --kind claude gets an Anthropic alias ─────────────────────────
grep -q 'KIND_EXPLICIT' "$ROOT/bin/seat/herdr-run.sh" && grep -q -- '--kind "\$KIND_EXPLICIT"' "$ROOT/bin/agents/eindri-start.sh" \
  && ok "eindri-start passes an explicit --kind to herdr-run, which lets it win over agents.yaml" || bad "an explicit --kind is not carried to the seat"
grep -q 'errand weight' "$ROOT/bin/agents/eindri-start.sh" && ok "--kind claude without --model takes an Anthropic alias chosen by the errand's weight" || bad "--kind claude has no Anthropic default"

# ── the version guard, proved against stubs ────────────────────────────────────────────────────
printf '#!/usr/bin/env bash\ncase "$1" in --version) echo "v9.9.9" ;; run) printf "  --model m\\n  --auto a\\n" ;; esac\n' >"$TMP/bin/opencode"
printf '#!/usr/bin/env bash\ncase "$1" in --version) echo "v9.9.9" ;; run) printf "  --auto a\\n" ;; esac\n' >"$TMP/bin-bad-opencode"
chmod +x "$TMP/bin/opencode" "$TMP/bin-bad-opencode"; mkdir -p "$TMP/badbin"; cp "$TMP/bin-bad-opencode" "$TMP/badbin/opencode"
PATH="$TMP/bin:$PATH" "$LAUNCHER" check >/dev/null 2>&1 && ok "check: an opencode whose run takes --model and --auto is green" || bad "check: a good opencode was refused"
out="$(PATH="$TMP/badbin:$PATH" "$LAUNCHER" check 2>&1)" && bad "check: an opencode whose run lost --model was passed" \
  || ok "check: an opencode whose run lost --model is red"

printf '\n%s\n' "$([ "$fail" -eq 0 ] && echo 'all ok' || echo "$fail failed")"
exit "$fail"
