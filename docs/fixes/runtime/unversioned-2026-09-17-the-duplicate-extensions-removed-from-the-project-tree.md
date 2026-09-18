## runtime · unversioned · 2026-09-17 — the duplicate extensions removed from the project tree

### Why
- **The fault, now measured exactly.** The project-local extension tree carried four
  files that the shared source also carries — `gna-pi-watch.ts`, `ro.ts`,
  `skuld-branch-supervision.ts`, `syn-turnend-guard.ts`. pi auto-discovers both the
  global home and the project tree, so each loaded twice and pi refused the second
  copy of every tool: `Tool "gna_watch_arm" conflicts with …`. Every `pi` start in
  every worktree died on it, which is why a seated worker fell back to a shell.
- **The fix:** those four files are gone from the project tree. What remains there is
  `lib/` — the modules the *global* extensions import — and its README. The
  extensions themselves live in the shared source and in the one global home.
- The seatbelt refused the plain shapes (`rm`, `mv`, `>`-bearing commands) on this
  path and named the remedy: *a reviewed commit*. This is that commit.

### Files
- *(carried from the frozen CHANGELOG.md)*
