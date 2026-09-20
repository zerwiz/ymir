## agents · unversioned · 2026-09-17 — the well as tools: Ymir's first custom pi extension

### Why
- **Why the extension tree was failing, from the upstream law:** pi auto-discovers
  extensions from BOTH the global home and the project-local tree. The same extension
  in both loads twice and pi refuses the duplicate tool —
  `Tool "gna_watch_arm" conflicts with …`. Ymir's own loader already says the shared
  extensions have **one** home; the tree contradicted it by carrying the extension
  files project-locally as well.
- **Built: `ymir-well`** — the well, as tools inside every pi session.
  `well_recall(query, k)` reads Kaia's memory before work begins;
  `well_observe(content, tags, actors, salience)` writes the lesson after. Written in
  the house voice, honest about failure (a failed write says the lesson was NOT
  written), and it sends tags as LISTS — a comma-string is stored as an array of
  characters, which is exactly how a recall once returned `['r','u','n']`.
- Authored in the SHARED source and deployed to the global home — one home, never a
  project copy. That is the pattern every future Ymir extension follows.

### Files
- *(carried from the frozen CHANGELOG.md)*
