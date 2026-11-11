---
section: agents-work-collaboration
---
| Records | **The project brief — "brief me on this project", in any tool** (`bin/records/project-brief.sh` · [how-to](docs/features/the-project-brief.md)) | His word, 2026-11-11: *"if I would start a session from 0, how would we know all this then"* · *"this must work for all coding tools, and several projects"* · *"only brief per project if asked to"*. Resolves the session's directory (git remote or clone path; a worktree to its main checkout) to its entry in `hodd/identity/projects.yaml`, and prints the entry's home folder (`seat:`) and its `NOW.md`, the open to-do lines and the newest daily lines that name it (`id`, `name`, `aliases:`). On request only, through the Sága skill. Proved by `project-brief.sh --self-test` on a fixture home | [docs/features/the-project-brief.md](docs/features/the-project-brief.md) |

## CHANGE LOG

- 2026-11-11 — added with the door.
