# Contributing to Ymir

Ymir is an open agent runtime. Anyone can fork, modify, and submit PRs to the
main tree at [zerwiz/ymir](https://github.com/zerwiz/ymir).

## Quick start

1. **Fork** the repo on GitHub.
2. **Clone** your fork:
   ```bash
   git clone git@github.com:<your-username>/ymir.git
   cd ymir
   ```
3. **Install** the runtime:
   ```bash
   bash scripts/start.sh
   ```
4. **Make changes** on a feature branch:
   ```bash
   git checkout -b feat/your-feature
   # edit files …
   git commit -m "feat: describe your change"
   git push -u origin feat/your-feature
   ```
5. **Open a PR** against `zerwiz/ymir:main`.

## PR guidelines

- **One thing per PR.** A PR should do one focused thing — a fix, a feature, a
  refactor. Squash if you need multiple commits for the same logical change.
- **Follow Norse naming.** Name subsystems, components, and processes for the
  figure whose role matches its work. See `.agents/assets/agents/naming.md`.
- **No secrets.** Never commit `.env.local`, `.env.realm`, API keys, tokens, or
  private URLs. Ship `.env.example` templates only.
- **Tests pass.** If your change touches code, run the test suite:
  ```bash
  bash .agents/tests/smoke.test.sh
  ```
- **Update docs.** If you change a component, update its asset in
  `.agents/assets/` and the master plan in `docs/masterplan.md`.
- **Human review.** All PRs require explicit approval from the Allfather before
  merge. No force-pushes. No auto-merge.

## For agents (Eindri)

Every agent in the Ymir tree should have the **pr-ops** skill installed. It
provides the standard workflow for creating branches (via `git-ops`), committing
with gates, and opening PRs to the main repo. See `.agents/skills/pr-ops/SKILL.md`.

## Code of conduct

- Respect realm boundaries — never read, write, or reference another realm
  without explicit approval.
- Fail safely — a failed execution never touches main.
- Output over process — always produce a tangible artifact.

## Questions?

Open an issue on the repo or reach out through the Ymir portal.

## Members

The Allfather's hall has more than one set of hands. Current
contributors who may access the private repo and YMIR_HOME data:

- **zerwiz** — the Allfather, primary operator
- **craig** — member contributor

Members with private-data access must keep realm boundaries
sacred and never share another operator's secrets, tokens, or
tenant material (Rule 04).
