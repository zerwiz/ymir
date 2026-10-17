#!/usr/bin/env bash
# well-guard.sh — the WARD behind RULES/20-the-well-appends.md.
#
# The well is the fleet's memory. It APPENDS: an episode is written once and
# stays. This ward exists because on 2026-10-07 a corrupt store was salvaged with
# `sqlite3 .recover`, 36 episodes were unreadable, and nothing noticed — the store
# shrank by a third and the loss rode the vault for ten days.
#
#   well-guard.sh check         # is the well whole? (exit 1 = a loss or a junk write)
#   well-guard.sh record        # roll the checkpoint forward (after a passing check)
#   well-guard.sh --self-test   # prove the ward FAILS when an episode disappears
#
# What it refuses, and why:
#   * the episode count FALLING below the checkpoint — a store was replaced,
#     rebuilt, restored-over, or trimmed. Never legitimate.
#   * the append log's line count FALLING — the log is the truth; a shrinking
#     log means records were dropped from the record itself.
#   * an episode whose content is empty or the literal string `undefined` — a
#     caller serialised a missing field; the store must not quietly keep junk.
#   * episodes with no vector, when the engram interpreter can measure it — an
#     unindexed memory is in the record but invisible to recall, which is a
#     silent half-loss.
#
# Exit: 0 whole · 1 a loss/junk/unindexed · 2 usage.
set -u

VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _w in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/hoard-lib.sh" "$ROOT/bin/vault/hoard-lib.sh"; do
    [ -r "$_w" ] && { . "$_w"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _w
fi

home=""
if [ -n "${YMIR_HOME:-}" ]; then home="$YMIR_HOME"
elif command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root home
else
  printf 'error: cannot resolve the home\nhelp: bin/vault/hoard-lib.sh must be reachable (YMIR_HOME, or the recorded choice)\n' >&2
  exit 2
fi

STORE="${WELL_STORE:-$home/hodd/memory/kaia.engram}"
LOG="${WELL_LOG:-$home/hodd/memory/well/episodes.jsonl}"
STATE="${YMIR_STATE_DIR:-$home/state}"
CHECKPOINT="$STATE/well-guard.json"

# The counts. python3 stdlib opens the plain tables; the vec0 index needs the
# engram interpreter, so the unindexed count is measured only when there is one.
counts() {  # -> "episodes junk"
  python3 - "$STORE" <<'PY' 2>/dev/null || echo "0 0"
import sqlite3, sys
try:
    c = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
    n = c.execute("select count(*) from episodes").fetchone()[0]
    # A row declared void by an appended correction (tag `void:`) is recorded,
    # not counted: the record keeps it, the ward does not nag about it.
    j = c.execute("select count(*) from episodes where instr(coalesce(tags,'[]'),'void:')=0"
                  " and (trim(coalesce(content,''))='' or trim(content)='undefined')").fetchone()[0]
    print(n, j)
except Exception:
    print("ERR ERR")
PY
}

log_lines() {  # the append log's line count (0 when absent)
  [ -r "$LOG" ] || { printf '0'; return; }
  wc -l <"$LOG" | tr -d '[:space:]'
}

# The engram interpreter prints itself; without it the vec measure is skipped.
engram_python() {
  if [ -x "$ROOT/bin/bridge/mimir-bridge.sh" ]; then
    "$ROOT/bin/bridge/mimir-bridge.sh" --python 2>/dev/null && return 0
  fi
  return 1
}

unindexed() {  # episodes with no vec row; empty when it cannot be measured
  local py; py="$(engram_python)" || return 0
  [ -n "$py" ] || return 0
  "$py" - "$STORE" <<'PY' 2>/dev/null
import sqlite3, sys
try:
    c = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
    if not c.execute("select 1 from sqlite_master where name='vec_episodes'").fetchone():
        raise SystemExit(0)          # no vector index in this store: nothing to measure
    c.close()
    from engram import Engram
    r = Engram(path=sys.argv[1], agent_id=None)._store._conn.execute(
        "select count(*) from episodes e where instr(coalesce(e.tags,'[]'),'void:')=0"
        " and not exists(select 1 from vec_episodes v where v.rowid = e.rowid)")
    print(r.fetchone()[0])
except Exception:
    pass
PY
}

read_cp() {  # <key> -> the recorded value, empty when there is no checkpoint
  [ -r "$CHECKPOINT" ] || return 0
  python3 - "$CHECKPOINT" "$1" <<'PY' 2>/dev/null
import json, sys
try: print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))
except Exception: pass
PY
}

cmd_check() {
  set -- $(counts); local eps=${1:-ERR} junk=${2:-0}
  local lines; lines="$(log_lines)"
  local cp_eps cp_lines
  cp_eps="$(read_cp episodes)"; cp_lines="$(read_cp log_lines)"
  local fails=0
  if [ "$eps" = "ERR" ]; then
    printf 'well-unreadable[1]{store,detail}:\n  "%s","the store cannot be read at all — that is a loss until proven otherwise."\n' "$STORE"
    return 1
  fi
  printf 'well[1]{store,episodes,log_lines,junk,unindexed}:\n'
  printf '  "%s",%s,%s,%s,%s\n' "$STORE" "$eps" "$lines" "$junk" "$(unindexed)"

  if [ -n "$cp_eps" ] && [ "$eps" -lt "$cp_eps" ]; then
    printf 'well-loss[1]{kind,now,before,detail}:\n  "episodes",%s,%s,"the well SHRANK — a store was replaced, rebuilt or trimmed. The law is APPEND (RULES/20)."\n' "$eps" "$cp_eps"
    fails=$((fails+1))
  fi
  if [ -n "$cp_lines" ] && [ "$lines" -lt "$cp_lines" ]; then
    printf 'well-loss[1]{kind,now,before,detail}:\n  "log_lines",%s,%s,"the append log lost lines — the record itself was rewritten."\n' "$lines" "$cp_lines"
    fails=$((fails+1))
  fi
  if [ "$junk" -gt 0 ]; then
    printf 'well-junk[1]{count,detail}:\n  %s,"episodes whose content is empty or `undefined` — a caller serialised a missing field; tag them void, never erase them (append-only)."\n' "$junk"
    fails=$((fails+1))
  fi
  local un; un="$(unindexed)"
  if [ -n "$un" ] && [ "$un" -gt 0 ]; then
    printf 'well-unindexed[1]{count,detail}:\n  %s,"episodes with no vector — in the record, invisible to recall."\n' "$un"
    fails=$((fails+1))
  fi
  [ "$fails" -eq 0 ] && printf 'well-guard: whole (%s episodes, %s log lines)\n' "$eps" "$lines"
  return $(( fails > 0 ))
}

cmd_record() {
  cmd_check || return 1
  set -- $(counts); local eps=${1:-0} junk=${2:-0}
  local lines; lines="$(log_lines)"
  mkdir -p "$STATE" || return 1
  python3 - "$CHECKPOINT" "$eps" "$lines" "$junk" <<'PY'
import json, sys, time
path, eps, lines, junk = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
try: prev = json.load(open(path))
except Exception: prev = {}
doc = {"episodes": eps, "log_lines": lines, "junk": junk,
       "checked_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
       "previous": {"episodes": prev.get("episodes"), "log_lines": prev.get("log_lines"),
                    "checked_at": prev.get("checked_at")}}
json.dump(doc, open(path, "w"), indent=2)
PY
  printf 'well-guard: checkpoint recorded — %s episodes, %s log lines (%s)\n' "$eps" "$lines" "$CHECKPOINT"
}

cmd_self_test() {
  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp:-}"' EXIT
  mkdir -p "$tmp/hodd/memory/well" "$tmp/state"
  python3 - "$tmp/hodd/memory/kaia.engram" <<'PY'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
c.execute("create table episodes (id text primary key, content text, timestamp text,"
          " tags text default '[]')")
c.executemany("insert into episodes values (?,?,?,'[]')",
              [(str(i), f"episode {i}", "2026-10-17T00:00:00+00:00") for i in range(5)])
c.commit()
PY
  printf 'a\nb\nc\nd\ne\n' >"$tmp/hodd/memory/well/episodes.jsonl"
  local rc=0
  YMIR_HOME="$tmp" YMIR_STATE_DIR="$tmp/state" bash "${BASH_SOURCE[0]}" record >/dev/null 2>&1 || rc=1
  printf '  record a 5-episode well: %s\n' "$([ $rc -eq 0 ] && echo ok || echo FAIL)"
  YMIR_HOME="$tmp" YMIR_STATE_DIR="$tmp/state" bash "${BASH_SOURCE[0]}" check >/dev/null 2>&1 || rc=1
  printf '  check a whole well:      %s\n' "$([ $rc -eq 0 ] && echo ok || echo FAIL)"
  python3 - "$tmp/hodd/memory/kaia.engram" <<'PY'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1]); c.execute("delete from episodes where id='4'"); c.commit()
PY
  if YMIR_HOME="$tmp" YMIR_STATE_DIR="$tmp/state" bash "${BASH_SOURCE[0]}" check >/dev/null 2>&1; then
    printf '  check after an episode is REMOVED: FAIL (the ward did not bite)\n'; rc=1
  else
    printf '  check after an episode is REMOVED: ok (the ward bit)\n'
  fi
  [ "$rc" -eq 0 ] && printf 'well-guard --self-test: PASS\n' || printf 'well-guard --self-test: FAIL\n'
  return $rc
}

case "${1:-check}" in
  check)       cmd_check ;;
  record)      cmd_record ;;
  --self-test) cmd_self_test ;;
  --version)   printf 'well-guard %s\n' "$VERSION" ;;
  *) printf 'usage: well-guard.sh [check|record|--self-test] [--version]\n' >&2; exit 2 ;;
esac
