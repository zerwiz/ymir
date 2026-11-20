## runtime · unversioned · 2026-09-18 — a username was in a tracked file (corrected, not rewritten)

### Why
- Two entries carried `$HOME/Ymir` — the operator s own username, in a public file.
  They now read `$HOME`. The rule is absolute and already in the changelog: **no hardcoded
  absolute file paths**, ever — a home path names a person, and this repo is public.

### Files
- `(see the body)`
