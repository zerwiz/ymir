## gate · unversioned · 2026-10-11 — the hoard ward was called by a pre-move path (silent), then bit the record and two fair files

**Cites:** `docs/fixes/gate/unversioned-2026-10-04-the-bin-rebuild-left-every-caller-pointing-at-the-old-door.md`.

### Why

Three faults on one ward, each hiding the next.

**1 — It was SILENT.** The compliance gate called `bash "$ROOT/bin/secret-guard.sh" --all`
and `…/private-guard.sh`; both wards live under `bin/gates/guards/`. bash answered
`No such file or directory`, the ward's own summary line never printed, and the row
came out with an **empty reason**:

```
"hoard","the hoard boundary (Rule 04)","FAIL","private-guard: "
```

The hoard boundary went **unjudged** from the bin move until 2026-10-11, while the row
merely looked red. `.agents/tests/private-guard-identity.test.sh` was dead the same way
(`FAIL guard present and executable`). *Both call sites were fixed by another hand
(PRs #313/#314) while this was in flight.*

**2 — Awake, it demanded that history be rewritten.** It named 14 files, 10 of them
`docs/fixes/**` — the fix notes that QUOTE the very leaks they removed, one of them
the note about this ward catching its own files. Rule 06 makes those append-only. A
ward that requires the record to be edited is a ward fighting the law. (Measured on
main `2fd9bb42`: exactly those 10 paths, and they were the compliance row's whole red.)

**3 — Awake, it bit its own law's door and a public doc.** `TENANT_DOC` matched the
**bare word** with ANY extension — `(…|confidential)(/|\.)` — so it flagged
`bin/vault/confidential.sh` (Rule 16's own door) and
`docs/features/confidential-session.md` (Rule 14's user-facing how-to). The ward's own
header says the opposite, in its own words:

> *"The match is deliberately a DIRECTORY or a doc suffixed with tenant content — NOT
> the bare word. `docs/guides/SECRETS.md` is a public how-to … so a bare `secrets`
> match would be a false positive."*

### What

- **`docs/fixes/*` is exempt**, with the Rule-06 reason in the comment. The live tree
  is still judged in full — only the record is spared.
- **`TENANT_DOC` is restored to the ward's own doctrine**: a company SHELF is a
  directory (`wiki/`, `handbook/`, `playbook/`, `internal/`, `confidential/`), and a
  tenant DOCUMENT is one of the words that is tenant content in a document's NAME
  (`vision` · `strategy` · `roadmap` · `policies`). The bare word is not evidence.
- **Four assertions added** to `.agents/tests/private-guard-identity.test.sh`: two fair
  files must pass (`confidential.sh`, `confidential-session.md`), two tenant shapes must
  still be blocked (a `wiki/` shelf, a `strategy-2026.md` document) — and the second of
  those is checked for the RIGHT reason, so the test cannot pass by failing for the
  wrong one.
- `RULES/04-hoard.md` — the eight references to the wards' pre-move paths are corrected
  by an **appended** section (Rule 06), never an edit.

### Verified

- `bin/gates/guards/private-guard.sh --all` → **was** `FAIL` with an empty reason;
  **now** `rc=0`, no findings.
- `.agents/tests/private-guard-identity.test.sh` → **11 assertions, ALL PASS** (was
  `FAIL guard present and executable`), including:
  `allows a fair file: qprobe/confidential.sh` ·
  `allows a fair file: qprobe/confidential-session.md` ·
  `blocks a company shelf (qprobe/wiki/notes.md)` ·
  `blocks a tenant document (qprobe/strategy-2026.md)`.
- The test leaves nothing behind (verified: no `qprobe/` in `git status`).

### Files

- `bin/gates/guards/private-guard.sh` — the shelf exemption, and the pattern restored
- `.agents/tests/private-guard-identity.test.sh` — four assertions
- `RULES/04-hoard.md` — appended correction: where the two wards live now
