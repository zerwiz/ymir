#!/usr/bin/env bash
# rodd-operational-input.sh - canonical Rödd operational-input protocol.
#
# Rödd ("voice") is the structured message wire between the Brokk primary and
# Ymir's workers. Ported from the upstream agent-distro reference for the Brokk
# distro runtime (docs/plans/29-brokk-distro-runtime.md). This file is both a
# source-safe shell library and the cross-language CLI used by the .pi / .opencode
# integrations.
#
# Current generic wire form:
#   U+2063 RODD_OP: v1 <kind>: <body>
#
# The version and kind header make current inputs structurally typed without
# deriving provenance from body prose. The from-brokk routing marker is the
# primary->worker compatibility carrier.
#
# CLI:
#   rodd-operational-input.sh encode <kind>  # body on stdin, encoded stdout
#   rodd-operational-input.sh kind           # current input on stdin, kind stdout
#   rodd-operational-input.sh classify       # current or legacy input on stdin
#   rodd-operational-input.sh body           # current generic input on stdin
#   rodd-operational-input.sh --help
#
# All successful data commands print exactly one value and no diagnostics.
# A non-match exits 1 silently. Invalid use exits 2. Bash 3.2 compatible.

RODD_MARK=$'\xE2\x81\xA3'
RODD_PREFIX="${RODD_MARK}RODD_OP: "
RODD_VERSION=v1
RODD_HEADER_PREFIX="${RODD_PREFIX}${RODD_VERSION} "
RODD_KINDS='session-start watcher turn-end-guard away-supervisor launch-brief branch-outcome'

# Compatibility name retained for the away-mode owner and its tests.
# shellcheck disable=SC2034 # Public source-library variable used by callers.
RODD_INJECT_MARK=$RODD_MARK

# The from-brokk carrier marks worker-directed guidance from the primary.
RODD_FROMBROKK_LABEL='[brokk-from-primary]'
RODD_FROMBROKK_SEPARATOR=$RODD_MARK
RODD_FROMBROKK_MARK="${RODD_FROMBROKK_LABEL}${RODD_FROMBROKK_SEPARATOR}"

rodd_kind_is_current() {  # <kind>
  case " $RODD_KINDS " in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

rodd_input_encode() {  # <generic-kind> <body> <result-var>
  local kind=${1-} body=${2-} result_var=${3-}
  [ -n "$result_var" ] || return 2
  rodd_kind_is_current "$kind" || return 2
  [ -n "$body" ] || return 2
  printf -v "$result_var" '%s%s: %s' "$RODD_HEADER_PREFIX" "$kind" "$body"
}

rodd_input_construct() {  # <kind> <body> <result-var>
  local kind=${1-} body=${2-} result_var=${3-}
  [ -n "$result_var" ] && [ -n "$body" ] || return 2
  if [ "$kind" = from-brokk ]; then
    rodd_message_mark_from_brokk "$body" "$result_var"
    return
  fi
  rodd_input_encode "$kind" "$body" "$result_var"
}

rodd_generic_kind() {  # <message> <result-var>
  local message=${1-} result_var=${2-} remainder parsed_kind body
  [ -n "$result_var" ] || return 2
  case "$message" in
    "$RODD_HEADER_PREFIX"*': '?*) ;;
    *) return 1 ;;
  esac
  remainder=${message#"$RODD_HEADER_PREFIX"}
  parsed_kind=${remainder%%': '*}
  rodd_kind_is_current "$parsed_kind" || return 1
  body=${remainder#"${parsed_kind}: "}
  [ "$body" != "$remainder" ] && [ -n "$body" ] || return 1
  printf -v "$result_var" '%s' "$parsed_kind"
}

rodd_input_kind() {  # <message> <result-var>
  local message=${1-} result_var=${2-} current_kind
  [ -n "$result_var" ] || return 2
  if rodd_generic_kind "$message" current_kind; then
    printf -v "$result_var" '%s' "$current_kind"
    return 0
  fi
  case "$message" in
    "$RODD_FROMBROKK_MARK"?*)
      printf -v "$result_var" '%s' from-brokk
      return 0
      ;;
  esac
  return 1
}

rodd_input_body() {  # <current-message> <result-var>
  local message=${1-} result_var=${2-} current_kind parsed_body
  [ -n "$result_var" ] || return 2
  if rodd_generic_kind "$message" current_kind; then
    parsed_body=${message#"${RODD_HEADER_PREFIX}${current_kind}: "}
    printf -v "$result_var" '%s' "$parsed_body"
    return 0
  fi
  case "$message" in
    "$RODD_FROMBROKK_MARK"?*)
      parsed_body=${message#"$RODD_FROMBROKK_MARK"}
      printf -v "$result_var" '%s' "$parsed_body"
      return 0
      ;;
  esac
  return 1
}

# Historical payload literals are intentionally isolated below this line.
# They exist only for persisted pre-protocol transcripts and must never be used
# by current producers or current-path tests.
# shellcheck disable=SC2016 # Backticks are literal historical prompt markup.
RODD_LEGACY_SESSIONSTART='Run `bin/saga-session-start.sh` now, exactly once, before executing any other instructions.'
RODD_LEGACY_WATCHER_PREFIX='BROKK WATCHER WAKE: '
RODD_LEGACY_WATCHER_SUFFIX=$'\n\nRun bin/saga-wake-drain.sh first and handle the queued wake. Watcher continuity is extension-owned.'
RODD_LEGACY_TURNEND_PREFIX=$'TURN WOULD END BLIND - supervision is off. The watcher cycle is missing, failed, or unhealthy. Follow the harness recovery instruction below before ending the turn.\n\n'
RODD_LEGACY_AWAY_PREFIX="${RODD_MARK}Supervisor escalate ("

rodd_legacy_kind() {  # <message> <result-var>
  local message=${1-} result_var=${2-}
  [ -n "$result_var" ] || return 2

  case "$message" in
    "$RODD_PREFIX"?*)
      printf -v "$result_var" '%s' legacy-operational
      return 0
      ;;
  esac

  if [ "$message" = "$RODD_LEGACY_SESSIONSTART" ]; then
    printf -v "$result_var" '%s' session-start
    return 0
  fi
  case "$message" in
    "$RODD_LEGACY_AWAY_PREFIX"*)
      printf -v "$result_var" '%s' away-supervisor
      return 0
      ;;
    "$RODD_LEGACY_WATCHER_PREFIX"*"$RODD_LEGACY_WATCHER_SUFFIX")
      [ "${#message}" -gt "$(( ${#RODD_LEGACY_WATCHER_PREFIX} + ${#RODD_LEGACY_WATCHER_SUFFIX} ))" ] || return 1
      printf -v "$result_var" '%s' watcher
      return 0
      ;;
    "$RODD_LEGACY_TURNEND_PREFIX"?*)
      printf -v "$result_var" '%s' turn-end-guard
      return 0
      ;;
  esac
  return 1
}

rodd_classify() {  # <message> <result-var>
  local message=${1-} result_var=${2-} classified_kind
  [ -n "$result_var" ] || return 2
  if rodd_input_kind "$message" classified_kind ||
     rodd_legacy_kind "$message" classified_kind; then
    printf -v "$result_var" '%s' "$classified_kind"
    return 0
  fi
  return 1
}

rodd_message_from_brokk() {  # <message>
  local kind
  rodd_input_kind "${1-}" kind && [ "$kind" = from-brokk ]
}

rodd_message_mark_from_brokk() {  # <message> <result-var>
  local message=${1-} result_var=${2-} transformed
  [ -n "$result_var" ] || return 2
  if rodd_message_from_brokk "$message"; then
    transformed=$message
  else
    transformed="${RODD_FROMBROKK_MARK}${message}"
  fi
  printf -v "$result_var" '%s' "$transformed"
}

rodd_read_stdin() {  # <result-var>
  local result_var=${1-} value
  [ -n "$result_var" ] || return 2
  value=$(cat; printf x)
  value=${value%x}
  printf -v "$result_var" '%s' "$value"
}

rodd_usage() {
  cat <<'EOF'
Usage:
  bin/rodd-operational-input.sh encode <kind>  # body on stdin
  bin/rodd-operational-input.sh kind           # current input on stdin
  bin/rodd-operational-input.sh classify       # current or legacy input on stdin
  bin/rodd-operational-input.sh body           # current input on stdin

Current construction kinds:
  session-start watcher turn-end-guard away-supervisor from-brokk launch-brief
  branch-outcome

The from-brokk kind uses the primary->worker compatibility carrier.
EOF
}

rodd_main() {
  local command=${1-} argument=${2-} input output
  case "$command" in
    -h|--help|help)
      rodd_usage
      ;;
    encode)
      [ "$#" -eq 2 ] || return 2
      rodd_read_stdin input || return 2
      rodd_input_construct "$argument" "$input" output || return 2
      printf '%s' "$output"
      ;;
    kind)
      [ "$#" -eq 1 ] || return 2
      rodd_read_stdin input || return 2
      rodd_input_kind "$input" output || return 1
      printf '%s\n' "$output"
      ;;
    classify)
      [ "$#" -eq 1 ] || return 2
      rodd_read_stdin input || return 2
      rodd_classify "$input" output || return 1
      printf '%s\n' "$output"
      ;;
    body)
      [ "$#" -eq 1 ] || return 2
      rodd_read_stdin input || return 2
      rodd_input_body "$input" output || return 1
      printf '%s' "$output"
      ;;
    *)
      rodd_usage >&2
      return 2
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  rodd_main "$@"
  exit $?
fi
