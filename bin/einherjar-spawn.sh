#!/usr/bin/env bash
# einherjar-spawn.sh - gather an Eindri worker (Einherjar = the chosen who are
# gathered to fight) into a Yggdrasil worktree, optionally sealed by Utgard,
# and expose its launch through the runtime backend (tmux/herdr).
#
# Usage:
#   einherjar-spawn.sh <task-id> <project-dir> --mode <direct-PR|local-only|no-mistakes>
#       [--yolo on|off] [--harness <name>] [--model <name>]
#       [--effort <low|medium|high|xhigh|max>] [--backend tmux|herdr]
#       [--isolation on|off|auto]
#   einherjar-spawn.sh <task-id> <project-dir> --scout [--harness ...] [--model ...]
#       [--effort ...] [--backend ...] [--isolation ...]
#   einherjar-spawn.sh <task-id> --relaunch [--harness ...] [--model ...]
#       [--effort ...] [--isolation ...]
#
# It fails closed on an unverified harness: bin/hamr-harness.sh is the shape
# detector when present, otherwise the inline detector runs; either verdict is
# checked against the verified adapter set before any endpoint or worktree
# exists. A raw launch command (a --harness value containing whitespace) is the
# deliberate escape hatch for trialing a new adapter.
# It creates or reuses the Yggdrasil worktree at <BROKK_HOME>/.yggdrasil/<id>,
# records state/<id>.meta, and refuses to launch a ship task whose brief's
# fixed "Delivery contract: mode=<mode>" line disagrees with the explicit
# --mode, so an adjusted brief and the recorded task cannot drift.
# --isolation on runs the worker inside an Utgard container built from
# .agents/sandbox/Dockerfile.utgard; auto selects it only when the image is
# present, and reports the decision; off runs the worker in the worktree.
# --relaunch reuses the recorded worktree, kind, and mode from state/<id>.meta
# and only harness/model/effort/isolation may change.
#
# Every spawn prints:
#   spawned <id> harness=<h> kind=<kind> [mode=<m> yolo=<y>] backend=<b> target=<t> worktree=<wt> isolation=<on|off>
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-${BROKK_ROOT_OVERRIDE:-$ROOT}}"
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"
DATA="${BROKK_DATA_OVERRIDE:-$BROKK_HOME/data}"
CONFIG="${BROKK_CONFIG_OVERRIDE:-$BROKK_HOME/config}"

# Adapters this platform has verified for direct launches. An adapter outside
# this set is refused unless a raw launch command is supplied.
VERIFIED_HARNESSES='opencode pi pi-signed'

shell_quote() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

resolve_dir() {  # <name> <path>
  local name=$1 path=$2 resolved
  case "$path" in
    /*) printf '%s\n' "$path"; return 0 ;;
  esac
  resolved=$(CDPATH='' cd -- "$path" 2>/dev/null && pwd -P) || {
    echo "error: $name directory cannot be resolved: $path" >&2
    return 1
  }
  printf '%s\n' "$resolved"
}

# --- parse ------------------------------------------------------------------
KIND=ship
SCOUT=0
RELAUNCH=0
MODE=
MODE_SET=0
YOLO=off
HARNESS_ARG=
MODEL=
MODEL_SET=0
EFFORT=
EFFORT_SET=0
BACKEND=
BACKEND_SET=0
ISOLATION=auto
POS=()
want_value=
for a in "$@"; do
  if [ -n "$want_value" ]; then
    case "$a" in
      --*) echo "error: --$want_value requires a value" >&2; exit 1 ;;
    esac
    case "$want_value" in
      mode) MODE=$a; MODE_SET=1 ;;
      yolo) YOLO=$a ;;
      harness) HARNESS_ARG=$a ;;
      model) MODEL=$a; MODEL_SET=1 ;;
      effort) EFFORT=$a; EFFORT_SET=1 ;;
      backend) BACKEND=$a; BACKEND_SET=1 ;;
      isolation) ISOLATION=$a ;;
      *) echo "error: internal parser state for --$want_value" >&2; exit 1 ;;
    esac
    want_value=
    continue
  fi
  case "$a" in
    --scout) SCOUT=1 ;;
    --relaunch) RELAUNCH=1 ;;
    --mode) want_value=mode ;;
    --mode=*) MODE=${a#--mode=}; MODE_SET=1 ;;
    --yolo) want_value=yolo ;;
    --yolo=*) YOLO=${a#--yolo=} ;;
    --harness) want_value=harness ;;
    --harness=*) HARNESS_ARG=${a#--harness=} ;;
    --model) want_value=model ;;
    --model=*) MODEL=${a#--model=}; MODEL_SET=1 ;;
    --effort) want_value=effort ;;
    --effort=*) EFFORT=${a#--effort=}; EFFORT_SET=1 ;;
    --backend) want_value=backend ;;
    --backend=*) BACKEND=${a#--backend=}; BACKEND_SET=1 ;;
    --isolation) want_value=isolation ;;
    --isolation=*) ISOLATION=${a#--isolation=} ;;
    *) POS+=("$a") ;;
  esac
done
[ -z "$want_value" ] || { echo "error: --$want_value requires a value" >&2; exit 1; }

ID=${POS[0]:-}
[ -n "$ID" ] || { echo "error: task-id is required" >&2; exit 2; }
case "$ID" in
  */*|.*|*' '*) echo "error: invalid task-id '$ID' (no slashes, no leading dot, no spaces)" >&2; exit 2 ;;
esac

case "$YOLO" in on|off) ;; *) echo "error: --yolo must be on or off (got '$YOLO')" >&2; exit 1 ;; esac
case "$ISOLATION" in on|off|auto) ;; *) echo "error: --isolation must be on, off, or auto (got '$ISOLATION')" >&2; exit 1 ;; esac
if [ -n "$EFFORT" ]; then
  case "$EFFORT" in low|medium|high|xhigh|max) ;; *) echo "error: --effort must be one of low, medium, high, xhigh, max (got '$EFFORT')" >&2; exit 1 ;; esac
fi

if [ "$RELAUNCH" -eq 1 ]; then
  [ "$SCOUT" -eq 0 ] || { echo "error: --scout is refused with --relaunch; the kind comes from the task record" >&2; exit 1; }
  [ "$MODE_SET" -eq 0 ] || { echo "error: --mode is refused with --relaunch; the mode comes from the task record" >&2; exit 1; }
  [ "${#POS[@]}" -le 1 ] || { echo "error: a project positional is refused with --relaunch; it comes from the task record" >&2; exit 1; }
else
  if [ "$SCOUT" -eq 1 ]; then
    [ "$MODE_SET" -eq 0 ] || { echo "error: --mode applies only to ship spawns; a scout delivers a report" >&2; exit 1; }
  else
    [ "$MODE_SET" -eq 1 ] || { echo "error: ship spawns require --mode <direct-PR|local-only|no-mistakes>" >&2; exit 1; }
    case "$MODE" in
      direct-PR|local-only|no-mistakes) ;;
      *) echo "error: --mode must be one of direct-PR, local-only, no-mistakes (got '$MODE')" >&2; exit 1 ;;
    esac
  fi
fi
[ "$BACKEND_SET" -eq 0 ] || case "$BACKEND" in tmux|herdr) ;; *) echo "error: --backend must be tmux or herdr (got '$BACKEND')" >&2; exit 1 ;; esac

if [ "$RELAUNCH" -eq 1 ]; then
  KIND=ship
fi
if [ "$SCOUT" -eq 1 ]; then
  KIND=scout
fi

# --- harness resolution / verification --------------------------------------
# hamr-harness.sh (Hamr = the shape a being wears) is the detector when present.
detect_harness() {
  if [ -x "$SCRIPT_DIR/hamr-harness.sh" ]; then
    "$SCRIPT_DIR/hamr-harness.sh" eindri 2>/dev/null || true
    return
  fi
  # Inline fallback detector: config/eindri-harness, then environment markers,
  # then process ancestry, then the platform default (opencode).
  local configured=
  if [ -f "$CONFIG/eindri-harness" ]; then
    configured=$(tr -d '[:space:]' < "$CONFIG/eindri-harness" || true)
  fi
  if [ -n "$configured" ] && [ "$configured" != default ]; then
    printf '%s\n' "$configured"
    return
  fi
  [ "${PI_CODING_AGENT:-}" = true ] && { printf 'pi\n'; return; }
  [ "${CLAUDECODE:-}" = 1 ] && { printf 'claude\n'; return; }
  local pid=$$ comm
  for _ in 1 2 3 4 5 6; do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null) || break
    case "$(basename -- "${comm:-}")" in
      *opencode*) printf 'opencode\n'; return ;;
      *claude*) printf 'claude\n'; return ;;
      *codex*) printf 'codex\n'; return ;;
      pi|pi-signed) printf 'pi\n'; return ;;
      *node*|*python*)
        case "$(ps -o args= -p "$pid" 2>/dev/null)" in
          *opencode*) printf 'opencode\n'; return ;;
          *" pi "*|*/pi) printf 'pi\n'; return ;;
        esac ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -n "$pid" ] && [ "$pid" -gt 1 ] || break
  done
  printf 'opencode\n'
}

RAW_LAUNCH=
HARNESS=
if [ -n "$HARNESS_ARG" ]; then
  case "$HARNESS_ARG" in
    *' '*) RAW_LAUNCH=$HARNESS_ARG ;;
    *) HARNESS=$HARNESS_ARG ;;
  esac
elif [ "$RELAUNCH" -eq 0 ] && [ -f "$CONFIG/eindri-dispatch.json" ]; then
  echo "error: config/eindri-dispatch.json is active - pass an explicit --harness resolved from its dispatch rules (consultation backstop, so the profiles are never silently skipped)" >&2
  exit 1
else
  HARNESS=$(detect_harness)
  [ -n "$HARNESS" ] || HARNESS=opencode
fi

if [ -n "$RAW_LAUNCH" ]; then
  HARNESS=$(printf '%s' "$RAW_LAUNCH" | awk '{for(i=1;i<=NF;i++) if ($i !~ /^[A-Za-z_][A-Za-z0-9_]*=/) {print $i; exit}}')
  HARNESS=$(basename -- "$HARNESS")
  echo "warning: launching a raw command as harness '$HARNESS' (not on the verified adapter set)" >&2
else
  verified=0
  for v in $VERIFIED_HARNESSES; do
    if [ "$HARNESS" = "$v" ]; then verified=1; break; fi
  done
  if [ "$verified" -ne 1 ]; then
    echo "error: harness '$HARNESS' is not verified for direct launch; verified: $VERIFIED_HARNESSES. Supply a raw launch command via --harness to trial a new adapter." >&2
    exit 1
  fi
  if ! command -v "$HARNESS" >/dev/null 2>&1; then
    echo "error: harness '$HARNESS' executable not found on PATH; install it or select a verified harness" >&2
    exit 1
  fi
fi

# --- backend resolution ------------------------------------------------------
resolve_backend() {
  local b="${BROKK_BACKEND:-}"
  if [ -z "$b" ] && [ -f "$CONFIG/backend" ]; then
    b=$(head -n1 "$CONFIG/backend" | tr -d '[:space:]')
  fi
  if [ -z "$b" ]; then
    if [ -n "${TMUX:-}" ]; then b=tmux
    elif [ "${HERDR_ENV:-}" = 1 ]; then b=herdr
    else b=tmux; fi
  fi
  case "$b" in
    tmux|herdr) printf '%s\n' "$b" ;;
    *) echo "error: unsupported backend '$b' (supported: tmux, herdr)" >&2; return 1 ;;
  esac
}

if [ "$BACKEND_SET" -eq 1 ]; then
  RESOLVED_BACKEND=$BACKEND
else
  RESOLVED_BACKEND=$(resolve_backend) || exit 1
fi

if [ "$RESOLVED_BACKEND" = tmux ]; then
  command -v tmux >/dev/null 2>&1 || { echo "error: backend tmux selected but tmux is not on PATH" >&2; exit 1; }
elif [ "$RESOLVED_BACKEND" = herdr ]; then
  command -v herdr >/dev/null 2>&1 || { echo "error: backend herdr selected but herdr is not on PATH" >&2; exit 1; }
fi

# --- meta / relaunch resolution ---------------------------------------------
META="$STATE/$ID.meta"
meta_value() {  # <file> <key>
  grep "^$2=" "$1" 2>/dev/null | tail -1 | cut -d= -f2- || true
}

PROJECT_DIR=
WT=
if [ "$RELAUNCH" -eq 1 ]; then
  [ -f "$META" ] || { echo "error: --relaunch requires an existing task record at $META" >&2; exit 1; }
  KIND=$(meta_value "$META" kind); KIND=${KIND:-ship}
  WT=$(meta_value "$META" worktree)
  PROJECT_DIR=$(meta_value "$META" project)
  [ -n "$WT" ] || { echo "error: task record $META records no worktree" >&2; exit 1; }
  [ -d "$WT" ] || { echo "error: recorded worktree $WT no longer exists; recover it before relaunching" >&2; exit 1; }
  if [ "$KIND" = ship ] && [ "$MODE_SET" -eq 0 ]; then
    MODE=$(meta_value "$META" mode)
    case "$MODE" in direct-PR|local-only|no-mistakes) ;; *) echo "error: task record $META records no valid mode" >&2; exit 1 ;; esac
  fi
  if [ -z "$HARNESS_ARG" ]; then
    RECORDED_RAW=$(meta_value "$META" raw_launch)
    RECORDED_HARNESS=$(meta_value "$META" harness)
    if [ -n "$RECORDED_RAW" ]; then
      RAW_LAUNCH=$RECORDED_RAW
      HARNESS=${RECORDED_HARNESS:-$(printf '%s' "$RECORDED_RAW" | awk '{print $1}')}
    else
      [ -n "$RECORDED_HARNESS" ] || RECORDED_HARNESS=$(detect_harness)
      HARNESS=$RECORDED_HARNESS
      verified=0
      for v in $VERIFIED_HARNESSES; do
        if [ "$HARNESS" = "$v" ]; then verified=1; break; fi
      done
      if [ "$verified" -ne 1 ]; then
        echo "error: recorded harness '$HARNESS' is not verified for relaunch; pass an explicit --harness or a raw launch command" >&2
        exit 1
      fi
      command -v "$HARNESS" >/dev/null 2>&1 || {
        echo "error: recorded harness '$HARNESS' executable not found on PATH" >&2
        exit 1
      }
    fi
    if [ "$MODEL_SET" -eq 0 ]; then MODEL=$(meta_value "$META" model); fi
    if [ "$EFFORT_SET" -eq 0 ]; then EFFORT=$(meta_value "$META" effort); fi
  fi
  BRIEF="$DATA/$ID/brief.md"
  [ -f "$BRIEF" ] || { echo "error: no brief at $BRIEF; regenerate it: bin/erindi-brief.sh $ID --relaunch" >&2; exit 1; }
else
  [ "${#POS[@]}" -ge 2 ] || { echo "error: <project-dir> is required for a fresh spawn" >&2; exit 2; }
  PROJECT_DIR=$(resolve_dir "project" "${POS[1]}") || exit 1
  [ -d "$PROJECT_DIR" ] || { echo "error: project directory not found: $PROJECT_DIR" >&2; exit 1; }
  git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "error: $PROJECT_DIR is not a git working tree; Yggdrasil needs one to create the task worktree" >&2
    exit 1
  }
  BRIEF="$DATA/$ID/brief.md"
  [ -f "$BRIEF" ] || {
    echo "error: no brief at $BRIEF; scaffold it first: bin/erindi-brief.sh $ID <repo> --mode $MODE" >&2
    exit 1
  }
  if [ "$KIND" = ship ]; then
    contract=$(grep -E '^Delivery contract: mode=' "$BRIEF" 2>/dev/null | head -1 | sed 's/^Delivery contract: mode=//') || true
    if [ -z "$contract" ]; then
      echo "warning: brief $BRIEF has no 'Delivery contract: mode=' line; launching on the explicit --mode=$MODE" >&2
    elif [ "$contract" != "$MODE" ]; then
      echo "error: brief $BRIEF records mode=$contract but spawn requested mode=$MODE; reconcile them before launching" >&2
      exit 1
    fi
  fi
fi

# --- isolation resolution ----------------------------------------------------
ISOLATION_EFFECTIVE=off
case "$ISOLATION" in
  on)
    command -v docker >/dev/null 2>&1 || { echo "error: --isolation on requires docker on PATH" >&2; exit 1; }
    docker image inspect utgard-runner:latest >/dev/null 2>&1 || {
      echo "error: --isolation on requires the Utgard image 'utgard-runner:latest'; build it: docker build -f .agents/sandbox/Dockerfile.utgard -t utgard-runner:latest .agents/sandbox" >&2
      exit 1
    }
    ISOLATION_EFFECTIVE=on
    ;;
  off) ISOLATION_EFFECTIVE=off ;;
  auto)
    if command -v docker >/dev/null 2>&1 && docker image inspect utgard-runner:latest >/dev/null 2>&1; then
      ISOLATION_EFFECTIVE=on
      echo "isolation: on (Utgard image present; pass --isolation off to run in the worktree)" >&2
    else
      ISOLATION_EFFECTIVE=off
      echo "isolation: off (no Utgard image; pass --isolation on after building it)" >&2
    fi
    ;;
esac

# --- Yggdrasil worktree ------------------------------------------------------
WT_ROOT="$BROKK_HOME/.yggdrasil"
if [ -z "$WT" ]; then
  WT="$WT_ROOT/$ID"
  mkdir -p "$WT_ROOT"
  if [ -e "$WT/.git" ]; then
    top=$(git -C "$WT" rev-parse --show-toplevel 2>/dev/null || true)
    [ "$top" = "$WT" ] || { echo "error: $WT exists but is not the expected worktree root" >&2; exit 1; }
  elif [ -e "$WT" ]; then
    echo "error: $WT already exists and is not a Yggdrasil worktree; remove it or choose another task id" >&2
    exit 1
  else
    base=
    remote_head=$(git -C "$PROJECT_DIR" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)
    if [ -n "$remote_head" ]; then
      remote_head=${remote_head#refs/remotes/}
      if git -C "$PROJECT_DIR" rev-parse --verify -q "refs/remotes/$remote_head" >/dev/null 2>&1; then
        base="refs/remotes/$remote_head"
      fi
    fi
    [ -n "$base" ] || base=HEAD
    git -C "$PROJECT_DIR" worktree add --detach "$WT" "$base" >/dev/null || {
      echo "error: Yggdrasil could not create worktree $WT from $PROJECT_DIR" >&2
      exit 1
    }
  fi
fi
[ -d "$WT" ] || { echo "error: Yggdrasil worktree missing: $WT" >&2; exit 1; }

# A linked worktree's .git file points at the project's common git dir. Mount
# that dir at the same path in the sandbox so git resolves inside Utgard.
GIT_COMMON=
if [ -n "$PROJECT_DIR" ]; then
  gc=$(git -C "$PROJECT_DIR" rev-parse --git-common-dir 2>/dev/null || true)
  if [ -n "$gc" ]; then
    GIT_COMMON=$(CDPATH='' cd -- "$PROJECT_DIR" && CDPATH='' cd -- "$gc" && pwd -P) || GIT_COMMON=
  fi
fi

# --- launch script + command -------------------------------------------------
mkdir -p "$STATE" "$DATA/$ID"
LAUNCH_SCRIPT="$STATE/$ID.launch.sh"

if [ "$ISOLATION_EFFECTIVE" = on ]; then
  # The worktree is mounted at the Utgard target; state/ and data/ are
  # mounted at their own host paths so the brief's status, inbox, and report
  # paths resolve identically inside the container.
  LAUNCH_CWD=/sandbox/workspace
else
  LAUNCH_CWD=$WT
fi
# --- pre-dispatch context injection (W0006): drink before you act -----------
# Recall what the well remembers about this task and hand it to the worker with
# the brief. A dry well never blocks; recall is a boost.
CTX="$DATA/$ID/context.md"
TITLE=$(grep -m1 -E '^#|title' "$BRIEF" 2>/dev/null | sed 's/^#* *//' || true)
"$SCRIPT_DIR/mimir.sh" recall "${TITLE:-$ID}" --k 4 >"$CTX" 2>/dev/null || : >"$CTX"
PROMPT="$DATA/$ID/prompt.md"
{
  cat "$BRIEF"
  printf '\n\n---\n\n## Recalled context (the well — Mimirsbrunn)\n\n'
  cat "$CTX"
} >"$PROMPT" 2>/dev/null || cp "$BRIEF" "$PROMPT"
BRIEF_REF=$PROMPT

build_launch_command() {
  local brief_ref=$1 model_flag= effort_flag=
  if [ -n "$MODEL" ] && [ "$MODEL" != default ]; then
    model_flag="--model $(shell_quote "$MODEL") "
  fi
  if [ "$HARNESS" = pi ] || [ "$HARNESS" = pi-signed ]; then
    if [ -n "$EFFORT" ] && [ "$EFFORT" != default ]; then
      effort_flag="--thinking $(shell_quote "$EFFORT") "
    fi
  fi
  case "$HARNESS" in
    opencode)
      printf 'OPENCODE_CONFIG_CONTENT=%s exec opencode %s--prompt "$(cat %s)"' \
        "$(shell_quote '{"permission":{"*":"allow"}}')" "$model_flag" "$(shell_quote "$brief_ref")"
      ;;
    pi|pi-signed)
      printf 'exec pi %s%s"$(cat %s)"' "$model_flag" "$effort_flag" "$(shell_quote "$brief_ref")"
      ;;
    *)
      local cmd=$RAW_LAUNCH
      if printf '%s' "$cmd" | grep -q '__BRIEF__'; then
        cmd=${cmd//__BRIEF__/$(shell_quote "$brief_ref")}
      fi
      printf '%s' "$cmd"
      ;;
  esac
}

LAUNCH_CMD=$(build_launch_command "$BRIEF_REF")
{
  printf '#!/usr/bin/env bash\n'
  printf 'set -eu\n'
  printf 'cd %s\n' "$(shell_quote "$LAUNCH_CWD")"
  printf '%s\n' "$LAUNCH_CMD"
} > "$LAUNCH_SCRIPT"
chmod +x "$LAUNCH_SCRIPT"

if [ "$ISOLATION_EFFECTIVE" = on ]; then
  GIT_MOUNT_ARGS=
  GIT_MOUNT_LINE=none
  if [ -n "$GIT_COMMON" ]; then
    GIT_MOUNT_ARGS=" -v $(shell_quote "$GIT_COMMON:$GIT_COMMON")"
    GIT_MOUNT_LINE=$GIT_COMMON:$GIT_COMMON
  fi
  cat > "$STATE/$ID.utgard" <<EOF
image=utgard-runner:latest
network=none
cpus=1.0
memory=512m
security_opt=no-new-privileges
user=$(id -u):$(id -g)
worktree_mount=$WT:/sandbox/workspace
git_common_mount=$GIT_MOUNT_LINE
state_mount=$STATE:$STATE
data_mount=$DATA:$DATA
launch=$LAUNCH_SCRIPT
EOF
  PANE_CMD="docker run --rm -it --network none --cpus 1.0 --memory 512m --security-opt no-new-privileges --user $(shell_quote "$(id -u):$(id -g)") -e HOME=/tmp -v $(shell_quote "$WT:/sandbox/workspace")$GIT_MOUNT_ARGS -v $(shell_quote "$STATE:$STATE") -v $(shell_quote "$DATA:$DATA") -w /sandbox/workspace utgard-runner:latest bash $(shell_quote "$LAUNCH_SCRIPT")"
else
  rm -f "$STATE/$ID.utgard"
  PANE_CMD="bash $(shell_quote "$LAUNCH_SCRIPT")"
fi

# --- backend launch ----------------------------------------------------------
launch_tmux() {  # -> prints target
  local session wname wid
  if [ -n "${TMUX:-}" ]; then
    session=$(tmux display-message -p '#S')
  else
    session="${BROKK_TMUX_SESSION:-brokk}"
    tmux has-session -t "$session" 2>/dev/null || tmux new-session -d -s "$session" || {
      echo "error: could not create tmux session '$session'" >&2; return 1; }
  fi
  wname="eindri-$ID"
  if tmux list-windows -t "$session" -F '#{window_name}' 2>/dev/null | grep -qx "$wname"; then
    echo "error: tmux window $session:$wname already exists; tear it down or relaunch" >&2
    return 1
  fi
  wid=$(tmux new-window -dP -F '#{window_id}' -t "$session:" -n "$wname" -c "$WT") || {
    echo "error: tmux failed to create window $session:$wname" >&2; return 1; }
  tmux set-window-option -t "$wid" automatic-rename off 2>/dev/null || true
  tmux set-window-option -t "$wid" allow-rename off 2>/dev/null || true
  tmux send-keys -t "$wid" -l "$PANE_CMD"
  tmux send-keys -t "$wid" Enter
  printf '%s\n' "$wid"
}

launch_herdr() {  # -> prints pane id
  local out ws pane
  out=$(herdr workspace create --cwd "$WT" --label "eindri-$ID" --no-focus 2>/dev/null) || {
    echo "error: herdr workspace create failed (is a herdr server running? try: herdr)" >&2
    return 1
  }
  ws=$(printf '%s\n' "$out" | sed -n 's/.*"workspace_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  [ -n "$ws" ] || ws=$(printf '%s\n' "$out" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  [ -n "$ws" ] || ws=$(printf '%s\n' "$out" | head -1)
  [ -n "$ws" ] || { echo "error: could not resolve a herdr workspace id from: $out" >&2; return 1; }
  pane=$(herdr pane list --workspace "$ws" 2>/dev/null | sed -n 's/.*"pane_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  [ -n "$pane" ] || { echo "error: no pane found in herdr workspace $ws" >&2; return 1; }
  herdr pane send-text "$pane" "$PANE_CMD" 2>/dev/null || true
  herdr pane send-keys "$pane" Enter 2>/dev/null || true
  printf '%s\n' "$pane"
}

if [ "$RESOLVED_BACKEND" = tmux ]; then
  RUN_TARGET=$(launch_tmux) || exit 1
else
  RUN_TARGET=$(launch_herdr) || exit 1
fi

# --- record state ------------------------------------------------------------
SPAWN_GEN="s$(date +%s).${BASHPID:-$$}.$RANDOM"
META_TMP="$STATE/.$ID.meta.${BASHPID:-$$}"
{
  printf 'id=%s\n' "$ID"
  printf 'kind=%s\n' "$KIND"
  if [ "$KIND" = ship ]; then
    printf 'mode=%s\n' "$MODE"
    printf 'yolo=%s\n' "$YOLO"
  fi
  printf 'harness=%s\n' "$HARNESS"
  printf 'raw_launch=%s\n' "$RAW_LAUNCH"
  printf 'model=%s\n' "$MODEL"
  printf 'effort=%s\n' "$EFFORT"
  printf 'backend=%s\n' "$RESOLVED_BACKEND"
  printf 'window=%s\n' "$RUN_TARGET"
  printf 'worktree=%s\n' "$WT"
  printf 'project=%s\n' "$PROJECT_DIR"
  printf 'brief=%s\n' "$BRIEF"
  printf 'isolation=%s\n' "$ISOLATION_EFFECTIVE"
  printf 'launch=%s\n' "$LAUNCH_SCRIPT"
  printf 'spawn_gen=%s\n' "$SPAWN_GEN"
} > "$META_TMP"
mv "$META_TMP" "$META"

if [ "$KIND" = ship ]; then
  printf 'spawned %s harness=%s kind=%s mode=%s yolo=%s backend=%s target=%s worktree=%s isolation=%s\n' \
    "$ID" "$HARNESS" "$KIND" "$MODE" "$YOLO" "$RESOLVED_BACKEND" "$RUN_TARGET" "$WT" "$ISOLATION_EFFECTIVE"
else
  printf 'spawned %s harness=%s kind=%s backend=%s target=%s worktree=%s isolation=%s\n' \
    "$ID" "$HARNESS" "$KIND" "$RESOLVED_BACKEND" "$RUN_TARGET" "$WT" "$ISOLATION_EFFECTIVE"
fi
