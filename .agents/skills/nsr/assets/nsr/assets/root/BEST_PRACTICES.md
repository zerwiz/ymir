# Best Practices

Code quality, patterns & design guidelines index. Category-specific standards live in `docs/BEST_PRACTICES/` — this file is the index.

## Categories (`docs/BEST_PRACTICES/`)

| File | Status | Domain |
|------|--------|--------|
| `api.md` | 🚧 Planned | REST/API design, versioning, error handling |
| `state-management.md` | 🚧 Planned | State patterns, immutability, data flow |
| `code-quality.md` | 🚧 Planned | Lint rules, naming, review checklists |
| `compliance-wiring.md` | ✅ Built | How to wire the compliance to a project's real procedures (start/stop/test/deploy per stack) |

## Cross-Cutting Practices

- **Deterministic operations** — every action is a script in `.agents/skills/`; nothing is typed ad-hoc.
- **Exit-code discipline** — automation is judged by `$? == 0`, never by parsing text output.
- **Typed handoffs** — inter-agent communication uses JSON/YAML envelopes, not unstructured summaries.
- **Observability first** — every agent phase logs tokens, latency, tool calls, and cost.
- **Thin context routing** — agents ingest root routing files + subfolder `AGENTS.md` only; detail lives in sub-docs.
- **Doc-driven navigation** — use `STRUCTURE.md` to find files and `FEATURES.md` to avoid duplicate work.
- **Environment-driven everything** — no hardcoded config; inject via `.env`/secret manager; `.env.example` templates only.
- **Multi-tenant discipline** — tenant isolation at runtime; client identity is an env input, never baked into shared code.
- **Relative-path hygiene** — paths resolve from repo root; absolute paths are rejected by `check_paths.sh`.
- **Platform portability** — POSIX bash, forward slashes, LF endings (Mac/Linux/Windows) — validated by `check_platform.sh`.
- **Stack consistency** — follow `TECH_STACK.md`; one primary stack per feature; pin versions.
- **Docs-before-production** — every hosting (`docs/HOSTING/`) and developer (`docs/DEVELOPER_SETUP/`) documented before going live.
