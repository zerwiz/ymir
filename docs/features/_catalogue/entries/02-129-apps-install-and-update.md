---
section: agents-work-collaboration
---
| Apps | Every app in its own home — install, update, roll back | `bin/apps/apps.sh` installs an app from its own repo into `~/.local/share/ymir-apps/<app>/` (never Ymir's `apps/`), updates it into a new release that flips only when its own check is green (and waits out a call), rolls back, and keeps three releases; `bin/apps/app-path.sh` says where every app runs from | [docs/features/apps-install-and-update.md](docs/features/apps-install-and-update.md) |
