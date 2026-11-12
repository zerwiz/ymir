## DESIGN SYSTEM

**Brand:** The house of Ymir — stone and bone, bronze and blood

**Palette:** stone `#0e0c09` · panel `#151209` · bronze `#c9973f` · line `#2b241a` ·
bone text `#cfc3a9` · steel `#96a0a8` · blood-lit `#c2584a` — the canonical
cloth (`midgard/design-system/tokens.css`, docs/design.md §4)

**Typography:** Cormorant (display/headings) · Newsreader (body) · IBM Plex Mono (data)

**Posture:** carved, not skinned — quiet stone, thin steel hairlines, faint
bronze washes, beveled panels, tinted buttons, no glass, no gradients-as-glow

**Rules:** a colour is never written at a call site (consume `--ymir-*` tokens);
selection amber `#57411a` on pale bone `#f0e6cd`; focus = chisel ring

**Export targets:** HTML, PDF, PPTX, MP4

## RUNTIME — the engine (installed 2026-09-24)

| piece | where |
|---|---|
| daemon | Docker `open-design` (ghcr.io/nexu-io/od:latest), loopback `:7456`, token-gated |
| MCP bridge | `open-design-mcp` (npm, global) — 10 `od_*` tools |
| pi register | `~/.pi/agent/mcp-adapter.json` → `hnoss-mcp-launch.sh` |
| launcher | `~/.local/bin/hnoss-mcp-launch.sh` — resolves `OD_API_TOKEN` + the model-rail key at launch |
| model rail | BYOK = llama-swap `127.0.0.1:8080/v1` (`qwen3.6-35b-a3b@iq3_s`) |

**Seating the Allfather in the web app:** the daemon is loopback-only and
single-tenant, so auth is **disabled** (`OPEN_DESIGN_DISABLE_API_AUTH=1` in
`~/opendesign/deploy/.env` — the engine's own blessed escape hatch for a
trusted loopback deployment). Open `http://127.0.0.1:7456` and the Studio is
there, no sign-in box. Do NOT re-enable the token gate for a browser login:
the Allfather asked to be carried through untouched, and loopback needs no
document. The `OD_API_TOKEN` still sits in the deploy `.env` (Secrets by
reference, never in a repo) and the MCP bridge still sends it as Bearer —
with auth off the daemon simply does not enforce it.

If a later seat wants the door gated again (public/LAN exposure), flip
`OPEN_DESIGN_DISABLE_API_AUTH=` to empty and the native sign-in returns:
username `open-design`, password `OD_API_TOKEN`.

**Status:** Installed and breathing — daemon `healthy` (no auth on loopback),
10 tools verified on stdio.

## RUNTIME ADDENDUM — 2026-09-24 · the Allfather seated, no login (the two doors)

The web app has TWO gates. Disabling the daemon's Basic token
(`OPEN_DESIGN_DISABLE_API_AUTH=1`) only kills the first. The second is the
frontend's **model-provider chooser** ("Sign in / Sign up · Free Credits · Or
use your own AI · Local AI · API Key"). To seat the Allfather past BOTH with
HIS providers and models:

1. **Mount his agents into the daemon** — the chooser's "Local AI" reads the
   daemon's runtime registry (`/api/agents`); if no CLI is inside the
   container, every agent reports `available:false` and the gate holds. The
   recipe lives in `~/opendesign/deploy/docker-compose.allfather.yml` +
   `Dockerfile.local` (image `od:local` = base + `libc6-compat`):
   - the **opencode** binary mounted as `$HOME_SEAT/.opencode/bin/opencode-cli`
     (the daemon scans for bin `opencode-cli`) with his `~/.config/opencode`
     and `~/.local/share/opencode`, so HIS providers/models ride in
   - **pi**'s node bin + `~/.pi` mounted read-only (his 54-model registry)
   - container PATH must keep its OWN `node` first — mounting the host's
     glibc `node` on PATH crashes the daemon with `libatomic.so.1` /
     `fcntl64: symbol not found`; do NOT mount `/lib/x86_64-linux-gnu` or
     `/lib64` (they break Alpine's musl loader). Stop with
     `docker compose -f docker-compose.yml -f docker-compose.allfather.yml up -d`
2. **Seed the daemon** so the chooser never opens — `PUT /api/app-config`:
   `{"onboardingCompleted":true,"agentId":"opencode","agentModels":{"opencode":{"model":"anthropic/claude-sonnet-4-5"}},"designSystemId":"default","skillId":"design"}`.
   The daemon persists it to `/app/.od/app-config.json`.
3. **Verify live** (not curl — the Next.js app is heavy; read the DOM after
   ~16 s via CDP): the Home paints "Let's create · Prototype", the composer
   shows model `anthropic/claude-sonnet-4-5` in Local mode, and the only
   remaining "Sign in" is the optional Cloud pill — never a door.

The MCP bridge (`hnoss-mcp-launch.sh`) resolves OD/rail keys from the pi
registry at launch; the web app needs none (auth disabled on loopback).

**Status:** Installed and breathing — daemon healthy, 10 MCP tools live, web
Studio in Local mode with opencode, no login.

### The model truth — "why is it claude? where are my models?"

OpenDesign's Settings model gallery (%the daemon's `/api/agents` `models` array)
is a **curated fallback list** (claude/gpt/gemini catalogs). It is NOT the
Allfather's registry. Two traps + the truth:

- **Trap 1 (mine):** seeding `agentModels: {agent: {model: "anthropic/claude-sonnet-4-5"}}`
  made the composer show claude. That was wrong — never seed a cloud model.
- **Trap 2 (OpenDesign):** a local CLI agent's *fallback* model list is its
  built-in catalog, so the gallery shows cloud names even when the CLI would
  use local ones.
- **The truth:** the daemon's agents include **`pi`** (`/api/agents`, id `pi`,
  bin `pi`) — and pi reads `~/.pi/agent/settings.json` + `models.json` at run.
  Its model `default` = *"Default (CLI config)"* = the Allfather's
  `defaultProvider: llama-swap` + `defaultModel: qwen3.6-35b-a3b@q4_k_xl-mtp`.
  pi's registry (54 models) is mounted into the container read-only, so a real
  generation runs on HIS rail at `127.0.0.1:8080/v1` — never claude.

**Seating fix (done 2026-09-24):** `PUT /api/app-config` →
`{"onboardingCompleted":true,"agentId":"pi","agentModels":{"pi":{}},
"designSystemId":"default","skillId":"design"}` — agent pi, model empty
(best value for `default`), so pi's own config decides. `opencode` is also
available (mounted as `opencode-cli`) if a different CLI is wanted; never
seed a named cloud model into `agentModels`.

## THE MODEL DOOR — 2026-11-10 (the addendum that makes generation work)

The Studio and the MCP bridge reach a model by two different roads, and conflating them is
what hid the fault for months.

**The Studio's own composer** spawns an agent CLI inside the container; `agentId: pi`
means pi's registry decides, and that was already right (see *the model truth* above).

**The MCP path** (`od_generate_design`) never touches an agent. It composes the design
system prompt locally and POSTs it to the daemon's `/api/proxy/<provider>/stream`, which
forwards it to `BYOK_BASE_URL` with `BYOK_API_KEY`. So every model call from an MCP client
is decided by the launcher's `BYOK_*`, and nothing else.

```
byok_road[4]{step,where,what}:
  "1","open-design-mcp","compose the design prompt, POST /api/proxy/openai/stream {baseUrl, apiKey, model, systemPrompt, maxTokens, messages}"
  "2","od daemon","thin pass-through: forwards to baseUrl with the bearer key, transcodes the SSE back"
  "3","the door","bin/pi/hnoss-mcp-launch.sh chose it: a models.json rail, or Bifrost for a pi built-in provider"
  "4","the provider","opencode-go / deepseek-v4.1-flash — and the log says so on every request"
```

**Three faults, all measured on this seat 2026-11-10:**

1. **A provider built INTO pi has no `models.json` entry.** `opencode-go` is one. The old
   launcher missed the lookup, fell back to `http://127.0.0.1:8080/v1` (the rail) and
   paired it with `deepseek-v4.1-flash`. The door now asks Bifrost for such a provider.
2. **The gateway wants `x-opencode-session`.** Both endpoints answer
   `400 MissingSessionID` without it, and `open-design-mcp` cannot send a custom header.
   Bifrost already does — which is why the bridge, not the URL, is the answer.
3. **The image's Node heap is 192 MB.** A real page (a ~40 kB system prompt plus a
   streamed document) died with `FATAL ERROR: Ineffective mark-compacts near heap limit`;
   the client saw only `OD daemon unreachable`. Worse, `bin/pi/open-design.sh` ran Compose
   from whatever directory it was called in, and Compose v2 reads `.env` from the caller's
   directory — so `~/opendesign/deploy/.env` was ignored entirely. The door now passes
   `--env-file` and the deployment sets `NODE_OPTIONS=--max-old-space-size=1024`,
   `OPEN_DESIGN_MEM_LIMIT=1536m`.

**The door's own words** (ask it, never guess):

```
bin/pi/hnoss-ensure.sh status        # four rows: server · launcher · pi MCP entry · model door
bin/pi/hnoss-mcp-launch.sh --resolve # the door it WOULD take; no bridge raised, no network
bin/pi/hnoss-mcp-launch.sh --print   # raise the door, then print it
bin/bridge/bifrost-bridge.sh --status --port 4613   # the live provider, read from the process
```

Hnoss's bridge lives on **`:4613`** (`YMIR_HNOSS_BRIDGE_PORT`), deliberately beside the
shared `:4603` door: the provider is a per-caller fact, and the pid/log files are
port-scoped so two instances coexist without one `--stop` killing the other.

**Prove a generation is on the model you asked for** — the log names it:

```
grep 'model=' "$YMIR_HOME/state/model-bridge-4613.log"    # model=deepseek-v4.1-flash provider=opencode-go
docker logs open-design-open-design-1 | grep 'proxy:openai'  # [proxy:openai] POST 127.0.0.1 model=deepseek-v4.1-flash
```

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
