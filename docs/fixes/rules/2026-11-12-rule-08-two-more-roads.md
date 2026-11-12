# Rule 08 gains two roads: documents on main, and the batch

**Date:** 2026-11-12 · **Component:** rules · **Door:** `RULES/08-delivery-gate.md` (appended section)

RULES/08 §08.1 said "Exception: None". An appended section now adds two roads at the Allfather's word.
A push of documents only, by an exact set of paths, may land on `main`. Errands dispatched together commit
and never push, and the helm ships them in one push and one PR through `bin/forge/gather.sh`. A lone
errand may still push its own PR. Everything else still leaves by PR, and who merges does not change.
The same section is noted at the end of `AGENTS.md`.
