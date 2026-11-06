#!/usr/bin/env bash
# utgard-lane.sh — best of N: one brief, many boxes, one board.
#
# The point of a lane is COMPARISON, not speed. The same brief goes to N boxes
# that differ in exactly one intended way, each box runs the same factory, and
# what comes back is a board you can read in under a minute: what each lane did,
# what it cost, how long it took, and which one you would ship.
#
# The rail serves ONE model on ONE request stream (`--models-max 1`,
# `parallel = 1`), so lanes do NOT run their inference at once — they queue on a
# LEASE. Parallel on files, serial on the model: anything else thrashes the swap
# and pays a reload per lane, which is a slower and more expensive lie.
#
# The axis that is cheapest to vary is the HARNESS and the PROMPT; the second is
# WHICH MODEL; the third is WHERE the model lives — this box's rail, or another
# machine's over the tailnet. All three are declared per lane.
#
# Usage:
#   utgard-lane.sh new <name> --brief <file> --lane <spec> [--lane <spec>…]
#                              [--ttl 4h] [--budget N] [--command "<cmd>"] [--seal door|none]
#   utgard-lane.sh run <name>            # take the lease, run every lane in turn
#   utgard-lane.sh board <name>          # the comparison board
#   utgard-lane.sh list                  # the lanes that exist
#   utgard-lane.sh rm <name>             # tear the lanes down (revokes each door)
#   utgard-lane.sh --version
#
# A <spec> is `label=model[@where]`, where `where` is `local` (default) or
# `tailnet`. A tailnet lane needs UTGARD_LANE_TAILNET_TARGET set (host:port),
# because an address is never written into a script (RULES/39, Rule 07).
#
# Exit: 0 ok · 1 error · 2 usage · 3 refused.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
BOX="$SCRIPT_DIR/utgard-box.sh"
PREFIX="${UTGARD_BOX_PREFIX:-utgard}"
LEASE="${UTGARD_LANE_LEASE:-$ROOT/state/utgard-lane.lock}"
STATE_CMD="${UTGARD_LANE_SCRATCH:-${TMPDIR:-/tmp}/.ymir-lane-command}"
DEFAULT_COMMAND="${UTGARD_LANE_COMMAND:-python3 /box/factory/smidja_plan_build_test.py /box/brief.md}"

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
refuse() { printf 'refused: %s\n' "$*" >&2; exit 3; }

# Every box of one lane, in index order, as `index<TAB>container`.
lane_boxes() {
  local lane="$1"
  "$ENGINE" ps -a --filter "label=ymir.utgard.lane=$lane" \
    --format '{{.Label "ymir.utgard.lane_index"}}\t{{.Names}}' 2>/dev/null | sort -n
}

cmd_new() {
  local name="" brief="" ttl="4h" budget="0" command="$DEFAULT_COMMAND" seal="door"
  local -a specs=()
  while [ $# -gt 0 ]; do case "$1" in
    --brief) brief=${2-}; shift 2 ;;
    --lane) specs+=("${2-}"); shift 2 ;;
    --ttl) ttl=${2-}; shift 2 ;;
    --budget) budget=${2-}; shift 2 ;;
    --command) command=${2-}; shift 2 ;;
    --seal) seal=${2-}; shift 2 ;;
    -*) die "new: unknown flag $1" ;;
    *) name=$1; shift ;;
  esac; done
  [ -n "$name" ] || die "new: a lane needs a name
help: utgard lane new sprint1 --brief task.md --lane 'a=qwen3.6-35b' --lane 'b=gemma-4-12b'"
  [ -n "$brief" ] || die "new: --brief <file> is required — a lane without a brief is not a comparison"
  [ -r "$brief" ] || die "new: brief not found: $brief"
  [ "${#specs[@]}" -gt 0 ] || die "new: at least one --lane <label=model[@where]> is required"

  local i=0 spec label model where
  for spec in "${specs[@]}"; do
    label="${spec%%=*}"; model="${spec#*=}"
    [ "$label" != "$spec" ] || die "new: lane spec '$spec' is not label=model[@where]"
    [ -n "$model" ] || die "new: lane '$label' names no model"
    where="local"
    case "$model" in *@*) where="${model##*@}"; model="${model%@*}" ;; esac
    case "$where" in
      local) ;;
      tailnet)
        [ -n "${UTGARD_LANE_TAILNET_TARGET:-}" ] \
          || refuse "lane '$label' asks for a tailnet model, and no target is configured
help: export UTGARD_LANE_TAILNET_TARGET=host:port   (the address stays out of the scripts)"
        ;;
      *) die "new: lane '$label' has an unknown where '$where' (local|tailnet)" ;;
    esac

    local box; box="lane-$name-$i"
    local target="host.docker.internal:8080"
    [ "$where" = tailnet ] && target="$UTGARD_LANE_TAILNET_TARGET"
    UTGARD_BOX_RAIL_TARGET="$target" \
      "$BOX" new "$box" --ttl "$ttl" --seal "$seal" --model "$model" --budget "$budget" \
        --label "ymir.utgard.lane=$name" \
        --label "ymir.utgard.lane_index=$i" \
        --label "ymir.utgard.lane_label=$label" \
        --label "ymir.utgard.lane_model=$model" \
        --label "ymir.utgard.lane_where=$where" \
      >/dev/null 2>&1 || die "new: lane '$label' could not raise its box ($box)"

    # The brief and the command travel as copies, never as mounts.
    local c="$PREFIX-$box"
    "$ENGINE" cp "$brief" "$c:/box/brief.md" >/dev/null 2>&1 \
      || die "new: lane '$label' could not take the brief"
    printf '%s' "$command" > "$STATE_CMD"
    "$ENGINE" cp "$STATE_CMD" "$c:/box/.lane-command" >/dev/null 2>&1 \
      || die "new: lane '$label' could not take its command"
    "$BOX" factory "$box" >/dev/null 2>&1 || printf 'warn: lane %s has no factory seated\n' "$label" >&2

    printf 'lane[5]{index,label,model,where,box}:\n  "%s","%s","%s","%s","%s"\n' \
      "$i" "$label" "$model" "$where" "$box"
    i=$(( i + 1 ))
  done
  printf 'lanes[2]{name,count}:\n  "%s","%s"\n' "$name" "$i"
  printf 'next: utgard lane run %s   (one lease, lanes in turn)\n' "$name"
}

cmd_run() {
  local name="${1-}"; [ -n "$name" ] || die "run: which lane?"
  local rows; rows="$(lane_boxes "$name")" || die "run: no lane named $name"
  [ -n "$rows" ] || die "run: lane $name has no boxes
help: utgard lane new $name --brief … --lane …"

  mkdir -p "$(dirname "$LEASE")"
  printf 'lane[2]{name,lease}:\n  "%s","%s"\n' "$name" "$LEASE"

  # ONE lease for the whole lane run: the rail serves one model at a time, so the
  # lanes queue here rather than thrashing the swap.
  exec 9>"$LEASE"
  if ! flock -n 9; then
    printf 'waiting: another lane holds the rail lease — queuing\n'
    flock 9
  fi

  local index c label model where started ended wall rc
  printf 'run[6]{index,label,model,where,wall_s,exit}:\n'
  while IFS=$'\t' read -r index c; do
    [ -n "$c" ] || continue
    label="$("$ENGINE" inspect --format '{{ index .Config.Labels "ymir.utgard.lane_label" }}' "$c" 2>/dev/null)"
    model="$("$ENGINE" inspect --format '{{ index .Config.Labels "ymir.utgard.lane_model" }}' "$c" 2>/dev/null)"
    where="$("$ENGINE" inspect --format '{{ index .Config.Labels "ymir.utgard.lane_where" }}' "$c" 2>/dev/null)"
    started="$(date +%s)"
    "$ENGINE" exec "$c" bash -lc 'cmd="$(cat /box/.lane-command 2>/dev/null)"; mkdir -p /box/lane; { eval "$cmd"; } >/box/lane/out.log 2>&1' >/dev/null 2>&1
    rc=$?
    ended="$(date +%s)"; wall=$(( ended - started ))
    printf '%s\t%s\t%s\t%s\t%s' "$rc" "$wall" "$label" "$model" "$where" \
      | "$ENGINE" exec -i "$c" bash -lc 'cat > /box/lane/result.tsv' >/dev/null 2>&1 || true
    printf '  "%s","%s","%s","%s","%s","%s"\n' "$index" "$label" "$model" "$where" "$wall" "$rc"
  done <<EOF
$rows
EOF
  printf 'next: utgard lane board %s\n' "$name"
}

cmd_board() {
  local name="${1-}"; [ -n "$name" ] || die "board: which lane?"
  local rows; rows="$(lane_boxes "$name")" || die "board: no lane named $name"
  [ -n "$rows" ] || die "board: lane $name has no boxes"
  printf 'board[6]{lane,label,model,where,wall_s,one_line}:\n'
  local index c label model where rc wall line
  while IFS=$'\t' read -r index c; do
    [ -n "$c" ] || continue
    label="$("$ENGINE" inspect --format '{{ index .Config.Labels "ymir.utgard.lane_label" }}' "$c" 2>/dev/null)"
    model="$("$ENGINE" inspect --format '{{ index .Config.Labels "ymir.utgard.lane_model" }}' "$c" 2>/dev/null)"
    where="$("$ENGINE" inspect --format '{{ index .Config.Labels "ymir.utgard.lane_where" }}' "$c" 2>/dev/null)"
    IFS=$'\t' read -r rc wall _l _m _w < <("$ENGINE" exec "$c" bash -lc 'cat /box/lane/result.tsv 2>/dev/null' 2>/dev/null) || true
    line="$("$ENGINE" exec "$c" bash -lc 'tail -1 /box/lane/out.log 2>/dev/null | cut -c1-90' 2>/dev/null)"
    [ -n "${wall:-}" ] || wall="-"
    [ -n "${rc:-}" ] || rc="-"
    case "${rc:-}" in
      0) line="${line:-done}" ;;
      -) line="${line:-not run}" ;;
      *) line="FAILED($rc): ${line}" ;;
    esac
    printf '  "%s","%s","%s","%s","%s","%s"\n' "$index" "$label" "$model" "$where" "$wall" "$line"
  done <<EOF
$rows
EOF
  printf 'his: the board ends in HIS pick — no lane merges itself (Rule 08)\n'
}

cmd_list() {
  local names; names="$("$ENGINE" ps -a --filter "label=ymir.utgard.lane" \
    --format '{{.Label "ymir.utgard.lane"}}' 2>/dev/null | sort -u | grep -v '^$' || true)"
  local count=0; [ -n "$names" ] && count="$(printf '%s\n' "$names" | wc -l | tr -d ' ')"
  printf 'lanes[%s]{name,boxes}:\n' "$count"
  local n
  for n in $names; do
    printf '  "%s","%s"\n' "$n" "$("$ENGINE" ps -a --filter "label=ymir.utgard.lane=$n" --format '{{.Names}}' 2>/dev/null | wc -l | tr -d ' ')"
  done
}

cmd_rm() {
  local name="${1-}"; [ -n "$name" ] || die "rm: which lane?"
  local index c removed=0
  while IFS=$'\t' read -r index c; do
    [ -n "$c" ] || continue
    "$BOX" revoke "${c#"$PREFIX"-}" >/dev/null 2>&1 || true
    "$BOX" rm "${c#"$PREFIX"-}" >/dev/null 2>&1 || true
    removed=$(( removed + 1 ))
  done <<EOF
$(lane_boxes "$name")
EOF
  printf 'lane[2]{name,removed}:\n  "%s","%s"\n' "$name" "$removed"
}

CMD="${1-}"; shift || true
case "$CMD" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|help|"") usage; exit 0 ;;
esac
# One engine, resolved once (Rule 07): every verb asks the same door.
. "$SCRIPT_DIR/../fleet/ymir-platform.sh"
ENGINE="$(ymir_container_engine)" || die "no container engine (docker/podman) reachable
help: install Docker or Podman, or set YMIR_CONTAINER_ENGINE to the one you use"

case "$CMD" in
  new)   cmd_new "$@" ;;
  run)   cmd_run "$@" ;;
  board) cmd_board "$@" ;;
  list|ls) cmd_list "$@" ;;
  rm)    cmd_rm "$@" ;;
  *) printf 'error: unknown verb %s\nhelp: utgard lane [new|run|board|list|rm]\n' "$CMD" >&2; exit 2 ;;
esac
