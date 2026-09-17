#!/usr/bin/env bash
# hamr-harness.sh - detect the agent harness (Hamr) this process tree runs on.
#
# Hamr ("shape") is the form a being wears. Detection answers which agent
# runtime the process tree is wearing so Brokk can choose the correct adapter,
# launch flags, and dispatch profile. Ported from the upstream agent-distro
# reference (bin/hamr-harness.sh) and retargeted to the Brokk runtime
# (memory/plans/core/29-brokk-distro-runtime.md).
#
# Usage:
#   hamr-harness.sh                 print own harness:
#                                   claude|codex|opencode|pi|pi-signed|grok|kimi|cursor|unknown
#   hamr-harness.sh eindri          print the effective EINDRI harness from
#                                   config/eindri-harness; an absent file or the
#                                   value "default" resolves to own.
#   hamr-harness.sh eindri-model    print the optional MODEL token from
#                                   config/eindri-harness, or empty when absent.
#   hamr-harness.sh eindri-effort   print the optional EFFORT token from
#                                   config/eindri-harness, or empty when absent.
#
# config/eindri-harness format: a single line "<harness> [<model>] [<effort>]",
# whitespace-separated. A bare "<harness>" (today's format) behaves exactly as
# harness-only with no model/effort. Only the first non-empty, non-comment line
# is parsed. Model/effort come ONLY from this file.
#
# Detection layers: verified environment markers first, then process ancestry.
# Record each newly verified env marker here.
set -u

# --- portability shim: bin/ymir-platform.sh --------------------------------
# One place knows the OS differences (readlink -f, /proc, setsid, stat, nproc).
if [ -z "${YMIR_PLATFORM_LOADED:-}" ]; then
  _ymir_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  for _ymir_c in "$_ymir_dir/ymir-platform.sh" "$(dirname "$_ymir_dir")/bin/ymir-platform.sh"; do
    [ -r "$_ymir_c" ] && { . "$_ymir_c"; YMIR_PLATFORM_LOADED=1; break; }
  done
  unset _ymir_dir _ymir_c
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BROKK_ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-${BROKK_ROOT_OVERRIDE:-$BROKK_ROOT}}"
CONFIG="${BROKK_CONFIG_OVERRIDE:-$BROKK_HOME/config}"

# --- Cursor process identity ------------------------------------------------
# Cursor ships two executable names: `cursor-agent` and the legacy alias
# `agent`. `agent` is far too generic to trust on its name alone, so structural
# evidence (canonical name or Cursor's versioned install tree) is required.
# This is inlined because the Brokk runtime has no separate cursor library;
# keep this block the single owner of Cursor process identity in this file.
#
# Canonical absolute path for $1, or the input unchanged when it cannot be
# resolved. Symlink resolution is what makes the structural signal work.
hamr_cursor_canonical_path() {  # <path>
  local path=$1 resolved
  [ -n "$path" ] || return 1
  if command -v readlink >/dev/null 2>&1; then
    resolved=$(ymir_readlink_f "$path" 2>/dev/null || true)
    [ -n "$resolved" ] && { printf '%s\n' "$resolved"; return 0; }
  fi
  printf '%s\n' "$path"
}

# True when path $1 carries Cursor's structural evidence: its canonical name is
# cursor-agent, or it lives inside Cursor's cursor-agent/versions/<version>/
# install tree. A directory component merely named `agent` is NEVER enough.
hamr_cursor_path_is_cursor() {  # <path>
  local path=$1 canonical
  [ -n "$path" ] || return 1
  canonical=$(hamr_cursor_canonical_path "$path") || return 1
  case "${canonical##*/}" in cursor-agent) return 0 ;; esac
  case "$canonical" in */cursor-agent/versions/*/*) return 0 ;; esac
  return 1
}

# Read argv[0] without flattening it into a whitespace-delimited command line.
hamr_cursor_argv0_for_pid() {  # <pid> [comm-fallback]
  local pid=$1 fallback=${2:-} proc_root=${BROKK_PROC_ROOT_OVERRIDE:-/proc} argv0=
  if [ -r "$proc_root/$pid/cmdline" ]; then
    IFS= read -r -d '' argv0 < "$proc_root/$pid/cmdline" || true
    [ -n "$argv0" ] && { printf '%s\n' "$argv0"; return 0; }
  fi
  if [ -z "$fallback" ]; then
    fallback=$(LC_ALL=C ps -p "$pid" -o comm= 2>/dev/null || true)
  fi
  [ -n "$fallback" ] || return 1
  printf '%s\n' "$fallback"
}

hamr_cursor_argv0_is_cursor() {  # <argv0>
  local argv0=$1
  [ -n "$argv0" ] || return 1
  case "$argv0" in
    ''|MainThread) return 1 ;;
    cursor-agent) return 0 ;;
  esac
  hamr_cursor_path_is_cursor "$argv0"
}

# True when the process described by command name $1 and structured argv0 $2 is
# Cursor. Rejects a bare MainThread with no Cursor evidence, any executable
# whose basename merely happens to be `agent`, and any path with an `agent/`
# directory component that is running something else.
hamr_cursor_process_matches() {  # <comm> [argv0]
  local comm=$1 argv0=${2:-} base
  [ -n "$comm" ] || [ -n "$argv0" ] || return 1
  argv0=${argv0:-$comm}
  base=$(basename -- "$comm")
  base=${base#-}
  case "$base" in
    cursor-agent) return 0 ;;
    agent|MainThread|node|node-*|node[0-9]*|python|python[0-9]*|python[0-9].[0-9]*)
      hamr_cursor_argv0_is_cursor "$argv0" && return 0
      hamr_cursor_path_is_cursor "$comm" && return 0
      return 1
      ;;
  esac
  case "$comm" in */*) hamr_cursor_path_is_cursor "$comm" && return 0 ;; esac
  return 1
}

detect_own() {
  # Layer 1: environment markers for verified harnesses. Keep marker detection
  # before ancestry detection as an explicit precedence rule.
  #
  # Cursor is checked BEFORE claude, deliberately: cursor-agent does NOT clear
  # an inherited CLAUDECODE, so a cursor worker launched from a claude primary
  # carries BOTH markers and whichever is tested first wins. Cursor's own
  # markers are unambiguous when present.
  [ "${CURSOR_AGENT:-}" = "1" ] && { echo cursor; return; }
  [ "${CURSOR_INVOKED_AS:-}" = "cursor-agent" ] && { echo cursor; return; }
  [ "${CLAUDECODE:-}" = "1" ] && { echo claude; return; }
  if [ "${PI_CODING_AGENT:-}" = "true" ]; then
    if [ "${BROKK_PI_HARNESS:-}" = pi-signed ]; then echo pi-signed; else echo pi; fi
    return
  fi
  # grok sets GROK_AGENT=1 for its child/tool processes (verified, grok 0.2.73).
  # It does NOT set CLAUDECODE despite being Claude-Code-compatible, so the
  # marker is unambiguous WHEN PRESENT. A grok hook process carries
  # GROK_HOOK_EVENT/GROK_HOOK_NAME instead, so treat this as a fast path only;
  # the ancestry walk below is what reliably identifies grok.
  [ "${GROK_AGENT:-}" = "1" ] && { echo grok; return; }
  # codex, opencode, and kimi publish no verified harness-identity marker, so
  # they are detected by ancestry alone below.
  #
  # Layer 2: walk the parent chain and match the command name.
  local pid=$$ comm args argv0
  for _ in 1 2 3 4 5 6 7 8; do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null) || break
    argv0=$(hamr_cursor_argv0_for_pid "$pid" "$comm" 2>/dev/null || true)
    if hamr_cursor_process_matches "$comm" "$argv0"; then
      echo cursor
      return
    fi
    case "$(basename -- "$comm")" in
      *claude*) echo claude; return ;;
      *codex*) echo codex; return ;;
      *opencode*) echo opencode; return ;;
      *grok*) echo grok; return ;;
      kimi) echo kimi; return ;;
      pi-signed) echo pi; return ;;
      pi) echo pi; return ;;
      node*|python*)
        # Bare interpreter: match the harness name in its script path.
        args=$(ps -o args= -p "$pid" 2>/dev/null)
        case "$args" in
          *claude*) echo claude; return ;;
          *codex*) echo codex; return ;;
          *opencode*) echo opencode; return ;;
          *grok*) echo grok; return ;;
          *" pi "*|*/pi) echo pi; return ;;
        esac ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -z "$pid" ] || [ "$pid" -le 1 ]; then
      break
    fi
  done
  echo unknown
}

# Print the first non-empty, non-comment line of config/eindri-harness
# (leading/trailing whitespace trimmed), or nothing when the file is absent or
# holds only blank/comment lines.
eindri_line() {
  local line
  [ -f "$CONFIG/eindri-harness" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] || continue
    case "$line" in
      '#'*) continue ;;
    esac
    printf '%s\n' "$line"
    return 0
  done < "$CONFIG/eindri-harness"
}

# Print the 1-based whitespace-separated token (1=harness, 2=model, 3=effort) of
# the resolved eindri_line, or nothing if the line or that field is absent.
eindri_field() {
  local idx=$1 line
  line=$(eindri_line)
  [ -n "$line" ] || return 0
  # shellcheck disable=SC2086  # deliberate word-splitting: tokenizing the line into fields
  set -- $line
  case "$idx" in
    1) printf '%s\n' "${1:-}" ;;
    2) printf '%s\n' "${2:-}" ;;
    3) printf '%s\n' "${3:-}" ;;
  esac
}

# Resolve the effective Eindri harness: config/eindri-harness wins; absent or
# "default" mirrors Brokk's own harness.
resolve_eindri() {
  local harness
  harness=$(eindri_field 1)
  if [ -z "$harness" ] || [ "$harness" = "default" ]; then detect_own; else echo "$harness"; fi
}

# Print the optional model token (2nd field) from config/eindri-harness, or
# empty when the harness token is absent/"default" or no model token is present.
resolve_eindri_model() {
  local harness
  harness=$(eindri_field 1)
  [ -n "$harness" ] && [ "$harness" != "default" ] || return 0
  eindri_field 2
}

# Print the optional effort token (3rd field) from config/eindri-harness, the
# same way.
resolve_eindri_effort() {
  local harness
  harness=$(eindri_field 1)
  [ -n "$harness" ] && [ "$harness" != "default" ] || return 0
  eindri_field 3
}

case "${1:-}" in
  eindri) resolve_eindri ;;
  eindri-model) resolve_eindri_model ;;
  eindri-effort) resolve_eindri_effort ;;
  *) detect_own ;;
esac
