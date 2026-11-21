---
section: agents-work-collaboration
---
| Review | The judge merges — every PR reviewed, an approval merged at once | `review-watch.sh --keeper` seats the judge for every open PR head (or hands it to a developer seat); `judge-merge.sh` carries out the verdict; `pr-seal.sh seal <n> --repo --head` re-checks the gates and merges under the owner's account | [docs/features/the-judge-merges.md](docs/features/the-judge-merges.md) |

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #863
