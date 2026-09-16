# Rule 07 — Configuration is never hardcoded

Every port, host, endpoint, path, credential, and tunable is **configuration**, not
a literal baked into shipped runtime. A hardcoded value is a bug that only appears
on someone else's machine — or someone else's server.

## The law

- **One default, one place.** A value has exactly one documented default, owned by
  the portability layer (`bin/ymir-platform.sh`) or a config file (e.g.
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
