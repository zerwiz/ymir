---
section: memory-secrets
---
| Security | **The NDA gate — company and client names never reach the public repo** (`bin/gates/guards/nda-guard.sh` · [how-to](docs/features/the-nda-gate.md)) | His word, 2026-11-12, after an inventory of project folders leaked into `main`: *"we cannot leak company information in Ymir's public repo."* One matcher reads the protected names from the home at run time (every company, client and non-public project, non-public realms, and the hand-written `nda:` list) and refuses them in the Claude Code write hook, `pre-commit`, `commit-msg`, `pre-push` and the tree ward; a word that is also plain English goes in `config/nda-allow.yaml` with its reason. Proved by `bin/gates/tests/test_nda_guard.sh` | [docs/features/the-nda-gate.md](docs/features/the-nda-gate.md) |

## CHANGE LOG

- 2026-11-12 — added with the gate.
