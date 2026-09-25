## gate · unversioned · 2026-09-25 — the gate could not see 158 of its own notes

### Why
A push was refused for carrying no fix note, while carrying two. The fault was in the
gate, not in the push.

- `bin/fixes-guard.sh` admitted only names beginning with a digit:
  `^docs/fixes/[a-z]+/[0-9][^/]*\.md$`. But a note's name is `<version>-<slug>.md`,
  and `bin/fixes.sh record --version=<v>` writes **whatever version it is told** —
  including `unversioned`, which is the convention 158 of the repo's 286 notes use.
  The gate could not read more than half of the record it exists to read, and refused
  a push that satisfied it. A gate that cannot see a note cannot judge one.
- **The count, before the widening:** 286 notes tracked, 128 digit-first, 158 named
  `unversioned-`. **After:** 286 visible.
- **Widened** to `^docs/fixes/[a-z]+/([0-9]|unversioned-)[^/]*\.md$`. Nothing else in
  the guard changed: it still demands at least one new note in the range, and it still
  reports whether that note names a path the range touched.
- **This note is its own proof.** It is named in the convention the old gate could not
  see, and the widened gate admits it. Had the widening been wrong, this push would
  have been refused a second time.
- The alternative was to rename the notes to satisfy the gate. That was rejected: it
  would have left 158 notes invisible and taught every future author to work around a
  gate rather than mend it.

galdr-reread: `brokk-distro-runtime.md` (the fix-note gate).

### Files
- `bin/fixes-guard.sh`
