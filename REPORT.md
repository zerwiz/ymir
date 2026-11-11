# REPORT — hnoss-deepseek-road

**Errand:** make Hnoss (the OpenDesign design smithy) reach
`opencode-go/deepseek-v4.1-flash`, and deliver it through the shipped doors.
**Mode:** direct-PR was the contract; **the arm holder stopped the errand at
2026-11-11 ~00:20Z** with "do not push and do not open a PR" — he merges this branch
locally with the others into one PR. **No PR was opened.**

## Delivery

- Branch: `eindri/hnoss-deepseek-road`
- Tip at the stop: `be50e764` (rebased onto `origin/main` `5ac55dd1`)
- **The branch was already pushed** (one `git push -u origin`) seconds before the stop
  arrived; the push is namespaced to the `eindri/` branch, and it was the push the
  delivery contract asked for. Nothing was merged, `main` was never touched, and no PR
  exists. The arm holder can merge the branch as-is or delete the remote ref.
- Worktree: `/home/heimdall/ymir/.yggdrasil/hnoss-deepseek-road` — clean.

## What changed (19 files, +1061/−34 at first commit)

**The road.** `open-design-mcp` reaches a model through BYOK only: it composes the design
prompt and POSTs it to the daemon's `/api/proxy/openai/stream`, which forwards to
`BYOK_BASE_URL`. pi was never in that path — the Studio's composer is a different road
(`agentId: pi`), already through pi. So the door had to be fixed, not the daemon.

- `bin/pi/hnoss-mcp-launch.sh` (new, shipped) — resolves provider, model and credential
  from pi, then picks the door: a `models.json` rail directly; a provider built **into**
  pi (`opencode-go`) through the **Bifrost bridge**, which adds the `x-opencode-session`
  header the gateway demands; anything else is a **refusal naming the provider**, never a
  silent fallback to the rail. `--resolve` is hermetic (no bridge raised, no network).
- `bin/pi/hnoss-ensure.sh` (new) — seats the launcher, merges the `hnoss` pi MCP entry
  into `~/.pi/agent/mcp.json` + `mcp-adapter.json` (every other server kept), writes a
  compatibility shim at any old path a config still names, resolves the door. Clean skip
  on a machine with no studio.
- `bin/bridge/bifrost-bridge.sh` — `--ensure --provider N` (raise on a named provider,
  restart a wrongly-providen one, never call it green), `--status` reads the provider from
  the LIVE process instead of the flag, pid/log scoped per port so Hnoss's `:4613`
  coexists with the shared `:4603`, `--providers` lists what it can carry.
- `.agents/backend/model-bridge.py` — `--bind`, `--providers`, and the model printed on
  every request (`model=<id> provider=<provider>`).
- `bin/pi/open-design.sh` — passes the deployment's `.env` to Compose (Compose v2 read the
  caller's directory, so `~/opendesign/deploy/.env` was ignored and the image's 192 MB
  Node heap killed real pages: "OD daemon unreachable").
- Wired: `step_hnoss` in `bin/engine/ymir-install.sh`, a mends-forward block in
  `bin/agents/groa-update.sh`, a `hnoss` surface in `bin/agents/eir-doctor.sh`.
- Docs: `docs/fixes/skills/2026-11-10-hnoss-reaches-the-provider-pi-uses.md`,
  `docs/fixes/install/2026-11-10-…`, dated appends to
  `.agents/skills/hnoss-design/{SKILL,DESIGN}.md`, a new
  `docs/features/design-with-hnoss.md` + its woven catalogue row.

## Verification

- **One real generation THROUGH the MCP**: stdio `initialize` → `open-design-mcp 0.16.1`,
  `tools/call od_generate_design` → content returned (1178 chars on the first proven run,
  631 on the second: "Blackwater Forge — Hero", real HTML/CSS).
- **The model named in the logs**, same requests:
  - `state/model-bridge-4613.log` → `[bridge] model=deepseek-v4.1-flash
    provider=opencode-go stream=True` with `"POST /v1/chat/completions HTTP/1.1" 200`;
  - the daemon → `[proxy:openai] POST 127.0.0.1 model=deepseek-v4.1-flash`.
- `.agents/tests/hnoss-model-door.test.sh` → **PASS** (16 checks, offline, no service
  raised): the built-in provider resolves to the bridge and NOT to `:8080`; a registry rail
  resolves directly; a provider with no door is refused and named; `--status` reads the
  process not the flag; `--ensure` refuses to call a wrongly-providen bridge green;
  `--stop` closes only its own port.
- `bin/pi/hnoss-ensure.sh status` → `"model door","resolves","opencode-go ·
  deepseek-v4.1-flash · http://127.0.0.1:4613/v1"`.
- `bin/agents/eir-doctor.sh check` → `"hnoss","ok",""`.
- `bin/gates/guards.sh` → **CLEARED** (7 wards red, all red on `origin/main` too).
  `secret-guard` and `public-guard` exit 0; `fixes-guard` accepts both notes.

## Changed outside the repo (the operator's machine property — said plainly, not hidden)

- `~/opendesign/deploy/.env` (backup kept): `NODE_OPTIONS=--max-old-space-size=1024`,
  `OPEN_DESIGN_MEM_LIMIT=1536m`.
- `~/opendesign/deploy/docker-compose.allfather.yml` (backup kept): the same
  `NODE_OPTIONS` wired from `.env`, because the image bakes 192 MB and a real page dies of
  heap exhaustion under it.
- Seated on this seat: the `hnoss` MCP entry in `~/.pi/agent/mcp.json` and
  `mcp-adapter.json`; the Studio container now carries the larger heap.

## Open questions / still standing

1. **`openrouter`** (and any future pi built-in) has no door here; the launcher refuses it
   by name. Adding one means teaching `model-bridge.py` that provider, not guessing a URL.
2. The daemon's heap is a deployment fact, not a repo fact: the compose files live in the
   operator's home, so a second machine needs the same two values.
3. `~/.local/bin/hnoss-mcp-launch.sh` still exists on this seat as an inert leftover shim;
   no config names it any more. Never deleted, per the append-only habit.
4. The worktree earlier carried 45 unstaged `.pi/extensions` deletions that were not mine;
   they were restored to match the commit rather than staged. Worth someone knowing they
   appeared.
