## sessrumnir · unversioned · 2026-09-19 — the hearth was painted behind the wall

### Why
- `.chat-center` painted `--color-chat-column` on the element itself, so the
  `EmberBackground` canvas mounted inside it at `-z-10` was covered by its own parent's
  colour: the embers were drawn every frame into a layer nobody could see.
- The colour moves to `.chat-center::before` at `z-index:-20`, below the ember, so the
  embers rise in front of the column from the bottom as the landing's do.

### Files
- `(see the body)`
