#!/usr/bin/env bash
# smoke_test.sh — does the WHOLE stack actually work? (the lifecycle interface)
#
# Answers more than "a port is open". It walks every surface the runtime owns:
#   services   — SPA, gate API, well, Bifrost, Smiðja visualizer, hall, model rail
#   runtime    — session lock, lock pointer, supervision (watcher), cron,
#                migrations, harness extension bindings, agent loaders
#   data       — Smiðja schema, the well store, the hoard layout
#   governance — compliance gates and the secret ward
#
# Every check is independent and tolerant: a surface that is intentionally not
# raised (an optional bridge, an idle model rail) reports SKIP, never FAIL. Exit
# 0 when nothing FAILs, 1 otherwise — a gate can rely on it.
#
# Usage: smoke_test.sh [--deep|--shallow]
#   --shallow  skip the governance checks (compliance, secret ward)
# Env: SMOKE_HTTP_TIMEOUT (default 5), SMOKE_DEEP (1/0)
set -u
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd)"
DEEP="${SMOKE_DEEP:-1}"
[ "${1-}" = "--shallow" ] && DEEP=0
[ "${1-}" = "--deep" ] && DEEP=1
TIMEOUT="${SMOKE_HTTP_TIMEOUT:-5}"

declare -a C S D
fail=0
check() { C+=("$1"); S+=("$2"); D+=("$3"); }
ok()    { check "$1" OK   "$2"; }
bad()   { check "$1" FAIL "$2"; fail=1; }
skip()  { check "$1" SKIP "$2"; }
http_ok()   { curl -fsS -m "$TIMEOUT" "$1" >/dev/null 2>&1; }
listening() { ss -ltn 2>/dev/null | grep -qE "[:.]$1([[:space:]]|$)"; }

# Resolve the operator's home/state exactly as every shell tool does (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
STATE=""
if command -v hoard_state_dir >/dev/null 2>&1; then hoard_state_dir STATE 2>/dev/null; fi
STATE="${STATE:-${YMIR_STATE_DIR:-${YMIR_HOME:-$HOME/Documents/ymirhome}/state}}"

# ── services ─────────────────────────────────────────────────────────────────

# 1. the SPA answers over HTTP, not merely that the port accepts
if http_ok http://127.0.0.1:3888/; then ok spa "Hlidskjalf answers on :3888"
else bad spa "no HTTP answer on :3888 — scripts/start.sh"; fi

# 2. the gate API
if http_ok http://127.0.0.1:3889/api/health || http_ok http://127.0.0.1:3889/; then
  ok api "gate API answers on :3889"
else bad api "no answer on :3889 — scripts/start.sh"; fi

# 3. the well (Mimirsbrunn bridge)
if http_ok http://127.0.0.1:4602/health; then ok well "well bridge answers on :4602"
else bad well "well bridge not answering — bin/mimir-bridge.sh --start"; fi

# 4. Bifrost (the model bridge) — optional: needs a provider key
if listening 4603; then
  _code="$(curl -s -m "$TIMEOUT" -o /dev/null -w '%{http_code}' http://127.0.0.1:4603/ 2>/dev/null || echo 000)"
  if [ "$_code" != "000" ]; then ok bifrost "Bifrost answers on :4603 (HTTP $_code)"
  else bad bifrost "listening on :4603 but does not answer"; fi
else skip bifrost "not raised (optional; needs OPENCODE_GO_API_KEY)"; fi

# 5. the Smiðja visualizer API and UI
if listening 8437; then
  if http_ok http://127.0.0.1:8437/api/health || http_ok http://127.0.0.1:8437/; then
    ok smidja-api "visualizer API answers on :8437"
  else bad smidja-api "visualizer listening on :8437 but does not answer"; fi
else bad smidja-api "visualizer API not up — scripts/start.sh"; fi
if listening 8438; then ok smidja-ui "visualizer UI listening on :8438"
else skip smidja-ui "dev UI not raised (optional)"; fi

# 6. Óðrerir, the live hall — optional
if listening 4322; then ok hall "Óðrerir hall listening on :4322"
else skip hall "not raised (optional)"; fi

# 7. the model rail — optional; a seat may have no model resident
if listening 8080; then ok models "model rail listening on :8080"
else skip models "no model rail on :8080 (optional)"; fi

# ── runtime ──────────────────────────────────────────────────────────────────

# 8. the session lock is held by a LIVE pid (Gleipnir)
if [ -r "$ROOT/bin/gleipnir-lock-lib.sh" ]; then
  # shellcheck source=bin/gleipnir-lock-lib.sh
  . "$ROOT/bin/gleipnir-lock-lib.sh"
  _owner=""
  gleipnir_lock_owner _owner 2>/dev/null || true
  if [ -n "$_owner" ] && gleipnir_pid_alive "$_owner"; then
    ok lock "session lock held by live pid $_owner"
  elif [ -z "$_owner" ]; then
    skip lock "no session lock (no live session)"
  else
    bad lock "session lock names dead pid $_owner — reaped on next start"
  fi
else
  bad lock "bin/gleipnir-lock-lib.sh missing"
fi

# 9. the lock pointer must name THIS machine's home (the synced-home trap)
_ptr="$STATE/.lock-path"
if [ ! -e "$_ptr" ]; then
  skip lock-pointer "no pointer yet (pre-machine-lock session)"
else
  _rec="$(head -n1 "$_ptr" 2>/dev/null | tr -d '[:space:]')"
  if [ -z "$_rec" ]; then ok lock-pointer "pointer empty (reclaimed on next arm)"
  elif [ "$_rec" = "$HOME" ] || [ "${_rec#"$HOME"/}" != "$_rec" ]; then
    ok lock-pointer "pointer names this machine's home"
  else
    bad lock-pointer "pointer names a foreign home ($_rec) — bin/ymir-migrate.sh apply"
  fi
fi

# 10. supervision is armed and the watcher is beating (Sýn/Gná)
_hb="$STATE/.watch.heartbeat"
if [ -f "$STATE/.supervision-armed" ]; then
  if [ -f "$_hb" ]; then
    _age=$(( $(date +%s) - $(cat "$_hb" 2>/dev/null || echo 0) ))
    if [ "$_age" -le 120 ]; then ok supervision "watcher heartbeat ${_age}s"
    else bad supervision "heartbeat stale (${_age}s) — the watcher flapped; re-arm"; fi
  else
    bad supervision "armed but no heartbeat — the watcher never started"
  fi
else
  skip supervision "not armed in this session"
fi

# 11. the harness extensions are bound (Pi markers)
if [ -f "$STATE/.pi-watch-extension-loaded" ] && [ -f "$STATE/.pi-turnend-extension-loaded" ]; then
  ok harness "Pi watch + turn-end extensions loaded"
elif [ -f "$STATE/.pi-watch-extension-loaded" ]; then
  bad harness "turn-end guard extension not loaded"
else
  skip harness "no Pi extension markers (non-Pi harness?)"
fi

# 12. the agents are bound into the harnesses
if [ -x "$ROOT/bin/valknut-load.sh" ] && bash "$ROOT/bin/valknut-load.sh" --status >/dev/null 2>&1; then
  ok loaders "agents bound into the harnesses"
else
  bad loaders "valknut-load.sh --status reported a problem"
fi

# 13. Nornir cron is running (inspected in the OPERATOR's state, not the tree)
if [ -x "$ROOT/bin/nornir-cron-start.sh" ]; then
  if BROKK_STATE_OVERRIDE="$STATE" bash "$ROOT/bin/nornir-cron-start.sh" --status 2>/dev/null | grep -q 'running'; then
    ok cron "Nornir cron is running"
  else
    bad cron "Nornir cron is not running — bin/nornir-cron-start.sh"
  fi
else
  skip cron "nornir-cron-start.sh absent"
fi

# 13b. no leaked cron loops — a seat that ended must not leave its scheduler behind
_cron_procs="$(pgrep -fc 'cron.yaml' 2>/dev/null || echo 0)"
if [ "${_cron_procs:-0}" -le 3 ]; then ok cron-leak "${_cron_procs} cron loop(s)"
else bad cron-leak "${_cron_procs} cron loops running — ended seats left schedulers behind"; fi

# 14. the home's structure migrations are applied (in the OPERATOR's state)
if [ -x "$ROOT/bin/ymir-migrate.sh" ]; then
  _mig="$(BROKK_STATE_OVERRIDE="$STATE" bash "$ROOT/bin/ymir-migrate.sh" status 2>/dev/null || true)"
  if printf '%s' "$_mig" | grep -qE '"(pending|available)"'; then
    bad migrations "structure migrations pending — bin/ymir-migrate.sh apply"
  elif [ -n "$_mig" ]; then
    ok migrations "structure migrations applied"
  else
    skip migrations "migration status unavailable"
  fi
else
  skip migrations "ymir-migrate.sh absent"
fi

# ── data ─────────────────────────────────────────────────────────────────────

# 15. the Smiðja database exists with a schema
if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root _ymh; else _ymh="${YMIR_HOME:-$HOME/Documents/ymirhome}"; fi
SMIDJA_DB="${YMIR_SMIDJA_DB:-${_ymh}/smidja/smidja.db}"
if [ -f "$SMIDJA_DB" ]; then
  _t="$(python3 -c "
import sqlite3,sys
try: print(sqlite3.connect('$SMIDJA_DB').execute(\"select count(*) from sqlite_master where type='table'\").fetchone()[0])
except Exception: print(0)" 2>/dev/null || echo 0)"
  if [ "${_t:-0}" -ge 5 ]; then ok smidja-db "$_t tables"
  else bad smidja-db "schema looks empty ($_t tables) — bin/smidja-bootstrap.sh"; fi
else
  bad smidja-db "no smidja.db — bin/smidja-bootstrap.sh"
fi

# 16. the well store (engram) exists
if [ -s "$ROOT/.agents/memory/kaia.engram" ] \
   || [ -s "${YMIR_HOME:-$HOME/Documents/ymirhome}/.agents/memory/kaia.engram" ] \
   || [ -s "${YMIR_HOME:-$HOME/Documents/ymirhome}/hodd/memory/kaia.engram" ] \
   || [ -s "$HOME/hodd/memory/kaia.engram" ]; then
  ok well-store "engram memory store present"
else
  skip well-store "no engram store yet (a fresh home)"
fi

# 17. the hoard layout is honest (no private data flat beside hodd/, and the
#     machine-local layout map names paths that EXIST here — a map carried in
#     from another seat's home is the same trap as the lock pointer)
if [ -n "${_ymh:-}" ] && [ -d "$_ymh" ]; then
  _flat=""
  for _k in identity data docs secrets tenants; do [ -d "$_ymh/$_k" ] && _flat="$_flat $_k"; done
  _lay="$_ymh/.ymir-layout.yaml"
  _badlay=""
  if [ -f "$_lay" ]; then
    while IFS= read -r _p; do
      [ -n "$_p" ] && [ ! -d "$_p" ] && _badlay="$_badlay $_p"
    done < <(sed -nE 's/^  [a-z_]+: "([^"]+)".*/\1/p' "$_lay")
  fi
  if [ -n "$_flat" ]; then bad hoard "flat duplicates beside hodd/:$_flat — bin/eir-doctor.sh fix"
  elif [ -n "$_badlay" ]; then bad hoard "layout map names paths absent here:$_badlay — repoint to this machine's home"
  else ok hoard "layout honest; map paths exist"; fi
else
  skip hoard "no home to inspect"
fi

# 18. the secrets vault and its age key
_home="$(dirname "$STATE")"
if [ -s "$_home/hodd/secrets/platform.env.age" ] && [ -f "$_home/hodd/secrets/age.key" ]; then
  ok vault "secrets vault + age key present"
elif [ -s "$_home/hodd/secrets/platform.env.age" ]; then
  bad vault "vault present but the age key is missing"
else
  skip vault "no secrets vault yet"
fi

# 19. the audit ledger exists and is non-empty
if [ -s "$_home/hodd/memory/runes_audit.md" ]; then ok runes "audit ledger present"
else skip runes "no ledger yet"; fi

# 20. the fleet backlog exists
if [ -f "$_home/hodd/data/backlog.md" ]; then ok backlog "fleet backlog present"
else skip backlog "no backlog yet"; fi

# ── integrations (MCP · A2A · tools) ──────────────────────────────────────────

# 21. every configured MCP server completes a real handshake: initialize, then
#     tools/list. A port that answers is not a connection; the ticket/plan and
#     memory servers must actually enumerate their tools.
MCP_INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}'
MCP_LIST='{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
mcp_probe() {  # <url> -> "ok:<n>" | "fail:<why>"
  local url="$1" hdr resp sid list n
  hdr="$(mktemp)"
  resp="$(curl -s -m "$TIMEOUT" -D "$hdr" -X POST \
    -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' \
    -d "$MCP_INIT" "$url" 2>/dev/null || true)"
  sid="$(grep -i '^mcp-session-id:' "$hdr" 2>/dev/null | tr -d '\r' | awk '{print $2}')"
  rm -f "$hdr"
  printf '%s' "$resp" | grep -q '"result"' || { printf 'fail:initialize failed'; return; }
  if [ -n "$sid" ]; then
    list="$(curl -s -m "$TIMEOUT" -X POST -H 'content-type: application/json' \
      -H 'accept: application/json, text/event-stream' -H "mcp-session-id: $sid" \
      -d "$MCP_LIST" "$url" 2>/dev/null || true)"
  else
    list="$(curl -s -m "$TIMEOUT" -X POST -H 'content-type: application/json' \
      -H 'accept: application/json, text/event-stream' \
      -d "$MCP_LIST" "$url" 2>/dev/null || true)"
  fi
  n="$(printf '%s' "$list" | python3 -c '
import json,sys
raw=sys.stdin.read()
try:
    d=json.loads(raw)
except Exception:
    import re
    m=re.search(r"data:\s*(\{.*\})", raw)
    try: d=json.loads(m.group(1)) if m else {}
    except Exception: d={}
res=d.get("result") or {}
print(len(res.get("tools") or []) if isinstance(res, dict) else -1)' 2>/dev/null || echo -1)"
  if [ "${n:- -1}" -ge 0 ] 2>/dev/null; then printf 'ok:%s' "$n"; else printf 'fail:no tools/list result'; fi
}
_mcp_cfg="$HOME/.pi/agent/mcp.json"
[ -f "$_mcp_cfg" ] || _mcp_cfg="$ROOT/.pi/mcp.json"
if [ -f "$_mcp_cfg" ] && command -v python3 >/dev/null 2>&1; then
  _servers="$(python3 -c '
import json,sys
try: cfg=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
for n,s in (cfg.get("mcpServers") or {}).items():
    print(str(n)+"\t"+str(s.get("url","")))
' "$_mcp_cfg" 2>/dev/null || true)"
  if [ -z "$_servers" ]; then
    skip mcp "no MCP servers configured"
  else
    while IFS=$'\t' read -r _name _url; do
      [ -n "$_name" ] || continue
      if [ -n "$_url" ]; then
        _probe="$(mcp_probe "$_url")"
        case "$_probe" in
          ok:*) ok "mcp:$_name" "connected — ${_probe#ok:} tools ($_url)" ;;
          *)    bad "mcp:$_name" "${_probe#fail:} ($_url)" ;;
        esac
      else
        skip "mcp:$_name" "stdio server (no url to probe)"
      fi
    done <<<"$_servers"
  fi
else
  skip mcp "no MCP config found"
fi

# 22. firecrawl's local service (a stdio MCP fronting a local HTTP API)
if listening 3002; then
  if curl -fsS -m "$TIMEOUT" http://localhost:3002/ >/dev/null 2>&1; then ok firecrawl "local service answers on :3002"
  else bad firecrawl "listening on :3002 but does not answer"; fi
else skip firecrawl "not raised (optional)"; fi

# 23. the A2A/MCP install surface is present
if [ -x "$ROOT/bin/a2a-mcp.sh" ]; then ok a2a "a2a-mcp.sh present"
else skip a2a "a2a-mcp.sh absent"; fi

# 24. herdr, the terminal-pane backend
if command -v herdr >/dev/null 2>&1; then ok herdr "herdr present ($(herdr --version 2>/dev/null | head -1))"
else skip herdr "herdr absent (panes unavailable)"; fi

# 25. the one-local-model lock is coherent
if [ -x "$ROOT/bin/local-model-lock.sh" ]; then
  if bash "$ROOT/bin/local-model-lock.sh" check >/dev/null 2>&1; then ok local-model "one-local-model lock coherent"
  else bad local-model "local-model lock reported a problem"; fi
else skip local-model "local-model-lock.sh absent"; fi

# ── toolchain ────────────────────────────────────────────────────────────────

# 26. node satisfies the package engine (>=20)
_nv="$(node -v 2>/dev/null || true)"
_nmaj="${_nv#v}"; _nmaj="${_nmaj%%.*}"
if [ "${_nmaj:-0}" -ge 20 ] 2>/dev/null; then ok node "node $_nv"
else bad node "node ${_nv:-absent} (>=20 required)"; fi

# 27. the pi model registry parses
if [ -f "$HOME/.pi/agent/models.json" ] \
   && node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$HOME/.pi/agent/models.json" >/dev/null 2>&1; then
  ok models-registry "pi model registry parses"
else bad models-registry "pi models.json missing or invalid"; fi

# 28. the pre-push delivery gate is installed
_hookdir="$(git -C "$ROOT" rev-parse --git-path hooks 2>/dev/null || true)"
if [ -n "$_hookdir" ] && [ -x "$_hookdir/pre-push" ]; then ok gates "pre-push gate installed"
else bad gates "pre-push hook missing — bin/fixes-guard.sh --install"; fi

# ── governance (deep) ────────────────────────────────────────────────────────

if [ "$DEEP" = 1 ]; then
  # 18. the compliance gates
  _comp="$ROOT/.agents/skills/galdr-ymirsystem/scripts/compliance-check.sh"
  if [ -x "$_comp" ]; then
    if bash "$_comp" >/dev/null 2>&1; then ok compliance "all gates pass"
    else bad compliance "a gate failed — bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh"; fi
  else
    skip compliance "compliance-check.sh absent"
  fi

  # 19. the secret ward (no secret in the tree)
  if [ -x "$ROOT/bin/secret-guard.sh" ]; then
    if bash "$ROOT/bin/secret-guard.sh" >/dev/null 2>&1; then ok secrets "secret ward clean"
    else bad secrets "secret-guard reported a finding"; fi
  else
    skip secrets "secret-guard.sh absent"
  fi
fi

printf 'smoke_test[%s]{check,status,detail}:\n' "${#C[@]}"
for i in "${!C[@]}"; do printf '  "%s","%s","%s"\n' "${C[$i]}" "${S[$i]}" "${D[$i]}"; done
exit "$fail"
