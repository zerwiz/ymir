## skills · unversioned · 2026-09-28 — OpenDesign dies on one unreadable token

### Why
- **The Studio at `http://127.0.0.1:7456` generated nothing.** The daemon was
  healthy (`/api/health` 200, container `open-design` up 38h, host networking so
  `:8080` reaches the llama-swap rail), yet every run died the same way. The
  daemon's own log carried the verdict:

  ```
  [test:agent] OpenCode → no_text (exit 1 · stderr:
    Error: Configuration is invalid at /home/open-design/.config/opencode/opencode.json:
    bad file reference: "{file:~/.config/opencode/.wayofteams-mcp-token}")
  [od-next-task] blocked … reasonCodes: [ 'od_next_physical_run_interrupted' ]
  ```

- **The cause was a permission, not a design fault.** The container mounts the
  host's `~/.config/opencode` read-only and runs the bundled opencode CLI against
  it, so the CLI reads the Allfather's live config — including 12
  `wayofteams-*` MCP blocks whose `Authorization` header is
  `Bearer {file:~/.config/opencode/.wayofteams-mcp-token}`. That token is `0600`
  owned by uid 1000 (`heimdall`); the container runs as uid 1001
  (`open-design`). The reference could not be resolved, and the opencode CLI
  rejects **the whole config** over one unresolvable file reference — so every
  design run exited 1 with `no_text`. The token became unreadable when the
  Way of Teams MCP was added to the host config on 2026-09-26; the design daemon
  had been quietly deaf ever since.

- **A second, independent gap:** the OpenCode harness had no `hnoss` MCP entry
  at all (`~/.config/opencode/opencode.json` carried 14 servers — well,
  a2abridge, engram, 10× wayofteams — and no design bridge), so the design craft
  was reachable from Pi (`~/.pi/agent/mcp-adapter.json` → `hnoss-mcp-launch.sh`,
  10 tools) but not from OpenCode.

- **And a third:** `od` on this seat resolves to `/usr/bin/od`, GNU coreutils'
  octal dump. The OpenDesign CLI is not on the host PATH, so the documented
  `od mcp install <agent>` step was never runnable here; the engine exists only
  as the container plus the `open-design-mcp` stdio bridge.

### Fix
- **The ward, not the door.** `setfacl -m u:1001:r
  ~/.config/opencode/.wayofteams-mcp-token` — uid 1001 gains read on that one
  file and nothing else widens. The host file stays `0600 heimdall:heimdall`, the
  host config keeps all 12 Way of Teams blocks, and the ACL follows token
  rotation with no copy to re-stamp. (The rejected alternative: `chmod 644`,
  which would hand a sold-control-plane bearer to every local uid; and the
  sanitized-copy alternative, which would have cost the container its Way of
  Teams tools.)
- **OpenCode is now bridged.** An `hnoss` local MCP block pointing at
  `~/.local/bin/hnoss-mcp-launch.sh` — the same launcher Pi uses, so both
  harnesses drink the same rail, model and daemon. Backup of the prior config:
  `~/.config/opencode/opencode.json.bak-hnoss-20260929T002749Z`.

### Verified
- `docker exec open-design … opencode-cli models` — clean, `ymir-local/*` listed;
  the "Configuration is invalid" error is gone.
- `opencode-cli run -m ymir-local/qwen3.6-35b-a3b@iq3_s "Reply with exactly:
  HNOR RUNE OK"` → `HNOR RUNE OK`, from inside the container.
- `hnoss-mcp-launch.sh` cold-started over stdio: `initialize` →
  `open-design-mcp 0.16.1`, `tools/list` → 10 tools.
- Full design loop through the pi bridge: `od_create_project` → `od_generate_design`
  Turn 1 brief form → Turn 2 artifact (a complete self-contained dark landing
  hero, 1642 chars, inline CSS, no external requests) → `od_delete_project`.
  Scratch project removed; the Studio is clean.

### Still standing
- `od` is still coreutils on this seat. If the Allfather wants the host CLI, it
  needs its own install (the image's `/home/open-design/.opencode/bin/opencode-cli`
  is the opencode CLI, not the OpenDesign one) — not mended here.

### Files
No file in this repository changed for this fix; it is a seat-level mend, recorded
here because the record is where a fault like this is looked up.

- `~/.local/bin/hnoss-mcp-launch.sh` — read, unchanged (it was already correct)
- `~/.config/opencode/opencode.json` — the `hnoss` MCP block added
  (backup `opencode.json.bak-hnoss-20260929T002749Z`)
- `~/.config/opencode/.wayofteams-mcp-token` — ACL `setfacl -m u:1001:r`; the file stays
  `0600 heimdall:heimdall`
