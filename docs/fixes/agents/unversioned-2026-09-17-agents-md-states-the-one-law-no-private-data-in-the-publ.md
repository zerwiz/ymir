## agents · unversioned · 2026-09-17 — AGENTS.md states the one law: no private data in the public repo

### Why
- **The law is now first.** A `first_law` block sits directly under the mandate
  in `AGENTS.md`: never store personal or private data in this repo — not a
  secret, a key, a name, a plan, a schedule, a client, a credential, or a note.
  The repo is public; private data lives at `$YMIR_HOME`, under `hodd/`.
- **The private-data section was rebuilt against the disk.** It had duplicated
  `secrets/` and `identity/` lines, no `hodd/` level, and a layout that no longer
  matched the home. It now shows the real tree, names `$YMIR_HOME/hodd/` as *the*
  private data path, and records that `bin/hoard-lib.sh` is the one source of
  truth for it.
- **Every `$YMIR_HOME/...` path in the file was corrected** to `$YMIR_HOME/hodd/...`
  — the directory rules table, the registry reference, the secrets reference, and
  the append-only ledger path all pointed at the old flat layout.
- **Two wards are now documented**: `bin/secret-guard.sh` (a secret entering the
  repo) and Eir's `hoard` surface (private data drifting outside the hoard, or a
  `.ymir-layout.yaml` naming a path that does not exist).
- **Staging discipline is written down.** Stage named files in the home, never
  `git add -A` — a scratch file written seconds earlier gets swept into a commit
  and pushed. This happened this day and cost a history rewrite.
- **`hodd/AGENTS.example.md`** carried the same stale flat paths and a wrong

### Files
- *(carried from the frozen CHANGELOG.md)*
