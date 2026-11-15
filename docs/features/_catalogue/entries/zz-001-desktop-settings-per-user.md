---
section: core-install-run-operate
---
| Settings | **Desktop settings per user — `desktop.env`** (`$YMIR_HOME/config/desktop.env`) | One file in the home answers for the person: the GPU policy (`auto`/`1`/`0`), the surface (`auto`/`wayland`/`x11`) and window placement; every app launcher reads it before it decides anything, and an explicit environment variable still wins | [docs/features/desktop-env.md](docs/features/desktop-env.md) |

## CHANGE LOG

- 2026-11-13 — review-mend: added missing heading for #731
