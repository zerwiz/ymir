# Rule 10 — Every server runs from a file the repo owns

Every server, service, worker, and MCP the runtime runs has exactly **one**
source: **this repo**. A running process whose code exists only on a machine is a
bug — it cannot be reviewed, versioned, updated, rolled back, or reproduced.

## The law

- **The repo is the source of truth.** Every long-running surface — the MCP
  servers (`tools/*-mcp/`), the fleet services (`tools/`, `apps/`), workers
  (`tools/mill/worker.sh`), and the desktop surfaces (`apps/`) — lives under a
  repo path and is tracked in git.
- **Deployment copies from the repo; it never hand-places.** A machine's runtime
  copy (`~/.fleet/<name>` or the service's working directory) is produced by a
  repo script (`bin/fleet-ensure.sh`), idempotently. Editing the deployed file by
  hand is drift, not a fix.
- **The launch manifest lives in the repo too.** The systemd unit (or
  Quadlet/Compose file) ships in `tools/mill/systemd/` and is installed from
  there. A host-specific PATH or interpreter may differ (Rule 05); the
  `ExecStart` target must be the **repo-deployed path** — never a directory
  someone invented on the machine (e.g. `tickets-mcp-v2`).
- **A running service is traceable to a revision.** The deployed copy carries the
  version or revision it was installed from, so "what is running?" has an answer.
- **Drift is a finding, not a mystery.** Eir's `fleet`/`mcp` surfaces and the
  lifecycle smoke test prove the running server; a deployed file that does not
  match the repo is reported.

## Scope

`tools/**`, `apps/**`, `bin/**` services, `tools/mill/systemd/*`, and every MCP
or worker a harness launches.

## Enforcement

- `bin/fleet-ensure.sh` is the one deployer: it copies from `$ROOT/tools/` and
  installs units from `$ROOT/tools/mill/systemd/`. Run it; never hand-place.
- `bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh` plus the
  lifecycle smoke test prove the running surface (the smoke test does a real MCP
  `initialize` → `tools/list`).
- A Rule 10 violation looks like: a service `ExecStart` pointing outside the repo
  deploy path; a server file on a machine with no repo twin; a hand-edited unit.

## Why

On 2026-09-23 the ticket MCP (`skuld`) ran a **hand-placed**
`~/.fleet/tickets-mcp-v2/server.mjs`, while the repo's own
`tools/tickets-mcp/server.mjs` (the source) was itself broken
(`ReferenceError: server is not defined` — a merge had left one tool registration
outside `makeMcp()`). The service failed with *"Already connected to a
transport"*, nobody could say which file was running, and the fix could not be
deployed because the source was not the source. **One repo, one deploy, one
answer.**

## Append-only

This rule is appended to, never rewritten (Rule 06). A correction is a new dated
entry citing the old.
