## hoard · unversioned · 2026-09-17 — Skrymir opens the hoard, not the checkout

### Why
- **The file browser was rooted in the wrong tree.** `workspaceRoot()` built every
  realm path under `ROOT` — the checkout — so `work` resolved to a directory that does
  not exist and the walk fell back to the repo's `docs/`. That is why Skrymir showed
  `lore.md`, `Architecture.md`, `research/`, `runbooks/`, and why a file it had just
  listed answered **"not found"**: the listing came from one tree and the read from
  another.
- **The hoard first now (Rule 04):** `$YMIR_HOME/svartalfaheim/<realm>` → company
  container → `$YMIR_HOME/workspace/<realm>` → the checkout only as legacy. An empty
  realm shows the hoard's home, never the repo's docs. Verified: `work` lists
  `memory/daily/2026-09-13.md` and `workspace/`, and a read returns its body.
- Note for the next hand: the gate runs **without** `--watch` — a server edit is on
  disk and not in the process until `scripts/start.sh` raises it again.

### Files
- *(carried from the frozen CHANGELOG.md)*
