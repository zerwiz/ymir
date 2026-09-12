# features/ — __PROJECT__

Feature-specific automation. One directory per feature registered in `FEATURES.md`.
Each feature is a slot where the compliance can operate a real procedure of this project.
Every feature registered in `FEATURES.md` (root) MUST have a matching skill directory
here — this is how zero feature duplication and zero ad-hoc commands are enforced.

## Layout

```
features/<feature>/
├── SKILL.md         # Feature scope & script binding map
├── setup.sh         # Environment/data bootstrap
├── test.sh          # Feature-isolated test suite
├── smoke_test.sh    # Feature health verification
└── rollback.sh      # Teardown / emergency rollback
```

## Rules

- Every feature has the five script domains (Lifecycle, Testing, Data & Setup, Source Control, Diagnostics) per `docs/project-skills.md`.
- No feature may exist in `FEATURES.md` without a matching directory here.
- **Register first, then wire:** add a row in `FEATURES.md`, create the directory, then bind the scripts to the app's real commands.
- **Wire, never rewrite:** delegate to existing procedures (e.g., `scripts/...`, `mix test`, `npm test`, `pytest`) and add env + exit-code guards.
- **Danger annotations:** a script that can delete data, migrate production, or force operations MUST start with a comment `# gate: dev|guard|human`. `check_danger.sh` fails on unannotated dangerous scripts; the runner refuses to auto-run `guard`/`human`.
- **No stubs in production:** `check_wiring.sh --strict` must pass before agents are trusted. A stub script is `WIRE ME` until replaced.
- Keep this file in sync via `.compliance/gates/verify_docs.py`.

## Growth

Adding a feature grows the compliance automatically: register it, wire its five scripts,
and `runner.py --list` / `--plan --feature <name>` pick it up with no compliance changes.

## Wiring walkthrough

See `docs/BEST_PRACTICES/compliance-wiring.md`.