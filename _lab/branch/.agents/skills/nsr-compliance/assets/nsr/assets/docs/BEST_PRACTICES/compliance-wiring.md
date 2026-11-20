# Wiring the Compliance to Your Project

> The compliance is a project-agnostic engine. Wiring is how it *benefits your specific stack*.
> This guide is for humans **and** agents: it explains how to add things, wire existing
> procedures, and operate the compliance safely. Read it before dispatching agents against a
> wired repo.

## 1. The Mental Model

- **Engine** — the compliance: `runner.py`, gates, telemetry, envelopes. Generic, portable, stack-neutral. It does not know or care what stack you run.
- **Gearbox** — the scripts under `.agents/skills/lifecycle/` and `.agents/skills/features/<name>/`. **You wire these to your app.** This is where your project's reality lives.
- **Fuel** — your existing procedures: how you start, stop, health-check, test, seed, and deploy today. The compliance never replaces them — it *wraps* them in env checks, exit-code gates, and telemetry.

Rule: **the compliance adds value only where the gearbox is wired.** A freshly stamped repo is 100% stubs — that is scaffolding, not operation.

## 2. The Fixed Script Contract

Every script must be:
- POSIX bash, relative paths only, no absolute paths
- `set -e`; `exit 0` on success, non-zero on failure
- Env-driven (read `APP_ENV`, `DATABASE_URL`, etc.; never hardcode)
- No raw `kill -9` / `pkill` — use wired lifecycle scripts
- If it touches anything destructive → annotate `# gate:` (see §5)

| Domain | Script | What it binds to |
|--------|--------|------------------|
| lifecycle | `start.sh` | boot the app for `APP_ENV` |
| lifecycle | `stop.sh` | graceful shutdown (no kill -9) |
| lifecycle | `status.sh` | health endpoint / process check |
| lifecycle | `smoke_test.sh` | post-boot verification against the real app |
| features/`<name>` | `setup.sh` | env/data bootstrap, seeds, migrations |
| features/`<name>` | `test.sh` | the feature's real test suite |
| features/`<name>` | `smoke_test.sh` | feature health after a change |
| features/`<name>` | `rollback.sh` | teardown / emergency rollback |

## 3. Step 1 — Inventory Existing Procedures

Write down the exact commands your project already uses:

- How do you boot it today? (`mix phx.server`, `npm run dev`, `manage.py runserver`, `docker compose up`...)
- How do you stop it? (Ctrl-C, `mix phx.server --no-compile` teardown, `docker compose down`, systemd stop)
- What is the health signal? (HTTP endpoint, DB ping, `mix phx.status`, `pg_isready`)
- What is the real test command? (`mix test`, `npm test`, `pytest`, `go test`)
- What needs permission before running? (migrations, seed/production data, `DROP`, force push, deploy)

## 4. Step 2 — Wire the Lifecycle Scripts (examples)

**Elixir / Phoenix**

```bash
# .agents/skills/lifecycle/start.sh
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../../.."
[ -f .env ] && set -a && . ./.env && set +a
case "${APP_ENV:-development}" in
  dev|development) exec mix phx.server ;;
  prod)            exec mix phx.server --no-compile ;;
  *) echo "unknown APP_ENV=$APP_ENV"; exit 1 ;;
esac
```

```bash
# .agents/skills/lifecycle/status.sh
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../../.."
curl -fsS "http://${PHX_HOST:-localhost}:${PORT:-4000}/health" >/dev/null
```

**Node.js**

```bash
# .agents/skills/lifecycle/start.sh
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../../.."
case "${APP_ENV:-development}" in
  prod) exec npm run start ;;
  *)    exec npm run dev ;;
esac
```

**Python / Django**

```bash
# .agents/skills/lifecycle/start.sh
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../../.."
exec python manage.py runserver 0.0.0.0:"${PORT:-8000}"
```

Wrap, never replace: if `scripts/cloudflare/startprod.sh` already does the right thing, your `start.sh` can simply delegate to it plus an env check:

```bash
# .agents/skills/lifecycle/start.sh
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../../.."
[ "${APP_ENV:-development}" != "prod" ] || { scripts/cloudflare/startprod.sh; exit $?; }
scripts/cloudflare/startdev.sh
```

## 5. Step 3 — Danger Annotations

Any script containing a destructive/force primitive **must** declare it:

```bash
# gate: dev    – safe for agents/automation in dev; human confirm in prod
# gate: guard  – must not run until a required guard script passes
# gate: human  – irreversible; agents must never run this alone
```

`check_danger.sh` fails on dangerous scripts without an annotation. The runner *refuses* to auto-run `guard`/`human` scripts during `--plan` unless a human passes `--confirm-gate`.

## 6. Step 4 — Prove the Wiring

```bash
# 1. Nothing left stubbed
.compliance/gates/check_wiring.sh --strict

# 2. No undeclared danger
.compliance/gates/check_danger.sh

# 3. Script registry (see what the compliance can do)
.compliance/harness/runner.py --list

# 4. Run for real — envelope -> gates -> your test suite
.compliance/harness/runner.py --plan <task-envelope.json> --action test
```

Run each lifecycle script once manually. If any exits non-zero, it is not wired and must be fixed before agents are trusted.

## 7. How Agents Operate the Compliance

- Agents never invent commands: they call wired scripts through `runner.py`.
- Agents read `--list` to see what exists, then open the matching feature script.
- The compliance verifies success by `$?`, never by the agent's word.
- Human-gated scripts (`# gate: human/guard`) are off-limits to agents; a human runs them after review.

## 8. The Compliance Grows with the Project

Adding a capability is mechanical:

1. Register the feature in `FEATURES.md`.
2. Create `.agents/skills/features/<name>/` with the five wired scripts (`setup test smoke_test rollback` + `SKILL.md`).
3. `check_wiring.sh --strict` and `check_danger.sh` automatically include it.
4. `runner.py --list` and `--plan --feature <name>` pick it up with zero compliance changes.

A new gate dropped in `.compliance/gates/` is auto-run by every `--gates`/`--plan`.

## 9. When It Is NOT Worth It

A one-off feature that will not be run repeatedly → prompt an agent directly; do not build a feature slot. The compliance earns its keep when the same workflow runs often (agents, CI, or repeated automation) and you need verification, metering, and safe autonomy.