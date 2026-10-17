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
> `bin/engine/prereq-ensure.sh engram` installs the right one. It is **one repo-local store** shared by every agent and
every harness. Motto: **drink before you act, water it after** — recall on the
way in, observe on the way out.

---

## 1. Components

| Component | Path | Role |
|---|---|---|
| Store | `$YMIR_HOME/hodd/memory/kaia.engram` | THE single SQLite memory (episodes, facts, entities) — one well, always in the hoard (Rule 04/07); resolved via `hoard_memory_store` (hoard-lib) or the `ENGRAM_DB` override |
| Append log | `.agents/memory/well/episodes.jsonl` | the raw episode log (source of truth for re-seeding) |
| HTTP bridge | `bin/bridge/mimir-bridge.py` (+ `bin/bridge/mimir-bridge.sh`) | the `:4602` face over the engram library |
| CLI | `bin/records/mimir.sh` | operator CLI: `health` `recall` `observe` `timeline` |
| Ingest | `bin/records/mimir-ingest.sh` | drinks a directory into the JSONL well + bridge |
| Gate API | `apps/hlidskjalf/server/index.ts` | `/api/well`, `/api/well/episode`, `/api/mimir/health` |
| UI | `apps/hlidskjalf/src/gates/Well.tsx` + `components/RecallPanel.tsx` | recall panel, timeline, click-to-read |
| MCP server | `engram-mcp` (console script) | stdio MCP: `remember` `recall` `why` `forget` `stats` |

The upstream engine ships a **CLI + MCP stdio server only** — there is no
`engram.server` HTTP module. `bin/bridge/mimir-bridge.py` is Ymir's own face, because
the gate API, `mimir.sh`, and `mimir-ingest.sh` speak HTTP on `:4602`.

`bin/records/mimir-ingest.sh` loads every stored hash once into an associative array, so
dedupe is O(1) per section rather than rescanning the whole store each time (was
O(sections × store)); `bin/records/workspace-rag.sh index` reads the store once and walks
all files in a single Python pass (was a store read + process spawn per file).

**Where ingest reads from.** Its source is the hoard's `docs/business`, and the
hoard root resolves through `bin/vault/hoard-lib.sh` (`$YMIR_HOARD`, else `$YMIR_HOME`,
else `$HOME/Documents/ymirhome`) — the same one default every other script uses, and
never the repo's `hodd/`, which holds only the guard, README and `*.example`
scaffolds (Rule 04).

---

## 2. HTTP bridge (`:4602`)

Raised by `bin/bridge/mimir-bridge.sh --start`; also raised by `scripts/start.sh` and
`bin/time/saga-session-start.sh`, so it is up whenever the stack is up.

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
| Pi | `~/.pi/agent/settings.json` → `mcpServers.engram` **and** `~/.pi/agent/mcp-adapter.json` + repo `.pi/mcp-adapter.json` (pass `pi --mcp-config .pi/mcp-adapter.json`) | pi-mcp-adapter. **Scope:** `bin/bridge/a2a-mcp.sh install` writes the GLOBAL `~/.pi/agent/mcp-adapter.json`; `install --project` writes the repo's `.pi/mcp-adapter.json` instead and never touches `~/.pi` — use it when Pi is run in other areas. |
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
well_laws[6]{id,law}:
  1,"No mock data — the well holds only true observations; test writes are purged"
  2,"Drink before you act — recall on the way in; never answer the Allfather dry"
  3,"Water it after — observe a lesson once it lands"
  4,"Hoarded — the store is $YMIR_HOME/hodd/memory/kaia.engram (one well, never a duplicated migrated copy)"
  5,"One well — every harness shares it; scope per-call, never per-server"
  6,"One resolver — the bridge resolves the home through bin/vault/hoard-lib.sh; a private default is refused by bin/gates/guards/defaults-guard.sh (2026-09-24)"
```

Words that *discuss* mock data (docs about removing mocks) are real knowledge
and stay; entries that *are* test/mock are removed.

---

## 5. Operate & verify

```
bin/bridge/mimir-bridge.sh --status          # well[1]{port,status}: 4602,"up"
bin/bridge/mimir-bridge.sh --foreground      # run under a supervising unit (mimir.service)
bin/records/mimir.sh health                   # WARM/COLD + entry count + online
bin/records/mimir.sh recall "sales pipeline"  # semantic recall (bridge) with local fallback
curl -s localhost:4602/health         # {"status":"up","episodes":367,"agents":["well"]}
curl -s 'localhost:4602/episode?id=<id>'   # full memory text
```

Re-seed the store from the JSONL well (idempotent spirit; dedupe by hash):

```
python3 - <<'PY'
import json
from datetime import datetime
from engram import Engram
eng = Engram(path="~/Documents/ymirhome/hodd/memory/kaia.engram", agent_id="well")
for l in open("~/Documents/ymirhome/hodd/memory/well/episodes.jsonl"):
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
- **Bridge down / `COLD`** → `bin/bridge/mimir-bridge.sh --start`; on a dev seat the
  mend is `systemctl --user restart mimir.service`; check
  `$YMIR_STATE_DIR/mimir-bridge.log` — runtime state lives in the home the
  operator chose (`hoard_state_dir` via `bin/vault/hoard-lib.sh`), never in the code
  tree: a packaged install replaces its tree on upgrade.

**Portability.** The bridge signals processes through `ymir_kill_matching` from
`bin/fleet/ymir-platform.sh` rather than calling `pkill` directly, because `pkill` is
absent on some MSYS/WSL images (Rule 05, one place knows the difference).

---

## 8. The log is the truth; the engram is derived (2026-10-12)

**Appended — the shape above still holds; this names which artifact carries the
memory across machines.** The fleet's wells had forked: the heart published its
engram and no seat pulled it, while every seat's bridge wrote its own local index.
The law is now explicit.

```
truth[3]{artifact,role,merges_by}:
  "hodd/memory/well/episodes.jsonl","the append log — the durable, unionable record","union (text, hash-deduped)"
  "hodd/memory/kaia.engram","a derived, PER-SEAT index rebuilt from the log","never — export -> union -> reseed"
  "hodd/memory/runes_audit.md","the chained ledger — it has its own fusion process","quarantine + ONE ledger.fusion entry"
```

**Every observe reaches the log.** `bin/bridge/mimir-bridge.py` appends each
observation (full record, hash-deduped) as it writes the store. The bridge is the
one door every harness passes through (`pi`, `opencode`, `claude`, `cursor`, `codex`),
so the log is complete by construction — before this, only `mimir.sh` and
`mimir-ingest.sh` appended, and the log held 5 lines against 101 episodes.

**`bin/records/mimir-log.{py,sh}` — the reconciliation, both ways:**

```
mimir-log[4]{verb,direction,meaning}:
  "export","engram -> log","append every episode the log lacks (hash-deduped)"
  "reseed","log -> engram","observe every record the index lacks (hash-deduped)"
  "union","other -> log","append another log's records we lack — APPEND-ONLY, never a rewrite"
  "verify","both counts","the gap that must be zero"
```

**`bin/time/well-vault-sync.sh`** rides only the log. `--mode push` exports then
publishes it; `--mode pull` exports this seat's memory, unions origin's log, and
re-seeds the local index. `--mode sync` is both. The binary engram is never
git-merged, and a pull that would overwrite a dirty tracked file is *refused* —
so a seat's memory is never lost. Because the whole log rides the vault, **a seat
holds the whole memory with the heart down**, and publishes its own when the heart
returns: the heart is the main port, never a single point of failure.

**One interpreter.** `bin/bridge/mimir-bridge.sh --python` prints the resolved
engram interpreter; `mimir-log.sh` calls it, so the log tool and the bridge never
disagree about which python owns the store.


## The law the well obeys: IT APPENDS (2026-10-17)

**Appended at the Allfather's word:** *"the well must always append only."* The rule
is `RULES/20-the-well-appends.md`; the ward is `bin/records/well-guard.sh`.

```
well_law[4]{rule}:
  "APPEND, never replace","an episode is written once and stays. No rebuild, no regenerate, no recover-over, no resync in place."
  "A SECOND TRUTH IS A LOSS","two wells fork into a UNION — every record from both is appended. `resync` on a well means append, never overwrite."
  "REPAIR ADDS, IT DOES NOT SUBTRACT","a corrupt store is preserved as found; recovery APPENDS beside the live one; what cannot be read is recorded as a known gap."
  "THE COUNT NEVER FALLS","the episode count and the log's line count are monotonic. A run that lowers either is a failure, not a tidy-up."
```

**Why it is law, not preference — the incident:** on **2026-10-07** the store was
malformed (`btreeInitPage() error code 11`). It was preserved by hand and salvaged
with `sqlite3 .recover`, which keeps only the pages it can read: **134 episodes became
98 — 36 lost.** Sixteen were later restored from `git` (the 2026-09-28 blob); twenty
(date-range 2026-10-04..06) existed nowhere else. **Nothing noticed for ten days** —
the store had shrunk by a third and the loss rode the vault. The missing ward, not the
missing tooling, is what this asset and Rule 20 make impossible to repeat.

**What is permitted:** appending; appending a fork's missing records (the log union);
restoring a lost episode from git or another seat (with provenance tags); annotating an
episode — a tag — without touching its content; removing an episode from a **derived**
index (a vector row, an FTS row) while the record stays.
**What is forbidden:** deleting an episode; rebuilding the store from a subset;
restoring an older snapshot *over* a newer one; `git checkout` of the binary store over
a live one; a "merge" that picks one side.

**The ward (`bin/records/well-guard.sh`):**

```
well-guard[3]{verb,what,exit}:
  "check","episode count and log lines against the checkpoint, junk content (empty or `undefined`), episodes with no vector","1 on any loss, junk or unindexed row; 1 when the store cannot be read at all"
  "record","roll the checkpoint forward AFTER a passing check","1 when the check fails (never records a loss as the new normal)"
  "--self-test","build a temp well, record, check, remove one episode, prove the ward bites","0 when the ward bites"
```

A row declared void by an appended correction (tag `void:…`) is counted as *recorded*,
not as junk — the record keeps it, the ward does not nag about it, and the episode is
excluded from the vector index so it cannot be recalled as fact.

Eir composes it as the `well` surface, so a loss is reported the next time anyone
diagnoses the house; `check` rides `record` after a passing run, so the checkpoint
follows a healthy well forward.
