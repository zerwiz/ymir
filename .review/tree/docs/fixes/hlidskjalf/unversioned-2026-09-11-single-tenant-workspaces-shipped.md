## hlidskjalf · unversioned · 2026-09-11 — Single-tenant workspaces shipped

### Why
- **First setup:** `bin/ymir-install.sh` (8 steps) + `bin/workspace-provision.sh`.
- **Model:** single tenant; workspaces (personal|work) over domains; houses = brands.
- **UI:** Login onboarding (name/kind/domains), Topbar workspace chip, AccountMenu/Profile relabelled.
- **Engines:** treehouse → `yggdrasil.sh pool`; sandcastle → `utgard.sh sandcastle`; no-mistakes → Mjollnir gate.
- **GitHub:** `bin/project-git.sh` reads `workspace/projects.yaml` `git{}`.
- **Verified:** build green, compliance 8/8, smoke 8/8, lint 4/4.

All significant runtime, policy, and architectural changes for the Ymir platform.
Entries are appended chronologically; never rewritten.

### Files
- *(carried from the frozen CHANGELOG.md)*
