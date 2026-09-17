# The Well — Mimirsbrunn (engram) memory, bridge, and harness wiring

> **Purpose:** Everything an agent must know to operate, extend, or rebuild
> Ymir's memory: the store, the HTTP bridge, the MCP server, the harness
> registrations, the laws, and the UI. The **code is authoritative**; this page
> explains the whole of it.

The well is **Mimirsbrunn**, backed by the validated OSS engine **engdbram**
(`pip install engdbram`) — the *module* it provides is `engram`.

> **The name trap.** PyPI's `engram` is an unrelated *rendering* library
> (mitsuba/drjit/torch). Installing it pulls gigabytes of CUDA wheels and still
> leaves Ymir with no memory engine. The distribution is **`engdbram`**;
> `bin/prereq-ensure.sh engram` installs the right one. It is **one repo-local store** shared by every agent and
every harness. Motto: **drink before you act, water it after** — recall on the
way in, observe on the way out.

---

## 1. Components

| Component | Path | Role |
|---|---|---|
| Store | `$YMIR_HOME/hodd/memory/kaia.engram` | THE single SQLite memory (episodes, facts, entities) — one well, always in the hoard (Rule 04/07); resolved via `hoard_memory_store` (hoard-lib) or the `ENGRAM_DB` override |
| Append log | `.agents/memory/well/episodes.jsonl` | the raw episode log (source of truth for re-seeding) |
| HTTP bridge | `bin/mimir-bridge.py` (+ `bin/mimir-bridge.sh`) | the `:4602` face over the engram library |
| CLI | `bin/mimir.sh` | operator CLI: `health` `recall` `observe` `timeline` |
| Ingest | `bin/mimir-ingest.sh` | drinks a directory into the JSONL well + bridge |
| Gate API | `apps/hlidskjalf/server/index.ts` | `/api/well`, `/api/well/episode`, `/api/mimir/health` |
| UI | `apps/hlidskjalf/src/gates/Well.tsx` + `components/RecallPanel.tsx` | recall panel, timeline, click-to-read |
| MCP server | `engram-mcp` (console script) | stdio MCP: `remember` `recall` `why` `forget` `stats` |

The upstream engine ships a **CLI + MCP stdio server only** — there is no
`engram.server` HTTP module. `bin/mimir-bridge.py` is Ymir's own face, because
the gate API, `mimir.sh`, and `mimir-ingest.sh` speak HTTP on `:4602`.

`bin/mimir-ingest.sh` loads every stored hash once into an associative array, so
dedupe is O(1) per section rather than rescanning the whole store each time (was
O(sections × store)); `bin/workspace-rag.sh index` reads the store once and walks
all files in a single Python pass (was a store read + process spawn per file).

**Where ingest reads from.** Its source is the hoard's `docs/business`, and the
hoard root resolves through `bin/hoard-lib.sh` (`$YMIR_HOARD`, else `$YMIR_HOME`,
else `$HOME/Documents/Ymir`) — the same one default every other script uses, and
never the repo's `hodd/`, which holds only the guard, README and `*.example`
scaffolds (Rule 04).

---

## 2. HTTP bridge (`:4602`)

Raised by `bin/mimir-bridge.sh --start`; also raised by `scripts/start.sh` and
`bin/saga-session-start.sh`, so it is up whenever the stack is up.

```
GET  /health                 -> {status, store, episodes, agents}
GET  /recall?q&k&mode        -> {results:[{score, distance, importance, episode}]}
GET  /recent?limit           -> {episodes:[...]}
GET  /episode?id=<id>        -> {episode:{id, content, timestamp, tags, actors, agent_id}}
GET  /timeline?entity        -> {facts:[...]}
GET  /inspect                -> {store, episodes, agents}
POST /observe {content,...}  -> {id, agent_id, episodes}
```

Mode is `hybrid` (default) | `cosine` | `spreading`. The bridge is **read-all**
by default (an unscoped `Engram`), so recall sees every episode regardless of
which agent wrote it.

---

## 3. MCP for harnesses (the shared well)

`engram-mcp --db $YMIR_HOME/hodd/memory/kaia.engram` — **unscoped**, so
every harness reads the one well. (A scoped `--agent-id` filters reads to that
agent and would hide the seeded `well` episodes; pass `agent_id` per `remember`
call instead when attribution is wanted.)

| Harness | Config | Notes |
|---|---|---|
| OpenCode (4 accounts: `opencode`, `opencode-rd`, `opencode-work`, `opencode-oczer`) | `<config-dir>/opencode.json` → `mcp.engram` | `{type:"local", command:["engram-mcp","--db",…], enabled:true}` |
| Pi | `~/.pi/agent/settings.json` → `mcpServers.engram` **and** `~/.pi/agent/mcp.json` + repo `.pi/mcp.json` (pass `pi --mcp-config .pi/mcp.json`) | pi-mcp-adapter. **Scope:** `bin/a2a-mcp.sh install` writes the GLOBAL `~/.pi/agent/mcp.json`; `install --project` writes the repo's `.pi/mcp.json` instead and never touches `~/.pi` — use it when Pi is run in other areas. |
| Claude Code | `~/.claude.json` → `mcpServers.engram` | |
| Cursor | `~/.cursor/mcp.json` → `mcpServers.engram` | |
| Codex | `~/.codex/config.toml` → `[mcp_servers.engram]` | args are a TOML array |

**Hard dependency:** `engram-mcp` needs the **`mcp<2`** SDK (mcp 2.x renamed
`FastMCP`→`MCPServer` and breaks engram 1.x/2.x):

```
python3 -m pip install --user --break-system-packages 'mcp<2'
```

---

## 4. Laws

```
well_laws[5]{id,law}:
  1,"No mock data — the well holds only true observations; test writes are purged"
  2,"Drink before you act — recall on the way in; never answer the Allfather dry"
  3,"Water it after — observe a lesson once it lands"
  4,"Hoarded — the store is $YMIR_HOME/hodd/memory/kaia.engram (one well, never a duplicated migrated copy)"
  5,"One well — every harness shares it; scope per-call, never per-server"
```

Words that *discuss* mock data (docs about removing mocks) are real knowledge
and stay; entries that *are* test/mock are removed.

---

## 5. Operate & verify

```
bin/mimir-bridge.sh --status          # well[1]{port,status}: 4602,"up"
bin/mimir.sh health                   # WARM/COLD + entry count + online
bin/mimir.sh recall "sales pipeline"  # semantic recall (bridge) with local fallback
curl -s localhost:4602/health         # {"status":"up","episodes":367,"agents":["well"]}
curl -s 'localhost:4602/episode?id=<id>'   # full memory text
```

Re-seed the store from the JSONL well (idempotent spirit; dedupe by hash):

```
python3 - <<'PY'
import json
from datetime import datetime
from engram import Engram
eng = Engram(path="~/Documents/Ymir/hodd/memory/kaia.engram", agent_id="well")
for l in open("~/Documents/Ymir/hodd/memory/well/episodes.jsonl"):
    if not l.strip().startswith("{"): continue
    e = json.loads(l); ts = e.get("timestamp")
    when = datetime.fromisoformat(ts.replace("Z","+00:00")) if ts else None
    eng.observe(e["content"], actors=[e.get("source","well")], tags=e.get("tags",["well"]), timestamp=when)
PY
```

---

## 6. UI

The **Well** gate (`#/well`) shows live metrics (episodes, bridge state from
`/api/mimir/health`) and a real timeline derived from episodes. Each recalled
episode is **clickable** — `RecallPanel` calls `onOpen(id)`, `Well` fetches
`/api/well/episode?id=` and opens the full memory text in a modal. The old
hardcoded timeline is gone.

---

## 7. Troubleshooting

- **MCP recall returns `[]`** → the server is scoped (`--agent-id`); drop it for
  the shared well.
- **`ModuleNotFoundError: mcp.server.fastmcp`** → mcp 2.x installed; pin `mcp<2`.
- **First `observe` slow (~20–30 s)** → the embedding model is warming; later
  writes are instant.
- **Bridge down / `COLD`** → `bin/mimir-bridge.sh --start`; check
  `$YMIR_STATE_DIR/mimir-bridge.log` — runtime state lives in the home the
  operator chose (`hoard_state_dir` via `bin/hoard-lib.sh`), never in the code
  tree: a packaged install replaces its tree on upgrade.

**Portability.** The bridge signals processes through `ymir_kill_matching` from
`bin/ymir-platform.sh` rather than calling `pkill` directly, because `pkill` is
absent on some MSYS/WSL images (Rule 05, one place knows the difference).
