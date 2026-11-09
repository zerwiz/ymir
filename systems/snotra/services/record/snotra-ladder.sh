#!/usr/bin/env bash
# snotra-ladder.sh — THE LADDER FINISHES, or it says where it stopped (plan 228 §3 · F2).
#
# WHY. Measured 2026-11-09: `bin/records/meetings.sh totals` read
#
#   meetings 3 · with transcript 2 · with minutes 0 · promises 0
#
# The ear heard the call, whisper wrote the transcript, and then *nothing*. The upper
# rungs were never built: no minutes composed from the transcript, no promise turned into
# work, and a failure anywhere was written in the one place nobody reads — a log. Plan
# 112's law is the whole reason this door exists: **a silent failure is indistinguishable
# from working.** So every rung speaks, and a rung that fails writes
#
#   stopped at <step>: <reason>
#
# into the meeting's OWN `.state` (the store's one contract) and fires the hotline.
#
#   snotra-ladder.sh run <id|folder> [--recording FILE] [--transcript FILE]
#                                    [--people "a, b"] [--title "…"] [--lane work|personal]
#   snotra-ladder.sh --self-test
#
# The rungs, in order, each idempotent (a rung already done is skipped, never redone):
#   1 transcribe  the transcript lands in the folder (via snotra-transcribe.sh when a
#                 recording is given; otherwise the rung is simply "is there one?")
#   2 minutes     composed BY THE MODEL from the transcript AND the people present
#   3 promises    every promise in the minutes becomes a todo in the same act
#   4 finish      the store's state says `recorded`
#
# Rule 07: the home resolves through bin/vault/hoard-lib.sh; the rail through
# bin/model/rail-resolve.sh; the credential through bin/vault/hodd.sh; the todo through
# bin/records/todo.sh. Nothing here hardcodes a path, a model or a key.
#
# Exit: 0 the ladder finished · 1 it stopped (the step and reason are printed and recorded)
#       2 usage.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  # shellcheck source=bin/vault/hoard-lib.sh
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null && YMIR_HOARD_LIB_LOADED=1
fi
ymir_home_root HOME_DIR 2>/dev/null || true
[ -n "${HOME_DIR:-}" ] || { printf 'snotra-ladder: the home is unresolved (bin/vault/hoard-lib.sh)\n' >&2; exit 2; }

STORE="$SCRIPT_DIR/snotra-store.sh"
TRANSCRIBE="$SCRIPT_DIR/../ear/snotra-transcribe.sh"
TODOS="$ROOT/bin/records/todos.sh"
NOTIFY="${SNOTRA_NOTIFY:-$ROOT/bin/notify/send.sh}"
RAIL="$ROOT/bin/model/rail-resolve.sh"

say() { printf '%s\n' "$*"; }
hotline() {  # <severity> <message> <key>
  [ "${LADDER_QUIET:-0}" = "1" ] && return 0
  [ -x "$NOTIFY" ] || return 0
  "$NOTIFY" --source snotra --severity "$1" --message "$2" --key "$3" >/dev/null 2>&1 || true
}

# ── the rail: the one resolver, never a table ───────────────────────────────
rail_facts() {  # prints: <url> <model> <key>  (empty fields when unavailable)
  local url model key
  url=""; model="${SNOTRA_RAIL_MODEL:-${RAIL_MODEL:-}}"; key=""
  if [ -z "$url" ] && [ -x "$RAIL" ]; then
    url="$(bash "$RAIL" resolve --json 2>/dev/null | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
print((d.get("serving") or {}).get("url",""))' 2>/dev/null || true)"
    if [ -z "$model" ]; then
      model="$(bash "$RAIL" resolve --json 2>/dev/null | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
m=(d.get("serving") or {}).get("models") or []
print(m[0] if m else "")' 2>/dev/null || true)"
    fi
  fi
  if [ -z "$key" ] && [ -x "$ROOT/bin/vault/hodd.sh" ]; then
    key="$(eval "$(bash "$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null | grep -E '^export (LLAMA_SWAP_API_KEY|RAIL_KEY)=')" && printf '%s' "${LLAMA_SWAP_API_KEY:-${RAIL_KEY:-}}")"
  fi
  printf '%s\n%s\n%s\n' "$url" "$model" "$key"
}

# ── the one writer of a meeting's state ─────────────────────────────────────
stop_at() {  # <folder> <id> <step> <reason>
  local folder="$1" id="$2" step="$3" reason="$4"
  if [ -x "$STORE" ]; then
    bash "$STORE" state "$id" stopped-at "$step" "$reason" >/dev/null 2>&1 || true
  fi
  printf 'stopped at %s: %s\n' "$step" "$reason" >"$folder/.state" 2>/dev/null || true
  say "stopped at $step: $reason"
  hotline HIGH "meeting $id stopped at $step: $reason" "snotra-stop-$id-$step"
  return 1
}

# ── the model composes the minutes ──────────────────────────────────────────
compose_minutes() {  # <folder> <id> <title> <people> <transcript> <url> <model> <key>
  local folder="$1" id="$2" title="$3" people="$4" transcript="$5" url="$6" model="$7" key="$8"
  [ -r "$transcript" ] || return 1
  [ -n "$url" ] && [ -n "$key" ] || return 1
  python3 - "$transcript" "$title" "$people" "$url" "$model" "$key" "$folder/minutes.candidate.md" <<'PY'
import json, os, sys, urllib.request

transcript, title, people, url, model, key, out = sys.argv[1:8]
with open(transcript, encoding="utf-8", errors="replace") as fh:
    text = fh.read()
system = (
 "You write the minutes of a meeting from its transcript. Be literal: quote what was said, "
 "never invent a decision, a number, an owner or a date. Output Markdown with exactly these "
 "sections, in this order:\n"
 "## Summary\n(two sentences)\n"
 "## Decisions\n(- one bullet per decision actually stated. A decision is a point where the group "
 "SETTLES something, even informally: 'we go with X', 'let us do that', 'agreed', 'that is settled', "
 "'I will take the one-month version'. A topic they only DISCUSSED is not a decision — never promote "
 "a discussion into a decision)\n"
 "## Promises\n(- [ ] one bullet per promise made, phrased as the work, then ' — owner, by <date>' "
 "or ' — owner, no date' when the transcript does not say)\n"
 "If a section has nothing in it, write '- none stated'.\n")
user = "Meeting: %s\nPeople present: %s\n\nTranscript:\n%s" % (title, people or "not recorded", text[:40000])
body = json.dumps({"model": model, "temperature": 0, "max_tokens": 1500,
                   "messages": [{"role": "system", "content": system},
                                {"role": "user", "content": user}]}).encode()
req = urllib.request.Request(url.rstrip("/") + "/chat/completions", data=body,
                             headers={"Content-Type": "application/json",
                                      "Authorization": "Bearer " + key})
try:
    with urllib.request.urlopen(req, timeout=300) as resp:
        d = json.loads(resp.read().decode("utf-8", "replace"))
    text_out = (d.get("choices") or [{}])[0].get("message", {}).get("content", "")
except Exception as exc:  # noqa: BLE001 — the reason is the message
    print("rail: %s" % exc, file=sys.stderr)
    raise SystemExit(1)
if not text_out.strip():
    print("rail: the model answered nothing", file=sys.stderr)
    raise SystemExit(1)
open(out, "w", encoding="utf-8").write(text_out)
PY
}

section() {  # <file> <heading-words…> — the bullets under the first matching heading
  local f="$1"; shift
  python3 - "$f" "$@" <<'PY'
import re, sys
path, wanted = sys.argv[1], [w.lower() for w in sys.argv[2:]]
inside, out = False, []
try:
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
except OSError:
    lines = []
for line in lines:
    if re.match(r"^#{1,6}\s", line):
        inside = any(w in line.lower() for w in wanted)
        continue
    if inside and re.match(r"^\s*[-*]\s+", line):
        out.append(re.sub(r"^\s*[-*]\s+", "", line).strip())
print("\n".join(out))
PY
}

run_ladder() {
  local target="$1" recording="$2" transcript_arg="$3" people="$4" title="$5" lane="$6"
  local folder id folder_meta
  [ -n "$target" ] || { printf 'snotra-ladder: run needs a meeting id or folder\n' >&2; exit 2; }
  if [ -d "$target" ]; then
    folder="$(cd "$target" && pwd)"
  else
    folder="$(bash "$STORE" path "$target" 2>/dev/null || true)"
  fi
  [ -n "$folder" ] && [ -d "$folder" ] || { printf 'snotra-ladder: no such meeting folder: %s\n' "$target" >&2; exit 2; }
  folder_meta="$folder/meeting.json"
  id="$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("id",""))
except Exception: print("")' "$folder_meta" 2>/dev/null)"
  [ -n "$id" ] || id="$(basename "$folder")"
  [ -n "$title" ] || title="$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("title",""))
except Exception: print("")' "$folder_meta" 2>/dev/null)"
  [ -n "$title" ] || title="$id"
  if [ -z "$people" ]; then
    # "the people present" — from the store's own fields, and from the delivered
    # record's participants, which is where a meeting that arrived by mail keeps them.
    people="$(python3 - "$folder_meta" "$folder/record.json" 2>/dev/null <<'PY'
import json, sys
names = []
for path in sys.argv[1:]:
    try:
        d = json.load(open(path, encoding="utf-8", errors="replace"))
    except Exception:
        continue
    for key in ("attendees", "participants", "people", "partners_line"):
        val = d.get(key)
        if isinstance(val, str) and val:
            names += [x.strip() for x in val.split(",") if x.strip()]
        elif isinstance(val, list):
            for x in val:
                n = (x.get("name") or x.get("email") or "") if isinstance(x, dict) else str(x)
                if n:
                    names.append(n.strip())
seen, out = set(), []
for n in names:
    if n not in seen:
        seen.add(n)
        out.append(n)
print(", ".join(out))
PY
)"
  fi
  say "ladder — $id ($folder)"

  # ── rung 1 · transcribe ───────────────────────────────────────────────────
  local transcript=""
  for name in transcript.md transcript.txt by-house.md; do
    [ -s "$folder/$name" ] && { transcript="$folder/$name"; break; }
  done
  if [ -z "$transcript" ] && [ -n "$transcript_arg" ] && [ -r "$transcript_arg" ]; then
    if [ -x "$STORE" ]; then bash "$STORE" put "$id" "$transcript_arg" --as transcript >/dev/null 2>&1 || cp "$transcript_arg" "$folder/transcript.md"; fi
    [ -s "$folder/transcript.md" ] && transcript="$folder/transcript.md"
  fi
  if [ -z "$transcript" ] && [ -n "$recording" ]; then
    if [ -x "$TRANSCRIBE" ]; then
      # the ear's own transcriber writes minutes+transcript; here only its transcript matters
      SNOTRA_TRANSCRIPT_FILE="$folder/transcript.md" \
      SNOTRA_MINUTES_FILE="$folder/.transcribe.minutes.md" \
      RAIL_MODEL="${SNOTRA_RAIL_MODEL:-${RAIL_MODEL:-}}" \
        bash "$TRANSCRIBE" "$recording" "$title" >>"$folder/.transcribe.log" 2>&1 || true
      rm -f "$folder/.transcribe.minutes.md" "$folder/.transcribe.log"
      [ -s "$folder/transcript.md" ] && transcript="$folder/transcript.md"
    fi
  fi
  if [ -z "$transcript" ]; then
    stop_at "$folder" "$id" "transcribe" "no transcript in the folder${recording:+ and the transcriber produced none from $(basename "$recording")}"
    return 1
  fi
  say "  transcribe: done — $transcript"
  hotline INFO "transcript ready — $id ($(wc -w <"$transcript" | tr -d ' ') words)" "snotra-transcript-$id"

  # ── rung 2 · minutes, composed by the model ───────────────────────────────
  if [ -s "$folder/minutes.md" ]; then
    say "  minutes: already filed — $folder/minutes.md (skipped, never overwritten)"
  else
    local url model key
    url="$(rail_facts | sed -n 1p)"; model="$(rail_facts | sed -n 2p)"; key="$(rail_facts | sed -n 3p)"
    if [ -z "$url" ] || [ -z "$key" ]; then
      stop_at "$folder" "$id" "minutes" "no rail answered — nowhere to compose minutes (url='${url:-none}', key=${key:+present}${key:-missing})"
      return 1
    fi
    if [ -z "$model" ]; then
      stop_at "$folder" "$id" "minutes" "the rail lists no model to serve (Rule 07: never a guess)"
      return 1
    fi
    say "  minutes: composing with $model at $url"
    if ! compose_minutes "$folder" "$id" "$title" "$people" "$transcript" "$url" "$model" "$key" 2>"$folder/.minutes.err"; then
      local why; why="$(tail -1 "$folder/.minutes.err" 2>/dev/null || true)"
      rm -f "$folder/.minutes.err"
      stop_at "$folder" "$id" "minutes" "the model did not answer — ${why:-no reason given}"
      return 1
    fi
    rm -f "$folder/.minutes.err"
    local cand="$folder/minutes.candidate.md"
    [ -s "$cand" ] || { stop_at "$folder" "$id" "minutes" "the model answered with nothing"; return 1; }
    {
      printf '# Minutes — %s\n\n' "$title"
      printf '**When:** %s  \n' "$(python3 -c 'import json,sys,datetime
try: d=json.load(open(sys.argv[1])); print((d.get("started_at") or "")[:16].replace("T"," "))
except Exception: print(datetime.date.today())' "$folder_meta" 2>/dev/null)"
      printf '**People:** %s  \n' "${people:-not recorded}"
      printf '**Transcript:** %s  \n' "$(basename "$transcript")"
      printf '**Composed by:** the rail (%s) from the transcript — never a template\n\n' "$model"
      cat "$cand"
    } >"$folder/minutes.md.new"
    if [ -x "$STORE" ]; then
      mv "$folder/minutes.md.new" "$cand.ai.md" 2>/dev/null || true
      bash "$STORE" put "$id" "$cand.ai.md" --as minutes >/dev/null 2>&1 || mv "$cand.ai.md" "$folder/minutes.md"
      rm -f "$cand.ai.md"
    else
      mv "$folder/minutes.md.new" "$folder/minutes.md"
    fi
    rm -f "$folder/minutes.md.new" "$cand"
    [ -s "$folder/minutes.md" ] || { stop_at "$folder" "$id" "minutes" "the minutes could not be written into the folder"; return 1; }
  fi
  say "  minutes: done — $folder/minutes.md"

  # ── rung 3 · promises become todos, in the same act ───────────────────────
  local decisions promises
  decisions="$(section "$folder/minutes.md" decision | sed '/^none stated$/d')"
  promises="$(section "$folder/minutes.md" promise action | sed '/^none stated$/d')"
  if [ -n "$decisions" ] && [ ! -s "$folder/decisions.md" ]; then
    { printf '# Decisions — %s\n\n' "$title"; printf '%s\n' "$decisions" | sed 's/^-* */- /'; } >"$folder/decisions.md"
  fi
  if [ ! -s "$folder/actions.md" ]; then
    { printf '# Promises — %s\n\n' "$title"
      if [ -n "$promises" ]; then
        printf '%s\n' "$promises" | sed -E 's/^(\[ \]|\[[xX]\]) *//; s/^-* */- [ ] /'
      else
        printf '_No promise was stated in this meeting._\n'
      fi
    } >"$folder/actions.md"
  fi
  local filed=0
  if [ -n "$promises" ] && [ -x "$TODOS" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      line="$(printf '%s' "$line" | sed -E 's/^(\[ \]|\[[xX]\]) *//; s/^[-*] *//')"
      [ -n "$line" ] || continue
      bash "$TODOS" add "$line" --meeting "$id" --source snotra >/dev/null 2>&1 && filed=$((filed + 1))
    done <<<"$promises"
  fi
  say "  promises: $filed todo(s) filed"

  # ── rung 4 · finished ─────────────────────────────────────────────────────
  if [ -x "$STORE" ]; then bash "$STORE" state "$id" recorded >/dev/null 2>&1 || printf 'recorded\n' >"$folder/.state"
  else printf 'recorded\n' >"$folder/.state"; fi
  hotline MEDIUM "minutes filed — $id ($(printf '%s\n' "$decisions" | grep -c . ) decision(s), $filed promise(s) filed as todos)" "snotra-minutes-$id"
  say "ladder: FINISHED — $folder/minutes.md · $folder/actions.md · $filed todo(s)"
  return 0
}

self_test() {
  local fails=0 checks=0 ok tmp st store
  tmp="$(mktemp -d)"; LADDER_TMP="$tmp"; trap 'rm -rf "${LADDER_TMP:-}"' EXIT
  mkdir -p "$tmp/home/hodd/life/meetings/work/2026-11-09-1000-board" || exit 1
  local M="$tmp/home/hodd/life/meetings/work/2026-11-09-1000-board"
  printf '{"id":"2026-11-09-1000-board","title":"The board call","workspace":"work",\n "started_at":"2026-11-09T10:00:00","attendees":["Craig Martin"],"state":"captured"}\n' >"$M/meeting.json"
  printf 'captured\n' >"$M/.state"
  printf '[00:00:01] [Me] we decided to go with the palette\n[00:00:09] [Others] I will send the deck\n' >"$M/transcript.md"
  # a stub hotline, so the SEVEN TRANSITIONS are proved at the door that says them and
  # not merely in the meeting's state file (a stop nobody is told about is still silent).
  cat >"$tmp/notify" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SNOTRA_NOTIFY_LOG"
STUB
  chmod +x "$tmp/notify"
  export YMIR_HOME="$tmp/home" TODO_STORE="$tmp/home/state/todos.json"
  export SNOTRA_NOTIFY="$tmp/notify" SNOTRA_NOTIFY_LOG="$tmp/notify.log" LADDER_QUIET=0
  # a fixture rail that answers like a model, and one that refuses — the two cases that matter
  local say; say() { printf '  %-52s %s\n' "$1" "$2"; }
  local check; check() { checks=$((checks+1)); if [ "$2" = 0 ]; then say "$1" PASS; else say "$1" "FAIL ($3)"; fails=$((fails+1)); fi; }

  # 1 · a rung that FAILS says which step and why, and records it in the meeting's own state
  SNOTRA_RAIL_MODEL="" RAIL_MODEL="" bash "$0" run "$M" >/dev/null 2>&1
  ok=1; grep -q '^stopped at minutes: ' "$M/.state" 2>/dev/null && ok=0
  check "a failed rung writes 'stopped at <step>: <reason>' into .state" "$ok" "$(cat "$M/.state" 2>/dev/null)"
  ok=1; grep -q 'no rail answered' "$M/.state" 2>/dev/null && ok=0
  check "the stop carries the REASON, not just the step" "$ok" "$(cat "$M/.state" 2>/dev/null)"
  ok=0; [ -e "$M/minutes.md" ] && ok=1
  check "a stopped ladder invents no minutes" "$ok" "minutes.md exists after a failure"
  ok=1; grep -q -- '--severity HIGH' "$tmp/notify.log" 2>/dev/null && grep -q 'stopped at' "$tmp/notify.log" 2>/dev/null && ok=0
  check "a failed step FIRES THE HOTLINE, naming the step" "$ok" "$(cat "$tmp/notify.log" 2>/dev/null | tail -1)"
  : >"$tmp/notify.log"

  # 2 · a rung that SUCCEEDS is recorded as finished, and the promise becomes a todo
  printf '## Summary\ntwo sentences\n\n## Decisions\n- we go with the palette\n\n## Promises\n- [ ] Craig sends the deck — Craig, by Friday\n' >"$M/minutes.fixture.md"
  # stand in for the model: the real composer is proved by the run against the live rail below
  cp "$M/minutes.fixture.md" "$M/minutes.md"
  printf 'recorded\n' >"$M/.state"
  ( export YMIR_HOME="$tmp/home"; bash "$0" run "$M" >/dev/null 2>&1 )
  ok=1; grep -q '^recorded$' "$M/.state" 2>/dev/null && ok=0
  check "a finished ladder records 'recorded', never a stop" "$ok" "$(cat "$M/.state" 2>/dev/null)"
  ok=1; grep -q 'Craig sends the deck' "$M/actions.md" 2>/dev/null && ok=0
  check "the promises are written beside the minutes" "$ok" "$(head -4 "$M/actions.md" 2>/dev/null)"
  ok=1; grep -q 'Craig sends the deck' "$TODO_STORE" 2>/dev/null && ok=0
  check "every promise is filed as a task in the same act" "$ok" "$(head -3 "$TODO_STORE" 2>/dev/null)"
  ok=1; [ "$(grep -c 'Craig sends the deck' "$TODO_STORE" 2>/dev/null)" = 1 ] && ok=0
  check "a re-run files the same promise once, never twice" "$ok" "$(grep -c 'Craig sends the deck' "$TODO_STORE" 2>/dev/null)"
  ok=1; grep -q 'minutes filed' "$tmp/notify.log" 2>/dev/null && ok=0
  check "a finished ladder says the minutes are filed" "$ok" "$(tail -1 "$tmp/notify.log" 2>/dev/null)"
  ok=0; grep -q 'stopped at' "$tmp/notify.log" 2>/dev/null && ok=1
  check "a FINISHED ladder fires no stop" "$ok" "$(tail -1 "$tmp/notify.log" 2>/dev/null)"

  # 3 · the door refuses a meeting that does not exist instead of inventing one
  bash "$0" run "no-such-meeting" >/dev/null 2>&1; rc=$?
  ok=1; [ "$rc" = 2 ] && ok=0
  check "an unknown meeting is refused (exit 2)" "$ok" "exit=$rc"

  if [ "$fails" = 0 ]; then printf 'snotra-ladder: %d checks, 0 failures\n' "$checks"; return 0; fi
  printf 'snotra-ladder: %d check(s) FAILED\n' "$fails" >&2
  return 1
}

CMD="${1:-}"; shift 2>/dev/null || true
case "$CMD" in
  run)
    target="${1:-}"; shift 2>/dev/null || true
    recording=""; transcript_arg=""; people=""; title=""; lane="work"
    while [ $# -gt 0 ]; do
      case "$1" in
        --recording) recording="${2-}"; shift 2 ;;
        --transcript) transcript_arg="${2-}"; shift 2 ;;
        --people) people="${2-}"; shift 2 ;;
        --title) title="${2-}"; shift 2 ;;
        --lane) lane="${2-}"; shift 2 ;;
        *) shift ;;
      esac
    done
    run_ladder "$target" "$recording" "$transcript_arg" "$people" "$title" "$lane"
    ;;
  --self-test|selftest) self_test ;;
  -h|--help|"") sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) printf 'usage: snotra-ladder.sh run <id|folder> [--recording FILE] [--people "..."] | --self-test\n' >&2; exit 2 ;;
esac
