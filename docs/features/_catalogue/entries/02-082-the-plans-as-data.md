---
section: agents-work-collaboration
---
| Collaboration | The plans, as data — every shelf the registry names, read once, done only on evidence | `bin/records/plans-state.sh` reads every plan shelf `hodd/identity/projects.yaml` names and answers per plan whether it is done and what proves it — a `state:` or `Status:` header, a `register.md` row, the `done/` folder it sits in, or a PR GitHub says merged (`--with-prs`) — writing `hodd/registry/plans-state.yaml`; a state it cannot measure is `open`, never `done`, a missing shelf prints `ABSENT` with its path, and `bin/day/day.sh plans [--done 7d · --blocked · --json · --carry · --check]` is the read. | [Guide](docs/features/the-plans-as-data.md) |
