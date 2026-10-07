## gate · unversioned · 2026-10-05 — the registers indexed the new door

`bin/README.md` and `.agents/assets/agents/capabilities.md` are **generated** by
`bin/gates/inventory.sh` and `bin/gates/capabilities.sh`. Both went stale the moment
#294 added `bin/bitrate-gate.sh` and #282 reshaped `bin/` into system folders.

**Regenerated, not hand-edited:**

```
bin/README.md             403 -> 404 doors, including bitrate-gate.sh
.agents/backend/README.md 175 files
capabilities.md           "Pi extension tools" 39 — unchanged and correct
```

**Why it is a change and not housekeeping to be waved through:** the capability register
exists so that *a door with no row cannot ship*. A stale index is that gate not
holding, and `inventory --check` is right to refuse a tree carrying one — the same
shape as every other silent failure recorded this week, where a moved file left a
caller behind and nothing said so.

This is the housekeeping that follows any change to the shape of `bin/`, kept as its
own change rather than folded into either of those PRs.
