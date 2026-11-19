## gates · 2026-11-19 — the gather undid the allow file, and the audit reads it again

The twice-daily private sweep queued **220** findings at 04:10 on 2026-11-19. The errand that triaged
them found the interesting half of the story was not in the findings: a merged, sealed change had been
**silently reverted** the day before by a squash that carried a stale branch's copy of four files.

### What the triage found

| Class | Count | What it is |
|---|---|---|
| A historical name inside the record of an older change (`docs/fixes/`) | **217** | real, and still the Allfather's decision (plan 287 §3): redact by a dated correction, or leave as history. `RULES/06` forbids a silent rewrite, so no note was touched |
| A documented false positive: a public figure's name in a published research note | **1** | already written down in the home's allow file (rule 20) — and it alarmed anyway, because of the fault below |
| A file that no longer exists | **2** | `.pi/extensions/herdr.ts` was split into a directory after the sweep ran; the findings went with it |

Nothing in this class was a secret. No key, token or private-key header was found, so nothing needs
rotation.

### The fault: a squash that carried a stale copy

`21cf7c27` — *"gather: one batch — the errands that were still out, and the trees that were never
merged"* — was made on top of `8dff432c` (PR **#816**). Its commit message lists the errands it
carried, and one of them still held the **pre-#816** version of four files. The gather wrote those
stale copies over the merged, sealed ones, so #816's own delivery was undone while its fix note stayed
in the tree telling the reader it had landed.

| File | What the gather removed |
|---|---|
| `bin/gates/agnostic-audit.sh` | `--allow FILE`, `YMIR_AUDIT_ALLOW`, the `allowed:` block, the `allowed` field of the machine row, `--paths-only` (87 lines) |
| `bin/time/nornir-job-private-scan.sh` | the sweep's use of `--paths-only` and its reading of the engine's `allowed` count — it went back to parsing the human report with a shape regex |
| `bin/gates/tests/test_agnostic_audit.sh` | the two properties that would have caught this: a recorded reason clears the tree but is still counted and printed, an allow rule is **anchored** on its path, and `--paths-only` prints paths and the one machine row and nothing else |
| `docs/features/agnostic-audit.md` | the page for a person: the two flags, the allow file, the `allowed` field |

The consequence was exact and measurable: the home's allow file held 50 rules and **not one of them
was ever consulted** for an engine finding, so a documented false positive alarmed twice a day for
ever, and the run line reported `allowed` as a number that could not be true.

### What this change does

It **restores** the four files to their #816 content, byte for byte (`git checkout 8dff432c -- …`). No
new code is written, because the house had already written and sealed this one; the fault was that a
later commit ate it.

| Before (at `origin/main`) | After |
|---|---|
| `218` findings, `allowed` not reported | `217` findings, `allowed: 1` |
| the sweep queues `218` (all of the attackable class mixed with a recorded one) | the sweep queues `217` — the fix-note history alone — and reports `4 allowed` |
| a fix note says the file is read, and it is not | the fix note is true again |

### The proofs, all on this machine, no build

- `bash bin/gates/tests/test_agnostic_audit.sh` — **24 properties hold**, including the six the revert
  had deleted: a recorded reason clears the tree, is still counted and printed, never prints the word,
  stays out of the machine row's finding count, is anchored on its path, and `--paths-only` prints one
  `path:line` per finding plus the one machine row.
- `bin/gates/agnostic-audit.sh` on the tree: `"the tree","217","123","19","1","FAIL"` — the same 217 in
  123 files that #816 measured when it was sealed.
- `bin/gates/agnostic-audit.sh --paths-only`: 217 bare `path:line` rows, then the machine row — nothing
  for a job to misread.
- The sweep itself, run in a scratch home against this branch:
  `2026-11-19T04:22:36Z private-scan: 217 high · 0 low · 4 allowed`, and every queued row is
  `AGNOSTIC` in `docs/fixes/`. Before this change the same run said `218 high · 0 low · 3 allowed`.

### What this does not do

It does not redact one fix note. The 217 are real, they are the record of older changes, and
`RULES/06` says a fix note is appended to, never rewritten — so the choice between a dated correction
per note and leaving them as history is the Allfather's, exactly as plan 287 §3 says. It also does not
touch the home's deny list, whose one `name:` entry that is also a fleet machine is a decision about
what the ward refuses.

> [!IMPORTANT]
> A squash that carries a stale branch can revert a merged change and leave no conflict to notice.
> The canary caught nothing because the canary's own properties were in the reverted set. What would
> have caught it: the same file's test running on `main` after every merge into it.

- **2026-11-19** — written with the change: four files restored from `8dff432c`, one false positive
  recorded in the home, 217 left for his word.

## CHANGE LOG

- 2026-11-18 — review-mend: added missing heading for #825
