# Projects — every project you work on, in one panel

The Projects panel (Hliðskjálf, the old Worktrees tab) lists the projects you have cloned **on this machine**, with
their worktrees, owning agent, open pull requests, CI, and the state of the collaboration kit. The same data is on the
command line as `ymir projects`.

## What you need

- A `projects.yaml` registry in your home (`hodd/identity/projects.yaml`). With none, the panel is empty and tells you
  how to add a project.
- `gh` signed in, for pull requests and CI. Without it the rows still show worktrees and the kit.

## The commands

| Command | What it does |
|---|---|
| `ymir projects` | Lists every project cloned on this machine (TOON rows; `--json` for scripts). |
| `ymir projects --fleet` | Also asks the other seats over ssh. This machine builds the answer and names each source seat. |
| `ymir projects add <repo-url\|path>` | Registers the repo, clones it into `~/CodeP` (or `YMIR_PROJECTS_DIR`) and shows it at once. |
| `ymir projects add <repo> --kit --report` | Also seats the collaboration kit and lets the repo report its state back. |
| `ymir projects kit update <id>` | Refreshes the kit in that clone. A report already seated stays seated. |
| `ymir projects reap <id> [--apply]` | Lists stale worktrees (branch merged, or path gone). `--apply` removes only those. |

Filters on the panel and the CLI: seat, realm, has PRs, red CI, stale. Pull requests are cached one minute per repo.

## Rules worth knowing

- **Only this machine by default.** Other seats are an opt-in (`--fleet`, or the *fleet* box in the panel). A seat that
  does not answer is a row saying so, never an error.
- **A repo reports only when you say so.** The kit writes `report` into `.collab-kit.json` only with `--report`.
  Without it the panel shows "seated, not reporting" and reads nothing more. A collaborator's repo reports to the one
  house that seated it.
- **Private stays private.** `/api/projects?view=shared` (and `--public-view`) drops every project not marked public.
- **Reap is careful.** It never touches the primary checkout, the worktree you stand in, a claimed branch, a dirty
  tree or a branch with unmerged work. Cloning refuses with less than 40 GB free (`PROJECTS_MIN_FREE_GB`).

## If it does not work

- *Empty panel:* nothing is registered or cloned here yet. Run `ymir projects add <repo-url>`.
- *No PRs shown:* run `gh auth status`; add `--refresh` to skip the one-minute cache.
- *A seat shows "unreachable":* check its ssh entry; the rest of the answer is still correct.
