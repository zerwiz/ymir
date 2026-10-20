#!/usr/bin/env bash
# snotra-autojoin.sh — read the calendar, decide which meetings Snotra joins, and join them.
#
# Read-only on the calendar; the only write is the plan and the bot dispatch.
#
# Usage:
#   snotra-autojoin.sh scan   [--events FILE] [--now ISO] [--window-hours N]
#   snotra-autojoin.sh plan
#   snotra-autojoin.sh run    [--apply]      (dry-run unless --apply)
#   snotra-autojoin.sh status
#
# Env/conf:
#   YMIR_HOME              the hoard
#   AUTOJOIN_CONFIG        config file (default <root>/config/snotra/autojoin.conf)
#   MANAGANDR_CACHE        calendar cache (default <home>/hodd/state/calendar/cache.json)
#   SNOTRA_BOT             bot door (default <root>/bin/time/snotra/snotra-bot.sh)
#
# Exit: 0 ok · 1 error · 2 usage · 3 refused (auto-join disabled)
set -euo pipefail
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1-}"; shift || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh" "$ROOT/bin/vault/hoard-lib.sh"; do [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }; done; unset _c
fi
ymir_home_root YMIR_HOME 2>/dev/null || true
YMIR_HOME="${YMIR_HOME:?YMIR_HOME unresolved}"
STATE_DIR="$YMIR_HOME/hodd/state/snotra"; mkdir -p "$STATE_DIR"
PLAN="$STATE_DIR/autojoin-plan.json"
JOINED="$STATE_DIR/autojoin-joined.json"
CACHE="${MANAGANDR_CACHE:-$YMIR_HOME/hodd/state/calendar/cache.json}"
CONF="${AUTOJOIN_CONFIG:-$ROOT/config/snotra/autojoin.conf}"
[ -r "$CONF" ] && . "$CONF"
BOT="${SNOTRA_BOT:-$ROOT/bin/time/snotra/snotra-bot.sh}"
NOW="${AUTOJOIN_NOW:-$(date -Iseconds)}"
WINDOW_H="${AUTOJOIN_WINDOW_HOURS:-24}"
EVENTS=""

die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
usage(){ sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
while [ $# -gt 0 ]; do case "$1" in
  --events) EVENTS="${2-}"; shift 2 ;;
  --now) NOW="${2-}"; shift 2 ;;
  --window-hours) WINDOW_H="${2-}"; shift 2 ;;
  --apply) APPLY=1; shift ;;
  *) die "unknown option: $1" ;; esac; done

[ "${AUTOJOIN_ENABLED:-1}" = 1 ] || { printf 'refused\tauto-join disabled\n'; exit 3; }

scan() {
  [ -n "$EVENTS" ] || EVENTS="$CACHE"
  [ -r "$EVENTS" ] || die "calendar events not readable: $EVENTS"
  python3 - "$EVENTS" "$PLAN" "$NOW" "$WINDOW_H" "$JOINED" "${AUTOJOIN_WORKSPACES:-work}" "${AUTOJOIN_PERSONAL:-0}" "${AUTOJOIN_ALLOWED_PLATFORMS:-}" "${AUTOJOIN_BLOCK_TITLES:-}" "${AUTOJOIN_MAX_PER_RUN:-3}" <<'PY'
import json,sys,re,datetime,os
src,out,now_s,win_h,joined_p,workspaces,personal,platforms,block,maxn=sys.argv[1:]
try: raw=json.load(open(src))
except Exception as e: print(f"error\tcannot read {src}: {e}",file=sys.stderr); sys.exit(1)
events=raw.get("events") if isinstance(raw,dict) else raw
events=events or []
now=datetime.datetime.fromisoformat(now_s.replace("Z","+00:00"))
end=now+datetime.timedelta(hours=float(win_h))
allowed={p.strip() for p in platforms.split(",") if p.strip()}
block_re=re.compile(block,re.I) if block else None
enabled={w.strip() for w in workspaces.split(",") if w.strip()}
if personal in ("1","true","yes"): enabled.add("personal")
try: joined=json.load(open(joined_p))
except Exception: joined=set()
joined=set(joined) if isinstance(joined,list) else set()
def dt(v):
    if not v: return None
    try: return datetime.datetime.fromisoformat(v.replace("Z","+00:00"))
    except Exception: return None
def platform_of(e):
    u=(e.get("conference_url") or "")+" "+(e.get("location") or "")
    if "meet.google." in u: return "google_meet"
    if "zoom.us" in u: return "zoom"
    if "teams.microsoft." in u: return "teams"
    if "jitsi" in u: return "jitsi"
    if "ping.zerwiz.org" in u: return "ping"
    return e.get("conference_type") or "other"
plan=[]
for e in events:
    ws=e.get("workspace") or e.get("account") or "work"
    start=dt(e.get("start")); stop=dt(e.get("end"))
    url=e.get("conference_url") or ""
    key=f"{ws}|{e.get('id','')}|{e.get('start','')}"
    reason=None
    if e.get("status")=="cancelled": reason="cancelled"
    elif e.get("all_day"): reason="all-day"
    elif not e.get("busy", True): reason="not busy"
    elif ws not in enabled: reason=f"workspace {ws} not enabled"
    elif not url: reason="no video link"
    elif platform_of(e) not in allowed: reason=f"platform {platform_of(e)} not enabled"
    elif (e.get("self_response") or "")=="declined": reason="you declined"
    elif (e.get("visibility") or "")=="private": reason="private event"
    elif block_re and block_re.search(e.get("summary") or ""): reason="blocked title"
    elif e.get("classification")=="restricted": reason="restricted"
    elif stop and stop < now: reason="already ended"
    elif start and start > end: reason="outside window"
    elif key in joined: reason="already joined"
    plan.append({"key":key,"id":e.get("id"),"workspace":ws,"title":e.get("summary"),
                 "start":e.get("start"),"end":e.get("end"),"platform":platform_of(e),
                 "url":url,"decision":"skip" if reason else "join","reason":reason,
                 "account":e.get("account")})
joins=[p for p in plan if p["decision"]=="join"]
if len(joins)>int(maxn):
    for p in joins[int(maxn):]: p["decision"]="skip"; p["reason"]="max per run"
json.dump({"generated_at":now.isoformat(),"now":now_s,"window_hours":float(win_h),
           "plan":plan},open(out,"w"),indent=2)
print(f"plan\t{out}\tevents:{len(plan)}\tjoin:{sum(1 for p in plan if p['decision']=='join')}")
PY
}

print_plan() {
  [ -r "$PLAN" ] || die "no plan — run scan first"
  python3 - "$PLAN" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
print(f'plan[1]{{generated,events,join}}:')
print(f'  "{d["generated_at"]}",{len(d["plan"])},{sum(1 for p in d["plan"] if p["decision"]=="join")}')
print('  id,workspace,start,platform,decision,reason')
for p in d["plan"]:
    print('  "%s","%s","%s","%s","%s","%s"' % (p.get("id",""),p.get("workspace",""),p.get("start",""),p.get("platform",""),p.get("decision",""),(p.get("reason") or "").replace('"',"'")))
PY
}

run_plan() {
  [ -r "$PLAN" ] || die "no plan — run scan first"
  local apply="${APPLY:-0}"
  python3 - "$PLAN" "$apply" <<'PY' > "$STATE_DIR/autojoin-run.txt"
import json,sys
d=json.load(open(sys.argv[1])); apply=sys.argv[2]=="1"
for p in d["plan"]:
    if p["decision"]!="join": continue
    print(("JOIN" if apply else "WOULD-JOIN")+"\t"+p["key"]+"\t"+p["url"])
PY
  if [ "$apply" = 1 ] && [ -x "$BOT" ]; then
    while IFS=$'\t' read -r act key url; do
      [ "$act" = JOIN ] || continue
      "$BOT" join "$url" --workspace "${key%%|*}" --name Snotra || printf 'failed\t%s\n' "$key" >&2
      python3 - "$JOINED" "$key" <<'PY'
import json,sys
p,key=sys.argv[1],sys.argv[2]
try: d=json.load(open(p))
except Exception: d=[]
if key not in d: d.append(key)
json.dump(d,open(p,'w'),indent=2)
PY
    done < "$STATE_DIR/autojoin-run.txt"
  fi
  cat "$STATE_DIR/autojoin-run.txt"
}

case "$ACTION" in
  scan) scan; print_plan ;;
  plan) print_plan ;;
  run) APPLY="${APPLY:-0}"; [ -r "$PLAN" ] || scan; run_plan ;;
  status) if [ -r "$PLAN" ]; then print_plan; else printf 'plan\tnone\n'; fi ;;
  *) usage ;;
esac
