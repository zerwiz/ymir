---
section: core-install-run-operate
---
| CI gate | The whole tree is judged before anything merges (`whole-tree` check, plus one `main-red` issue) | every pull request and every push to `main` runs `bin/gates/ci-verify.sh` on a clean runner; branch protection requires the check, and a red `main` files one issue naming the ward and the breaking commit | [docs/features/the-ci-gate.md](docs/features/the-ci-gate.md) |
