## install · unversioned · 2026-11-10 — the design door is seated by install and mended by every update

### Why

- The Hnoss (OpenDesign) MCP launcher was a hand-file placed outside the tree. Install never
  seated it, Gróa never mended it, and Eir never looked at it — so the one script that
  decides which model the design craft reaches was outside every door the house keeps.
  It was also wrong (see `docs/fixes/skills/2026-11-10-hnoss-reaches-the-provider-pi-uses.md`):
  it paired the local rail with an online model, and every design generation died
  silently.
- A door that is only a hand-copy cannot be agnostic either: nothing on a second machine
  would ever have made it.

### Fix

- **`step_hnoss` in `bin/engine/ymir-install.sh`** (after `models`, because the door needs
  pi's provider): it calls `bin/pi/hnoss-ensure.sh ensure --install`, which seats the
  shipped launcher, the pi MCP entry and the compatibility shim, and installs
  `open-design-mcp` when the machine has a studio. A machine with no design engine
  reports a clean skip — the engine is adopted, never forced.
- **`bin/agents/groa-update.sh` mends it forward**, beside the Electron mend: every
  update re-seats the door and prints the line it resolved, so an update can never leave
  a design generation on a stale hand-copy. Never fatal.
- **`bin/agents/eir-doctor.sh` checks it**: a new `hnoss` surface asks
  `hnoss-ensure.sh status`, which reports the MCP server, the launcher, the pi MCP
  entry, the compatibility shim and the resolved model door — and skips cleanly on a
  machine with no design studio.

### Verified

- `bin/pi/hnoss-ensure.sh status` → every row seated, `"model door","resolves","opencode-go
  · deepseek-v4.1-flash · http://127.0.0.1:4613/v1"`.
- `bin/agents/eir-doctor.sh check` → `"hnoss","ok",""`.
- `bin/engine/ymir-install.sh` and `bin/agents/groa-update.sh` pass `bash -n`.
- A real design generation through the MCP returned content with the model named in
  `state/model-bridge-4613.log` (full evidence in the skills fix note).

### Files

- `bin/engine/ymir-install.sh` — `step_hnoss` + its `run_step`
- `bin/agents/groa-update.sh` — the mends-forward block
- `bin/agents/eir-doctor.sh` — the `hnoss` surface

## CHANGE LOG

- **2026-11-10** — written with the fix it records: install seats the design door and every
  update mends it.
