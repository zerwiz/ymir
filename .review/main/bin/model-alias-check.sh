#!/usr/bin/env bash
# model-alias-check.sh — does every alias a body names resolve in the fleet?
#
# Plan 51 (multi-machine operations), Phase 5 §6 — the alias-conformance gate.
# The fleet's alias vocabulary is a contract: a seat's registry
# (`~/.pi/agent/models.json`) names the models it will ask for, and the rails
# (the forge's heavy rail and each body's local rail) are what serve those names.
# Renaming a rail alias that a body still names breaks that body silently — the
# written law, until now with no gate. This reads every reachable seat's registry
# over the ring, gathers what every reachable rail serves (the written presets
# AND the live `/v1/models`), and verifies each named alias resolves somewhere in
# the fleet (the forge or locally). A name no rail serves is a missing alias: the
# gate FAILS, names the seat + the alias, and exits non-zero.
#
# Honesty: a seat (or a rail) that cannot be reached is reported `offline` —
# never a FAIL — and every reachable seat is still verified.
#
#   model-alias-check.sh             # the whole reachable ring, as TOON
#   model-alias-check.sh --local     # this seat only; no ssh (the smoke-test mode)
#   model-alias-check.sh --json
#   model-alias-check.sh check       # the gate; exit 1 on a missing alias
#   model-alias-check.sh --version
#
# Env:
#   YMIR_FLEET_REGISTRY  fleet.json (default $YMIR_HOME/hodd/data/fleet.json)
#   YMIR_ALIAS_REGISTRY  this seat's registry (default ~/.pi/agent/models.json)
#   YMIR_RAIL_PRESET     the local rail's written presets (default
#                        ~/.config/llama-rail/models.ini)
#   YMIR_RAIL_PORT       the rail port (default 8080)
#   LLAMA_SWAP_API_KEY   the shared rail key; else read from the hoard vault, then
#                        the local root pi `auth.json` (never written to disk here)
#   YMIR_ALIAS_TIMEOUT   ssh/curl seconds (default 6)
#   YMIR_ALIAS_NO_LIVE=1 written presets only — do not probe /v1/models
set -u

VERSION="1.0.0"
case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

MODE=toon; LOCAL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json)  MODE=json ;;
    check)   MODE=check ;;
    --local) LOCAL=1 ;;
    *) printf 'error: unknown arg %s\nhelp: bin/model-alias-check.sh [--local] [--json|check]\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
YMIR_HOME_ROOT=""
if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root YMIR_HOME_ROOT 2>/dev/null; fi
YMIR_HOME_ROOT="${YMIR_HOME_ROOT:-${YMIR_HOME:-}}"
FLEET="${YMIR_FLEET_REGISTRY:-$YMIR_HOME_ROOT/hodd/data/fleet.json}"
SELF="${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"
SELF="${SELF:-unknown}"
RAIL_PORT="${YMIR_RAIL_PORT:-8080}"
TIMEOUT="${YMIR_ALIAS_TIMEOUT:-6}"
NO_LIVE="${YMIR_ALIAS_NO_LIVE:-0}"

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t model-alias)" || { printf 'error: cannot make a temp dir\n' >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT

# The shared rail key: env -> the hoard vault -> the local root pi auth.json. It is
# only ever used to ask a rail what it serves; it is never written anywhere.
KEY="${LLAMA_SWAP_API_KEY:-}"
if [ -z "$KEY" ] && [ -x "$SCRIPT_DIR/hodd.sh" ]; then
  KEY="$(bash "$SCRIPT_DIR/hodd.sh" emit secrets/platform.env 2>/dev/null | sed -n 's/^LLAMA_SWAP_API_KEY=//p' | head -1)"
fi
if [ -z "$KEY" ] && [ -r "${PI_AUTH_JSON:-$HOME/.pi/agent/auth.json}" ]; then
  KEY="$(python3 -c "import json,sys
try:
    print(json.load(open(sys.argv[1])).get('llama-swap',{}).get('key','') or '')
except Exception:
    pass" "${PI_AUTH_JSON:-$HOME/.pi/agent/auth.json}" 2>/dev/null || true)"
fi

# What a rail serves, asked over the network at /v1/models.
rail_aliases() {  # <base-url-without-/v1>
  local base="$1"
  [ -n "$base" ] || return 0
  [ -n "$KEY" ] || return 0
  curl -s -m 3 -H "Authorization: Bearer $KEY" "$base/v1/models" </dev/null 2>/dev/null | python3 -c "import sys,json
try:
    for m in json.load(sys.stdin).get('data',[]):
        if m.get('id'):
            print(m['id'])
except Exception:
    pass" 2>/dev/null || true
}

# A seat's registry, over ssh when it is not this machine.
read_registry() {  # <ssh-addr> ; empty on failure
  ssh -n -o BatchMode=yes -o ConnectTimeout="$TIMEOUT" -o StrictHostKeyChecking=accept-new \
      "$1" 'cat ~/.pi/agent/models.json 2>/dev/null' 2>/dev/null || true
}

# ── the seats: this machine plus every row in the registry ───────────────────
if [ "$LOCAL" = 1 ]; then
  printf '%s\t%s\n' "$SELF" "$SELF" >"$TMP/seats.tsv"
else
  python3 - "$FLEET" "$SELF" <<'PY' >"$TMP/seats.tsv"
import json, sys
reg, self_host = sys.argv[1], sys.argv[2]
rows = {}
try:
    doc = json.load(open(reg))
except Exception:
    doc = {}
for h, spec in (doc.get("hosts") or {}).items():
    spec = spec or {}
    addrs = [h]
    for k in ("tailnet", "lan"):
        v = spec.get(k)
        if v and v not in addrs:
            addrs.append(str(v))
    rows[h] = addrs
rows.setdefault(self_host, [self_host])
for h in rows:
    print(h + "\t" + ",".join(rows[h]))
PY
fi

mkdir -p "$TMP/regs" "$TMP/rails"
: >"$TMP/seatorder.tsv"
while IFS=$'\t' read -r name addrs; do
  [ -n "$name" ] || continue
  IFS=',' read -ra _cand <<<"$addrs"
  state=offline
  if [ "$name" = "$SELF" ]; then
    reg="${YMIR_ALIAS_REGISTRY:-$HOME/.pi/agent/models.json}"
    [ -r "$reg" ] && { printf '%s\n' "$(cat "$reg")" >"$TMP/regs/$name.json"; state=ok; }
    # The local rail: its written presets first, then the live answer.
    {
      PRESET="${YMIR_RAIL_PRESET:-$HOME/.config/llama-rail/models.ini}"
      [ -r "$PRESET" ] && grep -E '^\[' "$PRESET" 2>/dev/null | sed 's/^\[//;s/\]$//' | grep -v '^\*$'
      printf '__ALIAS_LIVE__\n'
      [ "$NO_LIVE" != 1 ] && rail_aliases "http://127.0.0.1:$RAIL_PORT"
    } >"$TMP/rails/$name.txt" 2>/dev/null
  else
    for _a in "${_cand[@]}"; do
      [ -n "$_a" ] || continue
      _reg="$(read_registry "$_a")"
      [ -n "$_reg" ] || continue
      printf '%s\n' "$_reg" >"$TMP/regs/$name.json"
      state=ok
      {
        printf '__ALIAS_LIVE__\n'
        [ "$NO_LIVE" != 1 ] && rail_aliases "http://$_a:$RAIL_PORT"
      } >"$TMP/rails/$name.txt" 2>/dev/null
      break
    done
  fi
  printf '%s\t%s\n' "$name" "$state" >>"$TMP/seatorder.tsv"
done <"$TMP/seats.tsv"

# ── the judgement ────────────────────────────────────────────────────────────
python3 - "$TMP" "$SELF" "$MODE" "$NO_LIVE" "$FLEET" <<'PY'
import json, os, sys, urllib.parse

tmp, self_host, mode, no_live, regpath = sys.argv[1:6]

# Every hostname a fleet seat answers to -> the seat's canonical name.
name_to_seat = {}
try:
    doc = json.load(open(regpath))
except Exception:
    doc = {}
for h, spec in (doc.get("hosts") or {}).items():
    spec = spec or {}
    for a in (h, spec.get("tailnet"), spec.get("lan")):
        if a:
            name_to_seat[str(a)] = h
name_to_seat.setdefault(self_host, self_host)

seats = []
for line in open(os.path.join(tmp, "seatorder.tsv")):
    p = line.rstrip("\n").split("\t")
    if len(p) >= 2 and p[0]:
        seats.append((p[0], p[1]))

def slurp(path):
    try:
        with open(path) as f:
            return f.read()
    except Exception:
        return ""

# What each reachable seat's LOCAL rail serves: its written presets, plus its
# live /v1/models unless the written contract alone was asked for.
rails, rail_present = {}, {}
for name, _state in seats:
    raw = slurp(os.path.join(tmp, "rails", name + ".txt"))
    ini, _, live = raw.partition("__ALIAS_LIVE__\n")
    aliases = {x.strip() for x in ini.splitlines() if x.strip()}
    if no_live != "1":
        aliases |= {x.strip() for x in live.splitlines() if x.strip()}
    rails[name] = aliases
    rail_present[name] = len(aliases) > 0
served = set()
for a in rails.values():
    served |= a

def provider_rail(seat, base):
    """Which rail a provider's baseUrl addresses: (kind, name)."""
    if "://" not in base:
        base = "http://" + base
    host = (urllib.parse.urlparse(base).hostname or "").lower()
    if host in ("127.0.0.1", "localhost", "0.0.0.0", "::1", ""):
        return ("local", seat)
    for alias, seat_name in name_to_seat.items():
        if alias.lower() == host:
            return ("local", seat_name)
    return ("net", host)

rows, offline_seats = [], []
checked = 0
for name, state in seats:
    if state != "ok":
        offline_seats.append((name, "seat unreachable"))
        continue
    try:
        reg = json.loads(slurp(os.path.join(tmp, "regs", name + ".json")) or "{}")
    except Exception:
        offline_seats.append((name, "registry unreadable"))
        continue
    providers = reg.get("providers") or {}
    if not isinstance(providers, dict):
        continue
    for pname in sorted(providers):
        pspec = providers[pname]
        if not isinstance(pspec, dict):
            continue
        base = pspec.get("baseUrl") or pspec.get("base_url") or ""
        if not base:
            continue
        kind, target = provider_rail(name, base)
        rail_ok = kind == "local" and state == "ok" and rail_present.get(target, False)
        ids = []
        for m in (pspec.get("models") or []):
            mid = m.get("id") if isinstance(m, dict) else m
            if mid:
                ids.append(str(mid))
        rail_label = ("local:" + target) if kind == "local" else ("net:" + target)
        for mid in ids:
            checked += 1
            if mid in served:
                st = "ok"
            elif not rail_ok:
                st = "offline"
            else:
                st = "missing"
            if st != "ok":
                rows.append((name, pname, mid, rail_label, st))

missing = [r for r in rows if r[4] == "missing"]
offline_rows = [r for r in rows if r[4] == "offline"]
verdict = "FAIL" if missing else "pass"
seat_summary = []
for name, state in seats:
    if state == "ok":
        seat_summary.append((name, "ok", str(len(rails.get(name, ())))))
    else:
        seat_summary.append((name, "offline", "0"))

if mode == "json":
    print(json.dumps({
        "verdict": verdict,
        "checked": checked,
        "missing": [{"seat": s, "provider": p, "alias": a, "rail": r} for s, p, a, r, _ in missing],
        "offline": [{"seat": s, "reason": reason} for s, reason in offline_seats]
                   + [{"seat": s, "provider": p, "alias": a, "rail": r} for s, p, a, r, _ in offline_rows],
        "seats": [{"seat": s, "state": st, "served": n} for s, st, n in seat_summary],
    }))
    sys.exit(1 if missing else 0)

print(f'model_alias_seats[{len(seat_summary)}]{{seat,state,served_aliases}}:')
for s, st, n in seat_summary:
    print(f'  "{s}","{st}","{n}"')
if missing:
    print(f'model_alias_missing[{len(missing)}]{{seat,provider,alias,rail}}:')
    for s, p, a, r, _ in missing:
        print(f'  "{s}","{p}","{a}","{r}"')
if offline_seats:
    print(f'model_alias_offline_seats[{len(offline_seats)}]{{seat,reason}}:')
    for s, reason in offline_seats:
        print(f'  "{s}","{reason}"')
print(f'model_alias_check[4]{{fact,value,note}}:')
print(f'  "verdict","{verdict}","{"a seat names an alias no reachable rail serves" if missing else "every named alias resolves (or its rail is offline)"}"')
print(f'  "checked","{checked}","aliases named by reachable seats"')
print(f'  "missing","{len(missing)}","aliases no reachable rail serves"')
print(f'  "offline","{len(offline_rows) + len(offline_seats)}","seats or aliases reported offline, never a FAIL"')
if missing:
    first = missing[0]
    print(f'help: {first[0]} names alias {first[2]} ({first[1]}) that no reachable rail serves — restore it or fix the {first[0]} registry')
sys.exit(1 if missing else 0)
PY
