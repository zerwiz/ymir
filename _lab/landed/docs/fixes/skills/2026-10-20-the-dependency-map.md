## skills · unversioned · 2026-10-20 — the dependency map

### What

The record renderer now writes `dependency-map.md`: a Mermaid `graph TD`, actions
grouped by owner, each node labelled with its deliverable and due date, and an edge for
every `dependency` that names another action. A table below the graph repeats the edges
for machines and for readers without Mermaid.

### Verified

- The pilot renders 16 actions across four owners; edges resolve to real action ids.
- Re-running the pipeline produced 9 documents (was 8), 6 decisions, 16 actions.

### Not verified

- Mermaid rendering is not asserted; the `.md` is generated and visually correct in a
  renderer, not tested in CI.
