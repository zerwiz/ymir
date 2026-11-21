## records · unversioned · 2026-11-21 — plan-sync reads a ledger kept in the project's own repository

### Why

The operator asked for a project's plans to move onto its board, and that project keeps its ledger in its own code
repository. Plan-sync only knew ledgers in the home, so it could not see those plans at all. The project's index also
lists plans without links, marks history as `record`, and calls its phases *slices* numbered `N`. Plan-sync read none
of those. The first real run also stopped early: the board door answered "no such place" for a place it listed in the
same answer, because its own lookup had been rate-limited.

### What

- `board.plans_repo` in a registry row names the clone, the ref and the folder. The ledger is read **at the ref**
  through `git archive` into a private temporary folder, so the checkout is never read or moved. `fetch: true`
  fetches the remote first.
- Cards from a repository ledger say the file is *in the repository*. They link to it through the row's `git:` block.
- An index row with no link is matched to the one ledger file of that number, and its status comes from the table's
  `Status` column. Linked rows read exactly as before.
- `board.status_map` maps a ledger's own status words onto state groups before the built-in words.
- `board.phase_heads` adds a ledger's own column words for phase tables. It never removes the built-in ones.
- `board_adapter_mcp.py` waits and retries when the door says "no such place" for a place it lists in the same answer,
  or "no such state" for a state the place has already listed. The second run of the night failed 32 plans on
  exactly that (`no such state …: Backlog`, a state the place has). A state the place truly lacks is still a refusal.

### Proof

- `bin/boards/tests/test_plan_sync_repo.py`: 21 checks, all ok. They cover reading at the ref (not the checkout),
  unlinked rows, the maps, the link, a refusal for an unknown ref, cleanup, and a home ledger unchanged, and
  which door answers are retried and which still refuse.
- The old and new readers were compared on the two home ledgers that have boards today. Both gave the same plans and
  the same card text, with no phase differences. So their stamps are unchanged, and a sync of those boards writes nothing.

### Files

- `bin/boards/plan_sync.py`, `bin/boards/board_adapter_mcp.py`
- `bin/boards/tests/test_plan_sync_repo.py` (new)
- `docs/features/plan-sync.md` (appended section)
