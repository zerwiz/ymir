## runtime · unversioned · 2026-09-23 — the README and npm manifest describe the fleet

### Why
- **Problem:** the README (used by BOTH GitHub and npm) and the npm `description`
  said nothing about the layer built today — the fleet, roles, offline-first
  sync-up, the MCP servers, role-gated crons, the forge rail, or the operations
  scripts. A reader could not discover that Ymir runs many machines over one
  record, or what to type to see it.
- **Fix (appended, nothing rewritten):**
  - **README** gains *"The Fleet — many machines, one record"*: the four roles
    (`heart · forge · dev · hand`) with what each owns/runs/does not; the registry
    and `bin/topology.sh`; **offline-first** (cache + journal + reconciler, the
    heart folds, the chain cannot fork); **MCP by role** (well/skuld/bolthorn on
    the heart, addressed by name — Rule 10 linked); **crons by role**; **models**
    (the forge owns the rail); **Eindri routing**; **one version across the
    fleet**; a nine-command **operations index**; and the **health** story
    (35-check smoke test, `bin/eir-doctor.sh`).
  - **`package.json`** — the `description` now names the fleet, offline-first,
    the MCP servers, and role-gated crons; `keywords` gain `agent-os`, `eindri`,
    `fleet`, `multi-machine`, `offline-first`, `self-hosted`, `local-models`,
    `llama.cpp`, `tailscale` (npm discovery).

### Verified
- `package.json` parses (`node -e`); description and keywords render as intended.
- The README section is present and its commands match the shipped scripts.

### Files
- `README.md`
- `package.json`
