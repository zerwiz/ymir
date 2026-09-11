# Installation & First Setup — stand the whole system up

> **Purpose:** Everything Galdr must know to install, provision, and repair
> Ymir for an operator who does not have it. The code is authoritative; this
> page is the map.

One command sets up the whole system for the user; it self-heals what it can and
reports what it cannot.

```
bin/ymir-install.sh          # the first setup (idempotent)
bin/ymir-install.sh --check  # report only, no writes
bin/ymir-install.sh --skip-engines --skip-services
bin/ymir-install.sh --status # alias of --check
```

## The steps

```
install[9]{step,what,self-heals}:
  "prereqs","git python3 bun docker gh engram mcp<2","pip-installs engram + 'mcp<2'; the rest is reported"
  "tree","workspace/{work,personal}/<domains>, companies/, workspaces.yaml, projects.yaml","creates if missing"
  "engines","treehouse · sandcastle · no-mistakes","installs treehouse + no-mistakes from their installers"
  "hermes","the Nous Research agent runtime","installs via bin/hermes-ensure.sh when absent"
  "sandbox","utgard-runner:latest image","builds via bin/utgard.sh build when absent"
  "memory","engram store + harness MCP registrations","raises the bridge; reports MCP coverage"
  "loaders","agents/skills into the harnesses","runs bin/valknut-load.sh"
  "register","workspace/INSTALL.md","writes the record"
  "services","gate API, SPA, Nornir, bridges, visualizer","raises via scripts/start.sh"
```

## What the system adopts (engines)

| Engine | Norse shell | Role |
|---|---|---|
| **treehouse** (`kunchenguid/treehouse`) | Yggdrasil | reusable worktree pool |
| **sandcastle** (`mattpocock/sandcastle`) | Utgard | Docker/Podman/Vercel sandboxes |
| **no-mistakes** (`kunchenguid/no-mistakes`) | Mjollnir · Glitnir | clean-PR validation gate |
| **Hermes** (`NousResearch/hermes-agent`, MIT) | — (product name) | worker agent runtime: own brain, memory, skills, subagents, sandbox backends |

## Missing dependencies

- **Fixable in place:** `engram`, `mcp<2` (pip), `treehouse`, `no-mistakes`,
  **Hermes** — the installer runs their official installers when absent.
- **System-level** (reported, not auto-installed): `git`, `python3`, `bun`,
  `docker`, `gh`. Install them with the platform package manager, then re-run.
- **Offline:** engine/Hermes installers fail gracefully and are reported; re-run
  when the network returns.

## Hermes specifically (`bin/hermes-ensure.sh`)

```
hermes-ensure.sh status           # hermes[1]{installed,version,path,method}
hermes-ensure.sh ensure --install # install if absent, then report
hermes-ensure.sh install          # curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

A user who lacks Hermes gets it at setup (`hermes` step). Config/identity
(`hermes setup`, auth) stays the user's own; Ymir guarantees only the runtime.

## Per-workspace provisioning

```
bin/workspace-provision.sh <name> --kind work|personal [--domains a,b,c] [--company wayof]
```

Creates `workspace/<name>/<domains>/`, registers it in `workspaces.yaml`, and
for a **work** workspace attaches it to the company container
`svartalfaheim/<company>/`.

## Verify

```
bin/ymir-install.sh --check          # all steps OK/WARN
bin/saga-session-start.sh            # the session digest
bash .agents/skills/galdr/scripts/compliance-check.sh
```

Rule: the installer is **idempotent** — running it again changes nothing but
fills gaps. It never overwrites real user data.
