---
section: agents-work-collaboration
---
| Delivery | **Gather a batch — many errands, one push, one PR** (`bin/forge/gather.sh` · [how-to](docs/features/gather-a-batch.md)) | His word, 2026-11-12: *"if multiple agents are sent out at the same time, it's much better to merge the branches locally into one push … so everybody is going through the gates."* Errands briefed `--mode batch` commit on `eindri/<id>` and never push; `gather.sh <id…>` or `--finished` merges them in one worktree from fresh `origin/main`, stops on a conflict naming branch and files (`--continue` resumes), gates once, opens one PR listing every acclaim, records the batch in the well and marks each errand shipped. The same amendment lets a documents-only push land on `main` (`branch-guard.sh --documents`). Proved by `.agents/tests/gather.test.sh` and `branch-guard-documents.test.sh` | [docs/features/gather-a-batch.md](docs/features/gather-a-batch.md) |

## CHANGE LOG

- 2026-11-12 — added with the door.
