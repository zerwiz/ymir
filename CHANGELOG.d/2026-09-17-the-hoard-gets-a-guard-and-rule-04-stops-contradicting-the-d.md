## 2026-09-17 — the hoard gets a guard, and Rule 04 stops contradicting the disk

- **Eir gains a `hoard` surface.** Private data drifting outside the hoard is
  now caught rather than discovered by asking "where did that go?". The check
  fails on two things: a `.ymir-layout.yaml` entry naming a directory that does
  not exist (a stale map is what lets private work land outside the hoard), and
  a flat `$YMIR_HOME/{identity,data,docs,secrets,tenants}` sitting beside
  `hodd/`. `fix` merges a flat duplicate into the hoard without clobbering, then
  repoints any stale layout entry at the hoard.
- **Rule 04 corrected, append-only.** The rule's mapping table read as if
  `hodd/x/` and `$YMIR_HOME/x/` were two locations; on a real home that produced
  two parallel stores which drifted. The appended correction states the truth:
  `$YMIR_HOME/hodd/` **is** the private data path, `bin/hoard-lib.sh` is the one
  source of truth for it, and `.ymir-layout.yaml` must name only paths that
  exist. Nothing above the correction was rewritten.
