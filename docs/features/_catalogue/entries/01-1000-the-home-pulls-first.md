---
section: memory-secrets
---
| Vault | **Home sync** (`bin/vault/home-sync.sh`) | Pull before an edit, push right after: `begin` merges origin, `ship` commits named paths and pushes with merge-and-retry on a lost race; append-only records merge by union via migration 0018 (RULES/50) | — |

See docs/features/the-home-push-door.md

## CHANGE LOG

- **2026-11-10** — written with the change it describes.
