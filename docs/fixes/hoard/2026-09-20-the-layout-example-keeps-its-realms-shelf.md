## hoard · unversioned · 2026-09-20 — the layout example keeps its realms shelf

### Why
- A stray staging raced into the well-fix commit (`9d2b185`) and dropped the
  `svartalfaheim` mapping from `hodd/.ymir-layout.yaml.example`. The drop was the
  concurrent hand's reap — the line's annotation names "the company shelves" —
  but the seat `svartalfaheim/wayof/` still stands and the canonical layout
  (`AGENTS.md` — Private data — YMIR_HOME) documents the shelf at the home
  root. A template that stops teaching a path the layout still seats is drift:
  a fresh home's placement ward would never track the realms shelf.
- Append-only: the line is restored as its own commit citing the drop, never a
  rewrite of `9d2b185`.

### Fix
- `hodd/.ymir-layout.yaml.example` carries the `svartalfaheim` key again, back
  between `data:` and `git_repo:` where it sat before the stray drop, with its
  `# realms — the company shelves` annotation intact.

### Verify
- `grep svartalfaheim hodd/.ymir-layout.yaml.example` prints the restored line;
  the net diff of the branch vs `origin/main` shows the example unchanged.

### Files
- `hodd/.ymir-layout.yaml.example`