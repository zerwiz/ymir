---
section: core-install-run-operate
---
| Health | **The Health view — every service and app, measured** (`apps/hlidskjalf/server/health.ts` · `/api/soak` · `apps/hlidskjalf/src/components/SoakHealth.tsx`) | A panel on Hlidskjalf's Runtime page that reads the leak ledger (RSS, file descriptors, inotify watches, children, GPU, restarts, every five minutes) and each app's last soak, judges every row against plan 286 §5's budgets, and says one plain word: **holds**, **grows** or **restarts** — `unknown` when there is not yet enough to judge, and the number that broke its budget is always named | [The Health view](docs/features/the-health-view.md) |

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #763
