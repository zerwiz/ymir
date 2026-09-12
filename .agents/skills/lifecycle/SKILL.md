---
name: lifecycle
description: "How this project is started, stopped, inspected and smoke-tested — the NSR compliance harness's wiring contract. `.compliance/gates/check_wiring.sh` requires .agents/skills/lifecycle/{start,stop,status,smoke_test}.sh for a project to count as operable. Use when raising or lowering the stack, checking what is up, or proving the runtime works."
allowed-tools: read, write, edit, bash
---

# lifecycle — start, stop, status, smoke_test

The operability contract of this repository. The NorthStar compliance harness
(`.compliance/`) looks for exactly these four scripts at exactly this path; a
project without them is not considered wired.

> **Why the name is not Norse.** Every subsystem in Ymir is named for the figure
> whose role matches its work (see `RULES/` and
> `galdr/assets/norse-naming.md`). This one is an **interface name**: the harness
> is an external contract that addresses these paths by name, like
> `.compliance/` itself. The scripts are wrappers; the procedures they call carry
> the house names.

## The four scripts

```
lifecycle[4]{script,action,delegates_to}:
  "start.sh","raise the stack","scripts/start.sh (the real boot command)"
  "stop.sh","lower the stack","scripts/stop.sh"
  "status.sh","what is up, by surface","the five ports + the two desktop views"
  "smoke_test.sh","does it actually work","HTTP, the well, the Smiðja schema, the harness bindings"
```

```bash
.agents/skills/lifecycle/start.sh          # SPA :3888, gate :3889, Bifrost :4603, Mimir :4602, visualizer :8437
.agents/skills/lifecycle/status.sh         # TOON: each surface up or down
.agents/skills/lifecycle/smoke_test.sh     # exit 0 when every check passes
.agents/skills/lifecycle/stop.sh
```

## The rule: a wrapper never rewrites what it wraps

Each script **delegates**. There is one boot command (`scripts/start.sh`) and one
stop command (`scripts/stop.sh`); these exist so a compliance gate, a CI job or a
new operator has a single predictable address, not so the procedure can live in
two places. If the stack changes how it boots, change `scripts/start.sh` — never
these.

`smoke_test.sh` is the one that adds something: it answers *"is it working"*
rather than *"is a socket open"* — it fetches the SPA over HTTP, asks the well
bridge, checks the Smiðja schema has tables, and proves the agents are bound. It
exits non-zero on failure so a gate can rely on it.

## Verify

```bash
.agents/skills/lifecycle/status.sh      # expect the surfaces that are up
.agents/skills/lifecycle/smoke_test.sh; echo "exit=$?"
bash .compliance/gates/check_wiring.sh --strict   # the harness's own verdict
```
