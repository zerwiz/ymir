## hlidskjalf · unversioned · 2026-09-21 — the hearth's fire re-seeds when its container changes

### Why
- the EmberBackground canvas went blank after a pane/layout change

### Fix
- the hearth re-seeds its particles on container resize via ResizeObserver

### Files
- apps/hlidskjalf/src (the hearth component)
