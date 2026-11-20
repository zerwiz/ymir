## snotra · unversioned · 2026-10-21 — the mutable access log leaves the manifest

### What

`snotra-provenance.sh` hashed every file in the meeting directory, including
`access.jsonl`. Every read or refused export appended a line, so `verify` failed after
the next access — a seal that invalidates itself on use.

The manifest now excludes `access.jsonl` and the `timestamp/` directory. The access log is
still append-only and mode 0600; the timestamp token refers to the manifest root, so it
cannot be inside that root.

### Verified

- Pilot: re-sealed, `verify` clean with the access log present.
- The root is unchanged by new access entries.
- A local-unqualified timestamp was written against the root.

### Not verified

- Off-host log shipping and hash-chaining of the access log itself; that is plan 94.
