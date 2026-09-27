## runtime · unversioned · 2026-09-27 — the living rail resolver (plan 51 Parts 9a/9b/9c)

### Why

The model lane had no owner. Every surface that needed to know where models came
from restated it itself: `bin/model-placement.sh` built rail URLs from the
registry, `bin/eindri-route.sh` assumed a `forge` role, `bin/snotra-transcribe.sh`
defaulted to `http://127.0.0.1:8080/v1`, and the alias gate gathered aliases from
whichever rails it could reach. The Allfather's word (plan 51 Part 9c): *models
come from whichever strong box is CONNECTED at the moment* — heimdall · whynot ·
omarchy — and "the WHERE-MODELS-COME-FROM logic must be in MANY things, never
restated per script. One resolver, called by all." A dropped box must reroute,
never be an outage.

### What

- **`src/ymir_runtime/fleet/rail.py`** (new package `fleet/`) — the ONE resolver.
  It reads the private registry (`$YMIR_HOME/hodd/data/fleet.json`, never
  shipped), names the strong boxes in rank order (`rails` list → `ear` list →
  `forge` hosts; a box the registry does not declare is never invented), probes
  LIVENESS (`GET /health` keyless and cheap, then `GET /v1/models` with the shared
  key — a refused key still reads ALIVE), and answers the first live box in rank
  order. With an alias it answers the first live box that SERVES it. Every rail
  down, or no live box serving the name, is a **declined** answer (exit 1) — never
  a fake URL. The shared key is a REFERENCE (`LLAMA_SWAP_API_KEY`: env → the hoard
  vault → pi auth.json); the value is read only to ask a rail what it serves and
  is never emitted. `__main__.py` is its module CLI; `__init__.py` its face.
- **`bin/rail-resolve.sh`** (new door) — `resolve [alias]` · `status`, TOON for a
  human and `--json` for callers; picks the engine venv or python3, resolves the
  home through `bin/hoard-lib.sh`, and never restates a path or a rail URL.
- **The many now call it:**
  - `bin/model-placement.sh` — the ranked rails and their reachability come from
    the resolver; the TOON/JSON fields are unchanged.
  - `bin/eindri-route.sh` — a `model` errand follows the ranked live set
    (first-alive at its head), falling back to the registry's `forge` hosts only
    when nothing is alive; the planner still never invents a box.
  - `bin/model-alias-check.sh` — the served set is the union over the RESOLVED
    provider's live rails, and a `model_alias_rail` row names the serving box: a
    seat's name resolves against whichever box serves.
  - `bin/snotra-transcribe.sh` — the ear's summary rail defaults to the resolver's
    serving box; `RAIL_URL` still forces one.
  - `bin/mcp-gateway.sh` — a `rail [resolve|status]` verb delegating to the
    resolver, and a `rail` row in `status`. The rail is NEVER an MCP upstream (the
    upstream map is handed to the engine verbatim).
  - `bin/mcp-config.sh` — the resolved rail rides the seat config's `ymir` block
    (`host` · `url` · `keyRef`); harnesses read `mcpServers`, so it is advisory
    metadata, and the MCP door/parity are unchanged.
- **Configs carry the truth.** `config/fleet.json.example` and
  `fleet.schema.json` gain the ordered `rails` list (models) and `ear` list (the
  ear), and `patternProperties ^_comment` — which also mends a pre-existing
  drift: the live registry's `ear`/`_comment_ear` keys were being REFUSED by the
  schema (`ymir-config-check validate` now passes both the example and the live
  registry).
- **`src/pyproject.toml`** ships the new `ymir_runtime.fleet` package.

### Proof (live, on heimdall)

- `bin/rail-resolve.sh resolve` → `heimdall · http://127.0.0.1:8080/v1 ·
  LLAMA_SWAP_API_KEY`; `status` → heimdall `health`, whynot `health`, omarchy
  `timeout` — matching the tailnet reality (whynot up, omarchy offline).
- `bin/rail-resolve.sh resolve qwen3.6-35b-a3b@iq3_s` → heimdall, alias verified;
  `resolve no-such-alias@nowhere` → declined, exit 1.
- `bin/eindri-route.sh model` → `heimdall,whynot` (the live set, first-alive at
  its head).
- `bin/model-alias-check.sh --local` → `pass`, `model_alias_rail` = heimdall,
  live_boxes 2.
- `bin/mcp-gateway.sh rail status` and `bin/mcp-config.sh show` (`ymir.rail`)
  answer the same serving box.
- `python3 -m unittest` from the repo root — **296 tests OK** (20 new in
  `test_rail.py`: one box up and one down → the up one serves; both down →
  declined; an alias picks the box that serves it; an undeclared box is never
  invented).
- `.agents/tests/rail-resolve.test.sh` — **ALL PASS** (a stub rail: the alive box
  serves, a dropped box is declined and prints no fake URL, a mocked registry
  flips the answer, and the key value never appears in the answer).
- `bash bin/guards.sh` — both wards PASS; `bash -n` clean on every changed script.

galdr-reread: `brokk-distro-runtime.md` (§7.8, the fleet registry readers),
`harness-integration/README.md` (the MCP door block, the rail resolved the same
way), `installation.md` (the `fleet` row), `snotra-meeting-ear.md` (M6, the living
rail).

### Files

- `src/ymir_runtime/fleet/rail.py` (new)
- `src/ymir_runtime/fleet/__init__.py` (new)
- `src/ymir_runtime/fleet/__main__.py` (new)
- `bin/rail-resolve.sh` (new)
- `src/ymir_runtime/tests/test_rail.py` (new)
- `.agents/tests/rail-resolve.test.sh` (new)
- `config/fleet.json.example`
- `config/fleet.schema.json`
- `src/pyproject.toml`
- `bin/model-placement.sh`
- `bin/eindri-route.sh`
- `bin/model-alias-check.sh`
- `bin/snotra-transcribe.sh`
- `bin/mcp-gateway.sh`
- `bin/mcp-config.sh`
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`
- `.agents/skills/galdr-ymirsystem/assets/installation.md`
- `.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md`
