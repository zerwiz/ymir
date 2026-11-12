## skills · unversioned · 2026-11-10 — Hnoss reaches the provider pi itself uses

### Why

- **Every design generation was dead, and silently so.** `open-design-mcp` reaches a
  model through BYOK: it composes the design prompt and POSTs it to the daemon's
  `/api/proxy/<provider>/stream`, which forwards it to `BYOK_BASE_URL`. The launcher
  that supplied those variables was a hand-file placed outside the tree. It read
  `defaultProvider` from pi's `settings.json` and looked that provider up in
  `models.json` — and the Allfather's provider is **`opencode-go`, a provider built
  INTO pi and therefore absent from `models.json`**. So the lookup missed, the door
  fell back to `http://127.0.0.1:8080/v1` (the local rail), and it paired that rail
  with `deepseek-v4.1-flash`. A door and a model that cannot answer each other.
- **The gateway needs a header the BYOK client cannot send.** Both opencode-go
  endpoints (`https://opencode.ai/zen/go/v1`, `https://opencode.ai/inference/go/openai/v1`)
  answer `400 MissingSessionID` unless the request carries `x-opencode-session`.
  Measured this day: no header → 400; with header → the model answers. `open-design-mcp`
  has no way to add it, so pointing BYOK straight at the gateway could never have worked
  either — the missing piece was a door, not a URL.
- **The daemon could not finish a real page.** The image bakes
  `NODE_OPTIONS=--max-old-space-size=192`; a real generation (a ~40 kB composed system
  prompt plus a streamed page) died with `FATAL ERROR: Ineffective mark-compacts near
  heap limit`, which the client reported only as `OD daemon unreachable: terminated`.
  The operator's deploy `.env` had no say: `bin/pi/open-design.sh` called Compose from
  whatever directory it was run in, and Compose v2 reads `.env` from the caller's
  directory — so every value in `~/opendesign/deploy/.env` was ignored and the defaults
  applied.
- **And the door was a copy.** A launcher that exists only as a hand-file is seated by
  nothing, mended by nothing and checked by nothing.

### Fix

- **`bin/pi/hnoss-mcp-launch.sh` is shipped.** It resolves the provider, the model and
  the credential from pi — `pi auth print-api-key` first, pi's files second — and then
  chooses the door:
  - a provider in `models.json` (the rails) → its own `baseUrl`, dialled directly;
  - a provider built into pi → the **Bifrost bridge** (`bin/bridge/bifrost-bridge.sh`),
    the shipped loopback bridge that already adds `x-opencode-session` and holds the
    gateway key. Hnoss gets its **own** instance on `:4613`, so it never fights the
    shared `:4603` bridge for a provider;
  - anything else → a **loud refusal** naming the provider. No silent fallback to the
    rail: a design generated on a model nobody asked for is worse than no design.
  `--resolve` answers with no bridge raised and no network, so a status check has no
  side effects; `--print` raises the door and prints it.
- **The bridge tells the truth about itself.** `--status` now reports the provider read
  from the LIVE process, not the flag the caller passed (that is how a bridge sitting on
  `lmstudio` reported itself green for an `opencode-go` caller). `--ensure --provider N`
  raises the door on `N`, restarts one that answers on something else, and refuses to
  call a wrongly-providen bridge green. State is **port-scoped**
  (`model-bridge-<port>.pid|log`, the default port keeping its old names), so a second
  instance is legal and `--stop --port N` kills only that port's process.
- **The model is named in the log.** `model-bridge.py` prints `model=<id>
  provider=<provider>` for every request; the daemon logs `[proxy:openai] POST …
  model=<id>`. A generation can now be PROVEN to have used the model it claims.
- **`bin/pi/hnoss-ensure.sh` seats and checks it:** the shipped launcher, the `hnoss`
  MCP entry merged into `~/.pi/agent/mcp.json` and `mcp-adapter.json` (every other
  server kept), a compatibility shim at any old path a config still names, and the model door
  resolved. A machine with no design studio reports a clean skip, not a red.
- **The daemon's heap and `.env`**: `bin/pi/open-design.sh` passes
  `--env-file ~/opendesign/deploy/.env` explicitly, and the deployment's compose sets
  `NODE_OPTIONS` from `.env` (this seat: `--max-old-space-size=1024`).

### Verified

- One real generation THROUGH the MCP (stdio `initialize` → `tools/call
  od_generate_design`) returned content: 1178 chars on the first proven run, 631 on the
  second ("Blackwater Forge — Hero", real HTML/CSS). `initialize` →
  `open-design-mcp 0.16.1`.
- The model is named in both logs, on the same requests:
  - `state/model-bridge-4613.log`: `[bridge] model=deepseek-v4.1-flash
    provider=opencode-go stream=True` with `"POST /v1/chat/completions HTTP/1.1" 200`;
  - the daemon: `[proxy:openai] POST 127.0.0.1 model=deepseek-v4.1-flash`.
- `bin/pi/hnoss-ensure.sh status` → `"model door","resolves","opencode-go ·
  deepseek-v4.1-flash · http://127.0.0.1:4613/v1"`, `"pi mcp entry","seated"`.
- `.agents/tests/hnoss-model-door.test.sh` → PASS, offline and without raising a
  service: a built-in provider resolves to the bridge and **not** to `:8080`; a registry
  rail resolves to its own URL; a provider with no door is refused and named; `--status`
  reads the process rather than the flag; `--ensure` will not call a wrongly-providen
  bridge green; `--stop` closes only its own port.
- `eir-doctor check` reports the new `hnoss` surface `ok`.

### Still standing

- `openrouter` (and any future pi built-in) has no door here; the launcher refuses it by
  name. Adding one means teaching `model-bridge.py` that provider, not guessing a URL.
- The composition of a full page on a slow model still takes minutes; that is the
  engine, not this door.

### Files

- `bin/pi/hnoss-mcp-launch.sh` (new) — the shipped launcher
- `bin/pi/hnoss-ensure.sh` (new) — seat + check
- `bin/pi/open-design.sh` — `--env-file` so the deployment's `.env` is read
- `bin/bridge/bifrost-bridge.sh` — `--ensure`, truthful `--status`, port-scoped state
- `.agents/backend/model-bridge.py` — `--bind`, `--providers`, the model on every log line
- `.agents/skills/hnoss-design/SKILL.md`, `DESIGN.md` — the dated addenda
- `.agents/tests/hnoss-model-door.test.sh` (new) — the regression test
- `docs/features/design-with-hnoss.md` (new) + its catalogue row

## CHANGE LOG

- **2026-11-10** — written with the fix it records: Hnoss's launcher resolves a pi
  built-in provider through the Bifrost bridge instead of falling back to the local rail.
