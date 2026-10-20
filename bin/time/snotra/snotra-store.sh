#!/usr/bin/env bash
# snotra-store.sh — ONE contract for every meeting record, whichever transport heard it.
#
# A meeting is a directory, not a row in someone's database:
#
#   $YMIR_HOME/hodd/life/meetings/<workspace>/<YYYYMMDD-HHMM>-<slug>/
#     meeting.json  transcript.md  minutes.md  decisions.md  actions.md  cards.json
#     audio/  .owner  .state  .transcribe.lock  .corrections.md
#
# The lane is a DIRECTORY because a field is one query away from being exported by
# mistake. `meeting.json.workspace` must equal the parent lane or the write fails.
#
# Usage:
#   snotra-store.sh new <workspace> <slug> [options]
#   snotra-store.sh put <id> <file> --as transcript|audio|minutes|decisions|actions|cards|corrections
#   snotra-store.sh state <id> <captured|transcribed|recorded|dispatched>
#   snotra-store.sh index
#   snotra-store.sh list [--workspace w] [--json]
#   snotra-store.sh verify [<id>|--all]
#   snotra-store.sh path <id>
#
# Options for `new`: --title T --date YYYY-MM-DD --source ear|bot|ping|telegram|manual
#                   --platform google_meet|zoom|teams|jitsi|ping|telegram|local|other
#                   --classification internal|confidential|restricted|private
#                   --account personal|work --consent announced|objected|not_recorded
#
# Exit: 0 ok · 1 verification/IO error · 2 usage · 3 refused (exists / lane mismatch)
set -euo pipefail

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yh="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _i in 1 2 3 4 5; do
    [ -n "$_yh" ] || break
    if [ -r "$_yh/bin/vault/hoard-lib.sh" ]; then . "$_yh/bin/vault/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    if [ -r "$_yh/hoard-lib.sh" ]; then . "$_yh/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    _yh="$(cd "$_yh/.." 2>/dev/null && pwd)"
  done
  unset _yh _i
fi
ymir_home_root YMIR_HOME 2>/dev/null || true
YMIR_HOME="${YMIR_HOME:?YMIR_HOME unresolved — run from a Ymir checkout or set it}"
MEETINGS="$YMIR_HOME/hodd/life/meetings"
STATE_DIR="$YMIR_HOME/hodd/state/snotra"
mkdir -p "$MEETINGS" "$STATE_DIR"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
usage() { sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]\+/-/g; s/^-//; s/-$//' | cut -c1-48
}


json_set() { python3 - "$1" "$2" "$3" <<'PY'
import json,sys
p,k,v=sys.argv[1],sys.argv[2],sys.argv[3]
d=json.load(open(p))
cur=d
parts=k.split('.')
for x in parts[:-1]: cur=cur.setdefault(x,{})
try: val=json.loads(v)
except Exception: val=v
cur[parts[-1]]=val
json.dump(d,open(p,'w'),indent=2)
open(p,'a').write("\n")
PY
}

find_meeting() {
  local id=$1 p
  while IFS= read -r p; do printf '%s\n' "$(dirname "$p")"; return 0; done < <(find "$MEETINGS" -mindepth 3 -maxdepth 3 -name meeting.json -path "*/$id/meeting.json" 2>/dev/null)
  return 1
}

cmd_new() {
  local workspace="" slug="" title="" mdate="" source="manual" platform="local" class="internal" account="" consent="not_recorded"
  workspace="${1-}"; slug="${2-}"; shift 2 2>/dev/null || true
  [ -n "$workspace" ] && [ -n "$slug" ] || usage
  case "$workspace" in work|personal) ;; *) die "workspace must be work or personal" ;; esac
  while [ $# -gt 0 ]; do
    case "$1" in
      --title) title="${2-}"; shift 2 ;;
      --date) mdate="${2-}"; shift 2 ;;
      --source) source="${2-}"; shift 2 ;;
      --platform) platform="${2-}"; shift 2 ;;
      --classification) class="${2-}"; shift 2 ;;
      --account) account="${2-}"; shift 2 ;;
      --consent) consent="${2-}"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  slug="$(slugify "$slug")"; [ -n "$slug" ] || die "slug is empty after normalisation"
  title="${title:-$slug}"
  [ -n "$mdate" ] || mdate="$(date +%Y-%m-%d)"
  local stamp; stamp="$(date +%Y%m%d-%H%M)"
  [ "$(date +%Y-%m-%d)" = "$mdate" ] || stamp="$(date -d "$mdate" +%Y%m%d)-0000"
  local id="$stamp-$slug"
  local dir="$MEETINGS/$workspace/$id"
  local n=2
  while [ -e "$dir" ]; do id="$stamp-$slug-$n"; dir="$MEETINGS/$workspace/$id"; n=$((n+1)); done
  mkdir -p "$dir/audio"
  chmod 700 "$dir" "$dir/audio"
  case "$source" in
    ear) local transport="pipewire" ;;
    bot|ping) local transport="webrtc" ;;
    telegram) local transport="telegram" ;;
    *) local transport="local" ;;
  esac
  python3 - "$dir/meeting.json" "$id" "$workspace" "$account" "$title" "$mdate" "$source" "$transport" "$platform" "$class" "$consent" "$(hostname)" <<'PY'
import json,sys,datetime
p,mid,ws,acct,title,mdate,src,tr,plat,cls,consent,host=sys.argv[1:]
json.dump({
 "schema":1,"id":mid,"workspace":ws,"account":acct or None,"title":title,
 "started_at":mdate+"T00:00:00","source":src,"transport":tr,"platform":plat,
 "classification":cls,"consent":consent,"state":"captured",
 "created_by":host,"created_at":datetime.datetime.now().astimezone().isoformat(timespec="seconds")
}, open(p,"w"), indent=2)
open(p,"a").write("\n")
PY
  printf '%s\t%s\n' "$(hostname)" "$$" > "$dir/.owner"
  printf 'captured\n' > "$dir/.state"
  printf '%s\n' "$dir"
}

cmd_put() {
  local id="${1-}" file="${2-}" as=""
  shift 2 2>/dev/null || true
  while [ $# -gt 0 ]; do case "$1" in --as) as="${2-}"; shift 2 ;; *) die "unknown option: $1" ;; esac; done
  [ -n "$id" ] && [ -n "$file" ] && [ -n "$as" ] || usage
  [ -r "$file" ] || die "not readable: $file"
  local dir; dir="$(find_meeting "$id")" || die "meeting not found: $id"
  local target
  case "$as" in
    transcript) target="$dir/transcript.md" ;;
    minutes) target="$dir/minutes.md" ;;
    decisions) target="$dir/decisions.md" ;;
    actions) target="$dir/actions.md" ;;
    cards) target="$dir/cards.json" ;;
    audio)
      local ext="${file##*.}"; [ "$ext" = "$file" ] && ext="wav"
      target="$dir/audio/recording.$ext"
      if git -C "$YMIR_HOME" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$YMIR_HOME" check-ignore -q "$target" || die "audio is not git-ignored: $target (add hodd/life/meetings/**/audio/ to .gitignore)"
      fi
      ;;
    corrections)
      printf '\n## Correction %s (%s)\n\n' "$(date -u +%Y-%m-%dT%H:%MZ)" "$(hostname)" >> "$dir/.corrections.md"
      cat "$file" >> "$dir/.corrections.md"; printf '\n' >> "$dir/.corrections.md"
      printf 'appended\t%s\n' "$dir/.corrections.md"; return 0 ;;
    *) die "--as must be transcript|audio|minutes|decisions|actions|cards|corrections" ;;
  esac
  [ ! -e "$target" ] || die "refusing to overwrite $target — the record is append-only (use --as corrections)"
  cp "$file" "$target"; chmod 600 "$target"
  case "$as" in
    transcript) [ "$(cat "$dir/.state")" = captured ] && printf 'transcribed\n' > "$dir/.state" ;;
    minutes) printf 'recorded\n' > "$dir/.state" ;;
    cards) printf 'dispatched\n' > "$dir/.state" ;;
  esac
  printf '%s\n' "$target"
}

cmd_state() {
  local id="${1-}" want="${2-}"; [ -n "$id" ] && [ -n "$want" ] || usage
  case "$want" in captured|transcribed|recorded|dispatched) ;; *) die "bad state: $want" ;; esac
  local dir; dir="$(find_meeting "$id")" || die "meeting not found: $id"
  printf '%s\n' "$want" > "$dir/.state"
  json_set "$dir/meeting.json" state "\"$want\""
  printf 'state\t%s\t%s\n' "$id" "$want"
}

cmd_path() { local id="${1-}"; [ -n "$id" ] || usage; find_meeting "$id" || die "meeting not found: $id"; }

cmd_list() {
  local want="" json=0
  while [ $# -gt 0 ]; do case "$1" in --workspace) want="${2-}"; shift 2 ;; --json) json=1; shift ;; *) die "unknown option: $1" ;; esac; done
  local rows=()
  while IFS= read -r f; do
    local ws; ws="$(basename "$(dirname "$(dirname "$f")")")"
    [ -z "$want" ] || [ "$ws" = "$want" ] || continue
    rows+=("$f")
  done < <(find "$MEETINGS" -mindepth 3 -maxdepth 3 -name meeting.json 2>/dev/null | sort)
  if [ "$json" = 1 ]; then
    python3 - "${rows[@]}" <<'PY'
import json,sys,os
out=[]
for p in sys.argv[1:]:
    try: d=json.load(open(p))
    except Exception: continue
    d["_dir"]=os.path.dirname(p)
    out.append(d)
print(json.dumps(out,indent=2))
PY
    return 0
  fi
  printf 'meetings[%d]{id,workspace,title,source,state,dir}:\n' "${#rows[@]}"
  for p in "${rows[@]}"; do
    python3 - "$p" <<'PY'
import json,sys,os
d=json.load(open(sys.argv[1]))
print('  "%s","%s","%s","%s","%s","%s"' % (d.get("id",""),d.get("workspace",""),d.get("title","").replace('"',"'"),d.get("source",""),d.get("state",""),os.path.dirname(sys.argv[1])))
PY
  done
}

cmd_index() {
  ( flock 9
    local out="$MEETINGS/index.md" tmp; tmp="$(mktemp)"
    {
      printf '# Meetings index\n\n'
      printf '_Generated by `snotra-store.sh index` — never hand-edited._\n\n'
      printf '| Date | Lane | Meeting | Source | State |\n|---|---|---|---|---|\n'
      find "$MEETINGS" -mindepth 3 -maxdepth 3 -name meeting.json 2>/dev/null | sort -r | while IFS= read -r f; do
        python3 - "$f" <<'PY'
import json,sys,os
p=sys.argv[1]; d=json.load(open(p))
ws=os.path.basename(os.path.dirname(os.path.dirname(p)))
title=(d.get("title") or "").replace("|","\\|")
print(f'| {d.get("started_at","")[:10]} | {ws} | [{title}]({ws}/{d.get("id","")}/minutes.md) | {d.get("source","")} | {d.get("state","")} |')
PY
      done
    } > "$tmp"
    mv "$tmp" "$out"
    printf 'index\t%s\tts:%s\n' "$out" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ) 9>"$STATE_DIR/index.lock"
}

cmd_verify() {
  local target="${1:---all}" errors=0 checked=0 f
  while IFS= read -r f; do
    local dir ws id state
    dir="$(dirname "$f")"; ws="$(basename "$(dirname "$dir")")"; id="$(basename "$dir")"
    checked=$((checked+1))
    if [ "$target" != "--all" ] && [ "$id" != "$target" ]; then continue; fi
    python3 - "$f" "$ws" "$id" <<'PY' || errors=$((errors+1))
import json,sys,os
p,ws,id=sys.argv[1],sys.argv[2],sys.argv[3]
try: d=json.load(open(p))
except Exception as e: print(f"error\t{id}\tjson: {e}"); sys.exit(1)
errs=[]
if d.get("schema")!=1: errs.append("schema != 1")
if d.get("id")!=id: errs.append("id != directory name")
if d.get("workspace")!=ws: errs.append("workspace != lane")
if d.get("state") not in ("captured","transcribed","recorded","dispatched"): errs.append("bad state")
if d.get("classification") not in ("internal","confidential","restricted","private"): errs.append("bad classification")
if errs:
    for e in errs: print(f"error\t{id}\t{e}")
    sys.exit(1)
print(f"ok\t{id}\t{d.get('workspace')}\t{d.get('state')}")
PY
    state="$(cat "$dir/.state" 2>/dev/null || echo missing)"
    case "$state" in
      captured|transcribed|recorded|dispatched) ;;
      *) printf 'error\t%s\t.state missing or invalid\n' "$id"; errors=$((errors+1)) ;;
    esac
    if [ "$state" != captured ] && [ ! -s "$dir/transcript.md" ]; then
      printf 'error\t%s\ttranscript missing for state %s\n' "$id" "$state"; errors=$((errors+1))
    fi
    if [ -d "$dir/audio" ] && [ -n "$(ls -A "$dir/audio" 2>/dev/null)" ]; then
      if git -C "$YMIR_HOME" rev-parse --git-dir >/dev/null 2>&1; then
        if ! git -C "$YMIR_HOME" check-ignore -q "$dir/audio/recording.wav"; then
          printf 'error\t%s\taudio is not git-ignored\n' "$id"; errors=$((errors+1))
        fi
      fi
    fi
  done < <(find "$MEETINGS" -mindepth 3 -maxdepth 3 -name meeting.json 2>/dev/null | sort)
  printf 'verified\t%d\tmeetings\terrors=%d\n' "$checked" "$errors"
  [ "$errors" -eq 0 ]
}

case "${1-}" in
  new) shift; cmd_new "$@" ;;
  put) shift; cmd_put "$@" ;;
  state) shift; cmd_state "$@" ;;
  path) shift; cmd_path "$@" ;;
  list) shift; cmd_list "$@" ;;
  index) cmd_index ;;
  verify) shift; cmd_verify "${1:---all}" ;;
  *) usage ;;
esac
