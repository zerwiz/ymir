## runtime · unversioned · 2026-10-17 — a2a-talk speaks a2abridge 3.0.0 (the door no longer lies)

### Why
3.0.0 serves the registry at /agents (a bare array) and 404s on /, so the tool reported 'directory unreachable' against a live directory. It now tries /agents then /, and accepts either shape.

### Files
- `bin/bridge/a2a-talk.sh`