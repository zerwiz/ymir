#!/usr/bin/env bash
# snotra-ladder.sh — the meeting ladder: transcript → minutes → promises → todos, and a stop that says so.
#
#   snotra-ladder.sh run <id-or-folder> [--dry-run]   walk the ladder for one meeting
#   snotra-ladder.sh run --pending [--limit N]        every meeting with a transcript and no minutes
#   snotra-ladder.sh status <id-or-folder>            where this meeting stands, in words
#   snotra-ladder.sh steps                            the ladder itself, and what each rung proves
#   snotra-ladder.sh --self-test                      prove a finished run and a failed step, on a fixture
#
# WHY (plan 228 §3 · F2, plan 111's ladder, plan 112 §18): the ear recorded, transcribed, and
# then STOPPED — `meetings.sh totals` read `3 meetings · 2 transcripts · 0 minutes · 0 promises`,
# and nothing said so. A pipeline that stops silently is indistinguishable from one that works.
# So every rung proves itself or names itself, the meeting's own `.state` carries the sentence
# `stopped at <step>: <reason>`, and the hotline hears about it.
#
# THE LADDER, in this order:
#   transcript  the words beside the recording (transcribed on the seat when only audio exists)
#   minutes     composed BY THE MODEL from the transcript and the people present, into the
#               meeting's own folder
#   promises    every promise the minutes carry, written as a list in the same folder
#   todos       every promise filed as a todo through bin/records/todos.sh (the board's ONE writer)
#
# Env (all resolved, never hardcoded — Rule 07):
#   YMIR_HOME                  the home (through bin/vault/hoard-lib.sh)
#   SNOTRA_MINUTES_COMPOSER    the command that composes minutes: <cmd> <transcript> <people> →
#                              minutes on stdout. Default: the living rail (bin/model/rail-resolve.sh)
#   SNOTRA_LADDER_NOTIFY_LOG   write hotline lines here instead of sending (tests, and a quiet ops run)
#   SNOTRA_LADDER_QUIET=1      no hotline at all
#
# Exit: 0 the ladder finished · 1 a step failed (its reason is in the meeting's `.state`) · 2 usage
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  # shellcheck disable=SC1091
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi
[ -n "${YMIR_HOME:-}" ] || { printf 'snotra-ladder: the home is unresolved — bin/vault/hoard-lib.sh answered nothing\n' >&2; exit 2; }

MEETINGS_DOOR="$ROOT/bin/records/meetings.sh"
TODO_DOOR="$ROOT/bin/records/todos.sh"
TRANSCRIBE_DOOR="$ROOT/systems/snotra/services/ear/snotra-transcribe.sh"
RAIL_DOOR="$ROOT/bin/model/rail-resolve.sh"
RUNES_DOOR="$ROOT/bin/records/runes-append.sh"
STEP_TIMEOUT="${SNOTRA_LADDER_TIMEOUT:-900}"

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

# ── the hotline: a step that finishes or fails is news the house hears ──────
hotline() {  # <severity> <message> <key>
  [ "${SNOTRA_LADDER_QUIET:-0}" = "1" ] && return 0
  if [ -n "${SNOTRA_LADDER_NOTIFY_LOG:-}" ]; then
    mkdir -p "$(dirname "$SNOTRA_LADDER_NOTIFY_LOG")" 2>/dev/null || true
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" >>"$SNOTRA_LADDER_NOTIFY_LOG"
    return 0
  fi
  [ -x "$ROOT/bin/notify/send.sh" ] || return 0
  "$ROOT/bin/notify/send.sh" --source snotra --severity "$1" --message "$2" --key "$3" >/dev/null 2>&1 || true
}

rune() {  # <message>
  [ -x "$RUNES_DOOR" ] || return 0
  "$RUNES_DOOR" snotra ladder --message "$1" >/dev/null 2>&1 || true
}

# ── the meeting's own folder, found through the index's one door ────────────
folder_of() {  # <id-or-folder>
  local key="$1"
  if [ -d "$key" ] && [ -f "$key/meeting.json" ]; then printf '%s\n' "$(cd "$key" && pwd)"; return 0; fi
  bash "$MEETINGS_DOOR" json 2>/dev/null | python3 -c '
import json, sys
key = sys.argv[1]
try:
    rows = json.load(sys.stdin)
except Exception:
    rows = []
for r in rows:
    if key and (key in (r.get("id") or "") or key in (r.get("folder") or "")):
        print(r.get("folder") or "")
        raise SystemExit(0)
raise SystemExit(1)
' "$key"
}

meeting_id() { basename "${1%/}"; }

meeting_title() { python3 -c '
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: d = {}
print(d.get("title") or sys.argv[2])
' "$1/meeting.json" "$(meeting_id "$1")"; }

meeting_people() { python3 -c '
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: d = {}
people = d.get("attendees") or d.get("participants") or []
out = []
for p in people:
    if isinstance(p, dict):
        out.append(p.get("name") or p.get("email") or "")
    else:
        out.append(str(p))
print(", ".join([x for x in out if x]))
' "$1/meeting.json"; }

state_write() {  # <folder> <state-line>
  local dir="$1" line="$2"
  printf '%s\n' "$line" >"$dir/.state.ladder.tmp" && mv "$dir/.state.ladder.tmp" "$dir/.state"
}

state_read() { cat "$1/.state" 2>/dev/null | head -1; }

find_transcript() {  # <folder> → path, or empty
  local dir="$1" f
  for f in "$dir/transcript.md" "$dir/by-house.md"; do
    [ -s "$f" ] && { printf '%s' "$f"; return 0; }
  done
  while IFS= read -r f; do
    case "$f" in *.txt|*.md) printf '%s' "$f"; return 0 ;; esac
  done < <(find "$dir" -maxdepth 1 -iname "*transcript*" -size +0c 2>/dev/null | sort)
  return 1
}

find_audio() {  # <folder> → path, or empty
  local dir="$1" f
  for f in "$dir/recording.wav" "$dir"/*.wav "$dir"/*.m4a "$dir"/*.ogg "$dir"/*.webm; do
    [ -s "$f" ] && { printf '%s' "$f"; return 0; }
  done
  if [ -d "$dir/audio" ]; then
    while IFS= read -r f; do [ -s "$f" ] && { printf '%s' "$f"; return 0; }; done < <(find "$dir/audio" -maxdepth 1 -type f 2>/dev/null | sort)
  fi
  return 1
}

find_minutes() {  # <folder> → path, or empty
  local dir="$1" f
  for f in "$dir/minutes.md" "$dir/minutes"*.md; do
    [ -s "$f" ] && { printf '%s' "$f"; return 0; }
  done
  return 1
}

# ── the rail: url · model · key, all resolved, and a loud refusal when absent ──
rail_json() {
  [ -x "$RAIL_DOOR" ] || return 1
  bash "$RAIL_DOOR" resolve --json 2>/dev/null
}

rail_key() {  # <key-ref>
  local ref="${1:-}" v=""
  [ -n "$ref" ] || return 0
  v="${!ref:-}"
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  if [ -x "$ROOT/bin/vault/hodd.sh" ]; then
    v="$(eval "$("$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null || true)"; printf '%s' "${!ref:-}")"
  fi
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  # the seat's own harness credential surface (a path, never a value in this repo)
  python3 -c '
import json, os, sys
path = os.path.expanduser("~/.pi/agent/auth.json")
try:
    d = json.load(open(path))
except Exception:
    raise SystemExit(0)
# WHICH provider's key: the rail's own name when the seat declares it ($RAIL_KEY_PROVIDERS,
# comma-separated, first match wins), else every provider the file holds. Never a list of
# this fleet's provider ids — a seat's own rail is its own business (RULES/04, RULES/25).
wanted = [x.strip() for x in os.environ.get("RAIL_KEY_PROVIDERS", "llama-swap").split(",") if x.strip()]
order = wanted + [k for k in d if k not in wanted]
for provider in order:
    key = (d.get(provider) or {}).get("key")
    if key:
        print(key); break
' 2>/dev/null
}

compose_minutes() {  # <folder> <transcript> <people> → minutes on stdout (or non-zero + reason on stderr)
  local dir="$1" transcript="$2" people="$3"
  if [ -n "${SNOTRA_MINUTES_COMPOSER:-}" ]; then
    # shellcheck disable=SC2086
    $SNOTRA_MINUTES_COMPOSER "$transcript" "$people" || return 1
    return 0
  fi
  local info url model keyref key title
  info="$(rail_json)" || { printf 'the rail resolver did not answer (bin/model/rail-resolve.sh)\n' >&2; return 1; }
  url="$(printf '%s' "$info" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
print((d.get("serving") or {}).get("url") or "")' 2>/dev/null)"
  # WHICH model: the seat's own choice first (the snotra unit sets SNOTRA_RAIL_MODEL to a
  # 9B summarizer window), then a caller's RAIL_MODEL, and only then the rail's models[0] —
  # which on this seat is a 21.7 GB model asked for a paragraph. Never a hardcoded id.
  model="${SNOTRA_RAIL_MODEL:-${RAIL_MODEL:-}}"
  if [ -z "$model" ] && command -v systemctl >/dev/null 2>&1; then
    # The seat's own choice lives in the watch unit's drop-in (never in this tree):
    # a hand-run ladder must compose with the same model the unit would.
    model="$(systemctl --user show "${SNOTRA_WATCH_UNIT:-snotra-detect.service}" -p Environment 2>/dev/null \
      | tr ' ' '\n' | sed -n 's/^SNOTRA_RAIL_MODEL=//p' | head -1)"
  fi
  if [ -z "$model" ]; then
    model="$(printf '%s' "$info" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
m=(d.get("serving") or {}).get("models") or []
print(m[0] if m else "")' 2>/dev/null)"
  fi
  keyref="$(printf '%s' "$info" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
print((d.get("serving") or {}).get("key_ref") or "")' 2>/dev/null)"
  [ -n "$url" ] || { printf 'no living rail answered — nothing can compose minutes\n' >&2; return 1; }
  [ -n "$model" ] || { printf 'the rail resolved no model — refusing to guess one\n' >&2; return 1; }
  key="$(rail_key "$keyref")"
  title="$(meeting_title "$dir")"

  local body status
  body="$(python3 - "$transcript" "$people" "$title" <<'PY'
import json, sys
transcript, people, title = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(transcript, encoding="utf-8", errors="replace").read()
limit = int(__import__("os").environ.get("SNOTRA_MINUTES_INPUT_CHARS", "48000"))
text = text[:limit]
system = (
    "You write minutes for a working meeting. You are given the transcript and the list of "
    "people invited. Write markdown with exactly these sections:\n"
    "# Minutes — <the meeting's title>\n"
    "## Present\n(the people given; if none were given, write `not named in the invitation`)\n"
    "## Decisions\n(one bullet per decision actually taken; quote the words that settle it)\n"
    "## Promises\n(one bullet per commitment: what is owed, by whom if the transcript names them, and when; "
    "format `- [ ] <what> · owner <who or unnamed> · due <date or unrepeated>`)\n"
    "## Notes\n(anything else the transcript establishes)\n"
    "RULES: use only what the transcript says. Never invent a name, a date or a decision. "
    "If the transcript establishes no decision, write `- none in the transcript`. "
    "If nobody promised anything, write `- none in the transcript`. Answer with the minutes only."
)
print(json.dumps({"model": None, "temperature": 0, "max_tokens": 1600,
                  "messages": [{"role": "system", "content": system},
                               {"role": "user", "content": "Meeting: " + title +
                                                      "\nPeople present: " + (people or "not named in the invitation") +
                                                      "\n\nTranscript:\n" + text}]}))
PY
)"
  local payload
  payload="$(printf '%s' "$body" | python3 -c '
import json, sys
d = json.load(sys.stdin)
d["model"] = sys.argv[1]
print(json.dumps(d))
' "$model")"
  local answer
  answer="$(printf '%s' "$payload" | curl -sS --max-time "$STEP_TIMEOUT" \
      -H "Content-Type: application/json" ${key:+-H "Authorization: Bearer $key"} \
      -d @- "${url%/}/chat/completions" 2>&1)" || { printf 'the rail did not answer at %s\n' "$url" >&2; return 1; }
  printf '%s' "$answer" | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    d = json.loads(raw)
except Exception:
    print("the rail answered with something that is not JSON: " + raw[:200], file=sys.stderr)
    raise SystemExit(1)
if "error" in d:
    print("the rail refused: " + json.dumps(d["error"])[:200], file=sys.stderr)
    raise SystemExit(1)
try:
    text = d["choices"][0]["message"]["content"]
except Exception:
    print("the rail returned no message", file=sys.stderr)
    raise SystemExit(1)
if len(text.strip()) < 40:
    print("the model returned nothing usable (" + str(len(text.strip())) + " chars)", file=sys.stderr)
    raise SystemExit(1)
print(text.strip())
'
}

# ── the promises a minutes file carries ────────────────────────────────────
promises_of() {  # <minutes-file> → one promise per line
  python3 - "$1" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
found, inside = [], False
for line in text.splitlines():
    if re.match(r"^#{1,6}\s", line):
        inside = any(w in line.lower() for w in ("promise", "action", "commit"))
        continue
    m = re.match(r"^\s*[-*]\s*(?:\[[ xX]\]\s*)?(.+)$", line)
    if not m:
        continue
    text_line = m.group(1).strip()
    if not text_line or re.match(r"^none in the transcript\.?$", text_line, re.I):
        continue
    if inside or re.match(r"^\s*[-*]\s*\[[ xX]\]", line):
        found.append(text_line)
seen, out = set(), []
for item in found:
    if item not in seen:
        seen.add(item)
        out.append(item)
for item in out:
    print(item)
PY
}

# ── the rungs ──────────────────────────────────────────────────────────────
step_transcript() {  # <folder> <dry>
  local dir="$1" dry="$2" tr audio
  if tr="$(find_transcript "$dir")"; then
    printf 'transcript\tyes\t%s\n' "$(basename "$tr")"
    return 0
  fi
  if ! audio="$(find_audio "$dir")"; then
    printf 'transcript\tno\tno transcript and no recording in this folder\n'
    return 1
  fi
  if [ "$dry" = 1 ]; then
    printf 'transcript\tplan\twould transcribe %s\n' "$(basename "$audio")"
    return 0
  fi
  [ -x "$TRANSCRIBE_DOOR" ] || { printf 'transcript\tno\tthe transcriber is missing: %s\n' "$TRANSCRIBE_DOOR"; return 1; }
  local out="$dir/transcript.md" err
  # The transcriber writes a transcript when told where; its own minutes are dropped —
  # the minutes rung is this ladder's, composed from the transcript AND the people present.
  err="$(SNOTRA_TRANSCRIPT_FILE="$out" SNOTRA_MINUTES_FILE="$dir/.transcript.minutes.tmp.md" \
        timeout "$STEP_TIMEOUT" bash "$TRANSCRIBE_DOOR" "$audio" "$(meeting_title "$dir")" 2>&1 >/dev/null)"
  rm -f "$dir/.transcript.minutes.tmp.md"
  if [ ! -s "$out" ]; then
    printf 'transcript\tno\tthe transcriber finished with no words%s\n' "${err:+ ($(printf '%s' "$err" | tail -1 | cut -c1-160))}"
    return 1
  fi
  printf 'transcript\tyes\t%s (%s lines)\n' "$(basename "$out")" "$(wc -l <"$out")"
}

step_minutes() {  # <folder> <dry>
  local dir="$1" dry="$2" tr mn people
  if mn="$(find_minutes "$dir")"; then
    printf 'minutes\tyes\t%s already filed\n' "$(basename "$mn")"
    return 0
  fi
  if ! tr="$(find_transcript "$dir")"; then
    printf 'minutes\tno\tthere is no transcript to compose from\n'
    return 1
  fi
  people="$(meeting_people "$dir")"
  if [ "$dry" = 1 ]; then
    printf 'minutes\tplan\twould compose minutes from %s for %s\n' "$(basename "$tr")" "${people:-nobody named}"
    return 0
  fi
  local out="$dir/minutes.md" err
  local tmp="$dir/.minutes.tmp.$$"
  if ! err="$(compose_minutes "$dir" "$tr" "$people" 2>&1 >"$tmp")"; then
    rm -f "$tmp"
    printf 'minutes\tno\t%s\n' "$(printf '%s' "$err" | tail -1 | cut -c1-200)"
    return 1
  fi
  if [ ! -s "$tmp" ]; then
    rm -f "$tmp"
    printf 'minutes\tno\tthe model returned nothing\n'
    return 1
  fi
  mv "$tmp" "$out"
  printf 'minutes\tyes\t%s (%s lines, %s present)\n' "$(basename "$out")" "$(wc -l <"$out")" "${people:-nobody named}"
}

step_promises() {  # <folder> <dry> → writes actions.md, prints the count
  local dir="$1" dry="$2" mn count=0
  if ! mn="$(find_minutes "$dir")"; then
    if [ "$dry" = 1 ] && [ -n "$(find_transcript "$dir" 2>/dev/null)" ]; then
      printf 'promises\tplan\twould read the promises out of the minutes this run would write\n'
      return 0
    fi
    printf 'promises\tno\tthere are no minutes to read promises from\n'
    return 1
  fi
  local listed; listed="$(promises_of "$mn")"
  if [ "$dry" = 1 ]; then
    printf 'promises\tplan\twould write %s promise(s)\n' "$(printf '%s' "$listed" | grep -c . || true)"
    return 0
  fi
  local out="$dir/actions.md" tmp="$dir/.actions.tmp.$$"
  {
    printf '# Promises — %s\n\n' "$(meeting_title "$dir")"
    printf '_From `%s`, filed %s by the ladder. Each line becomes one task on the board._\n\n' "$(basename "$mn")" "$(date +%F)"
    if [ -n "$listed" ]; then
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        printf -- '- [ ] %s\n' "$line"
        count=$((count+1))
      done <<< "$listed"
    else
      printf -- '_none in the transcript_\n'
    fi
  } >"$tmp"
  mv "$tmp" "$out"
  printf 'promises\tyes\t%d promise(s) in %s\n' "$count" "$(basename "$out")"
}

step_todos() {  # <folder> <dry> → files every promise through the board door
  local dir="$1" dry="$2" added=0 existed=0 failed=0 n=0 line
  local acts="$dir/actions.md"
  if [ ! -s "$acts" ]; then
    if [ "$dry" = 1 ]; then
      printf 'todos\tplan\twould file whatever promises the minutes of this run carry\n'
      return 0
    fi
    printf 'todos\tno\tthere is no promise list to file\n'
    return 1
  fi
  local id; id="$(meeting_id "$dir")"
  [ -x "$TODO_DOOR" ] || { printf 'todos\tno\tthe board door is missing: %s\n' "$TODO_DOOR"; return 1; }
  while IFS= read -r line; do
    case "$line" in "- [ ] "*) ;; *) continue ;; esac
    local item="${line#- \[ \]}"
    item="${item# }"
    case "$item" in _none*) continue ;; esac
    n=$((n+1))
    if [ "$dry" = 1 ]; then
      printf 'todos\tplan\twould file: %s\n' "${item:0:100}"
      continue
    fi
    local out rc
    out="$("$TODO_DOOR" add "$item" --meeting "$id" --source snotra-ladder --tag promise \
            --key "meeting:$id:$n" 2>&1)"; rc=$?
    if [ $rc -ne 0 ]; then
      failed=$((failed+1))
      printf 'todos\tno\tthe board door refused promise %d: %s\n' "$n" "$(printf '%s' "$out" | tail -1 | cut -c1-160)"
      continue
    fi
    case "$(printf '%s' "$out" | head -1)" in
      exists*) existed=$((existed+1)) ;;
      \#*)     added=$((added+1)) ;;
      *) added=$((added+1)) ;;
    esac
  done <"$acts"
  printf 'todos\tyes\t%d promise(s): %d filed now, %d already there%s\n' "$n" "$added" "$existed" "$([ "$failed" -gt 0 ] && printf ', %d refused' "$failed")"
  [ "$failed" -eq 0 ]
}

# ── the walk ───────────────────────────────────────────────────────────────
run_one() {  # <folder> <dry>
  local dir="$1" dry="${2:-0}"
  local id title line step reason out rc
  id="$(meeting_id "$dir")"; title="$(meeting_title "$dir")"
  printf 'meeting %s — %s%s\n' "$id" "$title" "$([ "$dry" = 1 ] && printf '  (dry run)')"
  for step in transcript minutes promises todos; do
    out="$("step_$step" "$dir" "$dry" 2>&1)"; rc=$?
    line="$(printf '%s' "$out" | head -1)"
    reason="$(printf '%s' "$line" | cut -f3-)"
    case "$rc" in
      0)
        case "$step" in
          transcript) [ "$dry" = 0 ] && { state_write "$dir" transcribed; hotline MEDIUM \
            "transcript ready — $id: $reason" "snotra-transcript-$id"; } ;;
          minutes)    [ "$dry" = 0 ] && { state_write "$dir" recorded; hotline HIGH \
            "minutes filed — $id: $(basename "$(find_minutes "$dir" 2>/dev/null || printf '-')") · $reason" "snotra-minutes-$id"; } ;;
          promises)   : ;;
          todos)      [ "$dry" = 0 ] && state_write "$dir" dispatched ;;
        esac
        printf '  PASS  %-10s %s\n' "$step" "$reason" ;;
      *)
        printf '  FAIL  %-10s %s\n' "$step" "$reason"
        if [ "$dry" = 0 ]; then
          state_write "$dir" "stopped at $step: $reason"
          hotline HIGH "meeting stopped at $step — $id: $reason" "snotra-stopped-$id-$step"
          rune "snotra ladder stopped — $id at $step: $reason"
        fi
        printf 'meeting %s — STOPPED at %s\n' "$id" "$step"
        return 1 ;;
    esac
  done
  [ "$dry" = 0 ] && rune "snotra ladder finished — $id: minutes and $(grep -c '^- \[ \]' "$dir/actions.md" 2>/dev/null || echo 0) promise(s) filed"
  printf 'meeting %s — FINISHED\n' "$id"
  return 0
}

# ── the self-test: a finished ladder and a stopped one, both proven ────────
self_test() {
  local tmp rc=0
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/snotra-ladder-selftest.XXXXXX")" || return 1
  export YMIR_HOME="$tmp/home" SNOTRA_LADDER_QUIET=0
  export SNOTRA_LADDER_NOTIFY_LOG="$tmp/hotline.log"
  export YMIR_STATE_DIR="$tmp/state"     # the board's store lives here in the fixture
  local M="$YMIR_HOME/hodd/life/meetings/self/2026-01-02-good"
  local B="$YMIR_HOME/hodd/life/meetings/self/2026-01-03-bad"
  mkdir -p "$M" "$B"
  for pair in "good:$M" "bad:$B"; do
    local id="${pair%%:*}" dir="${pair#*:}"
    cat >"$dir/meeting.json" <<EOF
{"id":"2026-01-0$([ "$id" = good ] && echo 2 || echo 3)-$id","title":"The $id call","started_at":"2026-01-0$([ "$id" = good ] && echo 2 || echo 3)T10:00:00","state":"captured"}
EOF
    printf '# Transcript\n\nAllfather: we will send the minutes by Friday.\nAnna: I will book the room.\n' >"$dir/transcript.md"
  done
  printf 'captured\n' >"$M/.state"
  printf 'captured\n' >"$B/.state"

  # a deterministic composer: the model's seat, replaced for the test only
  cat >"$tmp/composer.sh" <<'SH'
#!/usr/bin/env bash
transcript="$1"; people="$2"
printf '# Minutes — the test call\n\n## Present\n%s\n\n## Decisions\n- the minutes go out on Friday ("send the minutes by Friday")\n\n## Promises\n- [ ] send the minutes · owner Allfather · due Friday\n- [ ] book the room · owner Anna · due unrepeated\n\n## Notes\nnone\n' "${people:-nobody}"
SH
  chmod +x "$tmp/composer.sh"

  printf 'snotra-ladder self-test (fixture: %s)\n' "$tmp"

  # 1 · the ladder finishes
  local out rc1
  out="$(SNOTRA_MINUTES_COMPOSER="$tmp/composer.sh" bash "$0" run "$M" 2>&1)"; rc1=$?
  printf '%s\n' "$out" | sed 's/^/  | /'
  if [ $rc1 -eq 0 ] && [ "$(state_read "$M")" = "dispatched" ] && [ -s "$M/minutes.md" ] && [ -s "$M/actions.md" ]; then
    printf '  PASS  %-16s finished, state=dispatched, minutes and promises on disk\n' "finished"
  else printf '  FAIL  %-16s rc=%s state=%s\n' "finished" "$rc1" "$(state_read "$M")"; rc=1; fi
  local filed; filed="$(bash "$TODO_DOOR" list --meeting "2026-01-02-good" --json 2>/dev/null | python3 -c 'import json,sys
print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)"
  if [ "$filed" = "2" ]; then printf '  PASS  %-16s %s promise(s) became todos\n' "todos" "$filed"
  else printf '  FAIL  %-16s expected 2 todos, got %s\n' "todos" "$filed"; rc=1; fi
  if grep -q "minutes filed" "$SNOTRA_LADDER_NOTIFY_LOG" 2>/dev/null; then
    printf '  PASS  %-16s the minutes rung spoke\n' "hotline"
  else printf '  FAIL  %-16s the minutes rung said nothing\n' "hotline"; rc=1; fi
  if grep -q "stopped at" "$SNOTRA_LADDER_NOTIFY_LOG" 2>/dev/null; then
    printf '  FAIL  %-16s a finished ladder reported a stop\n' "no-false-stop"; rc=1
  else printf '  PASS  %-16s a finished ladder reports no stop\n' "no-false-stop"; fi
  # idempotent: a second run files nothing twice
  SNOTRA_MINUTES_COMPOSER="$tmp/composer.sh" bash "$0" run "$M" >/dev/null 2>&1
  local again; again="$(bash "$TODO_DOOR" list --meeting "2026-01-02-good" --json 2>/dev/null | python3 -c 'import json,sys
print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)"
  if [ "$again" = "2" ]; then printf '  PASS  %-16s re-running filed nothing twice\n' "idempotent"
  else printf '  FAIL  %-16s re-run duplicated todos (%s)\n' "idempotent" "$again"; rc=1; fi

  # 2 · a step that fails is REPORTED, in the meeting's own state and on the hotline
  rm -f "$B/transcript.md"
  : >"$SNOTRA_LADDER_NOTIFY_LOG"
  local out2 rc2
  out2="$(SNOTRA_MINUTES_COMPOSER="$tmp/composer.sh" bash "$0" run "$B" 2>&1)"; rc2=$?
  printf '%s\n' "$out2" | sed 's/^/  | /'
  local st; st="$(state_read "$B")"
  case "$st" in "stopped at transcript: "*) printf '  PASS  %-16s %s\n' "stopped-state" "$st" ;;
    *) printf '  FAIL  %-16s wanted "stopped at transcript: …", got %q\n' "stopped-state" "$st"; rc=1 ;; esac
  if [ $rc2 -ne 0 ]; then printf '  PASS  %-16s the ladder exits non-zero\n' "stopped-rc"
  else printf '  FAIL  %-16s a stopped ladder exited 0\n' "stopped-rc"; rc=1; fi
  if grep -q "stopped at transcript" "$SNOTRA_LADDER_NOTIFY_LOG" 2>/dev/null; then
    printf '  PASS  %-16s the stop reached the hotline: %s\n' "stopped-hotline" "$(head -1 "$SNOTRA_LADDER_NOTIFY_LOG" | cut -f2 | cut -c1-70)"
  else printf '  FAIL  %-16s the stop never reached the hotline\n' "stopped-hotline"; rc=1; fi
  if [ -s "$B/minutes.md" ]; then printf '  FAIL  %-16s a stopped ladder still wrote minutes\n' "stopped-honest"; rc=1
  else printf '  PASS  %-16s a stopped ladder wrote no minutes\n' "stopped-honest"; fi

  if [ $rc -eq 0 ]; then printf 'snotra-ladder self-test: OK\n'; else printf 'snotra-ladder self-test: FAILED\n'; fi
  rm -rf "$tmp"
  return $rc
}

CMD="${1:-steps}"; shift || true
DRY=0; PENDING=0; LIMIT=0; TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --pending) PENDING=1; shift ;;
    --limit) LIMIT="${2:-0}"; shift 2 ;;
    *) [ -z "$TARGET" ] && TARGET="$1"; shift ;;
  esac
done

case "$CMD" in
  --self-test|selftest) self_test; exit $? ;;
  steps)
    printf 'ladder[4]{step,what,proof}:\n'
    printf '  "transcript","the words beside the recording","the folder holds a transcript, and an audio it no longer needs"\n'
    printf '  "minutes","composed by the model from the transcript and the people present, into that meeting own folder","the minutes name a decision that exists in the transcript"\n'
    printf '  "promises","every promise the minutes carry, written as a list","the list counts what the minutes promise"\n'
    printf '  "todos","every promise filed as work on the board in the same act","the board count equals the promises the minutes list"\n' ;;
  run)
    status=0
    if [ "$PENDING" = 1 ]; then
      local_lim="${LIMIT:-0}"; n=0
      while IFS= read -r folder; do
        [ -n "$folder" ] || continue
        [ -s "$folder/minutes.md" ] && continue
        [ -n "$(find_transcript "$folder" 2>/dev/null)" ] || continue
        n=$((n+1))
        [ "$local_lim" -gt 0 ] && [ "$n" -gt "$local_lim" ] && break
        run_one "$folder" "$DRY" || status=1
      done < <(bash "$MEETINGS_DOOR" json 2>/dev/null | python3 -c '
import json, sys
try: rows = json.load(sys.stdin)
except Exception: rows = []
for r in rows:
    if r.get("transcript") and not r.get("minutes") and r.get("folder"):
        print(r["folder"])
' 2>/dev/null)
      [ "$n" -gt 0 ] || printf 'snotra-ladder: nothing is pending — every transcript already has its minutes\n'
    else
      [ -n "$TARGET" ] || usage
      folder="$(folder_of "$TARGET")" || { printf 'snotra-ladder: no meeting matches %s\n' "$TARGET" >&2; exit 2; }
      [ -n "$folder" ] || { printf 'snotra-ladder: no meeting matches %s\n' "$TARGET" >&2; exit 2; }
      run_one "$folder" "$DRY" || status=1
    fi
    exit $status ;;
  status)
    [ -n "$TARGET" ] || usage
    folder="$(folder_of "$TARGET")" || { printf 'snotra-ladder: no meeting matches %s\n' "$TARGET" >&2; exit 2; }
    st="$(state_read "$folder")"
    printf 'meeting:\n  id: %s\n  folder: %s\n  state: %s\n' "$(meeting_id "$folder")" "$folder" "${st:-no state recorded}"
    case "$st" in
      stopped*) printf '  stopped_at: %s\n' "${st#stopped at }" ;;
      dispatched) printf '  finished: yes — transcript, minutes, promises and todos\n' ;;
      *) printf '  finished: no\n' ;;
    esac ;;
  *) usage ;;
esac
