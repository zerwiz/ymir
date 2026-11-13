# Rule 07 — Configuration is never hardcoded

Every port, host, endpoint, path, credential, and tunable is **configuration**, not
a literal baked into shipped runtime. A hardcoded value is a bug that only appears
on someone else's machine — or someone else's server.

## The law

- **One default, one place.** A value has exactly one documented default, owned by
  the portability layer (`bin/fleet/ymir-platform.sh`) or a config file (e.g.
  `config/agents.yaml`). Everywhere else reads it; nothing else restates it.
- **Env first, then config, then the documented default.** Resolve as
  `${VAR:-default}` (or the app's equivalent) — never a bare literal.
- **No literal ports.** Ports come from env (`HLIDSKJALF_PORT`,
  `HLIDSKJALF_API_PORT`, `SMIDJA_VIZ_API_PORT`, `PORT`, …). A published port, a
  proxy target, and a health probe must all read the *same* source.
- **No literal hosts or URLs.** `127.0.0.1`, `localhost`, tunnel hostnames, registry
  and mesh endpoints resolve from env/config.
- **No literal paths to secrets.** Secrets are referenced by path (`YMIR_HOARD`,
  `.env.local`, `.env.realm`) and resolved at run time; never inlined.
- **No literal credentials. Ever.**
- **Bind and publish are separate and explicit.** An app binds a host
  (`HLIDSKJALF_HOST`); a deployment publishes a host-IP/port. Neither assumes the
  other's value.
- **A deployment overrides; it never patches the core.** Environments run from
  env/config (`deploy/env.example`, Quadlet/Compose env), so the same core runs
  anywhere — a laptop, a bare box, a container, or a shared server.

## Scope

Every shipped surface: `bin/`, `scripts/`, `apps/`, `.agents/skills/**` tools,
deploy manifests, and generated config.

## Enforcement

- Review, plus `bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh`.
- The portability layer is the **one** place that knows an environment difference
  (Rule 05). A hardcoded value is a Rule 05 violation as well as a Rule 07 one.

## Why

Hardcoding is how a substrate written on one machine breaks on another, or
collides with a neighbour's port on a shared server — the exact failure a
host-agnostic core exists to prevent. This rule is the companion of Rule 05: Rule
05 keeps *behaviour* portable; Rule 07 keeps *configuration* portable.

## Amendment — models, providers, and paths are the user's, in the hoard (2026-09-17)

Appended, not rewritten; the clauses above stand.

### A. Models and providers live in the hoard, per user, read from YAML

**Every user's models and providers differ.** One operator runs local llama.cpp
on a 16 GB card; another runs hosted models; a third runs both. There is therefore
**no such thing as a global model or provider** — a shipped default that names a
model is a claim about someone else's machine.

- **The one source.** A user's models and providers live in **`$YMIR_HOME/hodd/`**
  — the user's own workspace, their private hoard — and are read from a **YAML
  file there** (`hodd/config/agents.yaml`). Nothing else owns them.
- **No global.** A model id or provider name must not appear in shipped runtime
  code, in a tracked config, or in any repo file as a *value*. The repo ships a
  **template** (`config/agents.yaml.example`) with placeholders; the live file is
  the user's, and it is private (Rule 04).
- **Resolve, never restate.** Code reads a model or provider through the resolver
  (`bin/model/model-resolve.sh`, `bin/fleet/agents-config.sh`) or from env. It never embeds
  the id.
- **A comment may name an example; code may not.** A usage line in a header
  (`#   bin/pi/pi-seat.sh -m <model>`) is documentation. A literal assigned to a
  variable, written into a config, or passed as a default is a violation.

### B. No hardcoded absolute file paths

**A path that names a user, or a machine's layout, is not portable.**

- **User-agnostic.** No `/home/<user>/…`, no `/Users/<user>/…`, no `C:\Users\…`,
  no baked-in username anywhere in shipped code, config, or docs.
- **Relative or resolved.** A path is relative to a resolved root
  (`$YMIR_HOME`, `$YMIR_HOARD`, `$ROOT`, `$SCRIPT_DIR`), or comes from env/config
  with one documented default. Never a literal absolute path.
- **The home is resolved, not assumed.** `$YMIR_HOME` resolves through
  `bin/vault/hoard-lib.sh` (`hoard_root`) — never a hardcoded `~/Documents/Ymir`, never
  another user's home.
- **A test may use a temp dir; it may not use a real home.** `mktemp -d` and
  `$TMPDIR` are correct. A fixture that names a real user's home is a violation
  that will fail on every other machine.

### Enforcement

`compliance-check.sh` gains the **`config`** gate, which fails on:

```
config_gate[3]{class,what_it_catches}:
  "model","a model id or provider name used as a VALUE in shipped code or a tracked config"
  "path","an absolute path naming a user (/home/<user>, /Users/<user>, C:\\Users\\<user>)"
  "hoard","a model/provider config outside $YMIR_HOME/hodd/"
```

Comments, templates (`*.example`), `CHANGELOG*`, and `assets/reference/`
(provenance) are exempt by intent — they document, they do not configure.


## Amendment — a new port is a random five-digit number (2026-11-12)

Appended, not rewritten; the clauses above stand. **By the Allfather's word:** *"Use a random
5 digit ports to avoid conflicts — this should already be a global rule for all agents and LLMs."*

### C. Choosing a port

- **Never a well-known or four-digit default.** No `4000`, `5432`, `8080`, `3000`, `5173`… for
  anything new. Those collide with every other dev server, database and tool on the host.
- **Pick a random five-digit port in `10000–32767`.** That range sits below the kernel's
  ephemeral range (`net.ipv4.ip_local_port_range` = `32768–60999` on this host), so an outgoing
  connection can never be handed the same number. One way to pick it:
  `shuf -i 10000-32767 -n 1`, then confirm it is free with `ss -ltnH | grep -w ":<port>"`.
- **One port per surface, recorded once.** The chosen number becomes the one documented
  default (env var with that default, per clause *No literal ports*), and the app, the
  published port, the proxy target and the health probe all read it.
- **A service's ports are a block.** When a project needs several (app, db, metrics), pick a
  random base and use consecutive numbers (`base`, `base+1`, …), each checked free.
- **Existing ports stay.** Ports already in service are not migrated for this rule alone; they
  move when their service is next reworked.

Applies to every agent and every LLM tool on every machine: Claude Code, pi, opencode, Codex,
Gemini, and Eindri workers alike.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
- **2026-11-12** — amendment C appended: a new port is a random five-digit number in 10000–32767 (fix note `docs/fixes/rules/2026-11-12-rule-07-random-five-digit-ports.md`).
