# gates · unversioned · 2026-11-14 — the ratchet counted with a liar

The portability ratchet (RULES/05) passed or failed at random. Two runs over one unchanged commit,
same tree, gave `stat -c` **38** and then **34**. A gate that flickers is a gate nobody trusts, so it
was traced before anything else was believed.

## The cause

```bash
set -uo pipefail
git show "HEAD:$f" | grep -v '^[[:space:]]*#' | grep -q -- "$pat"
```

`grep -q` exits at the **first match**, which SIGPIPEs the writer before it finishes. Under the file's
own `pipefail`, the pipeline then reports the *broken writer's* status, not `grep`'s — so whether a file
that really does call `stat -c` was counted depended on timing and buffer size.

The damage was already in the record: the baseline (`hodd/data/portability-baseline.yaml`) was written
from that noise on 2026-11-02 and claimed **84** callers while the tree holds **127**. Every run since
compared reality against a number that was never real.

## What changed

- `grep -c … >/dev/null` instead of `grep -q`: `-c` reads all of the input, so no writer is killed and
  the answer is the content and nothing else.
- **The baseline was re-recorded on the honest count** (home file, shipped separately): `stat-c 49 ·
  sha256sum 46 · flock 9 · mapfile 12 · nproc 2 · sed-i 9`, total 127. That is not a loosening of the
  rule — the callers were always there — it is the first time the ratchet has measured them.

## Proof

Three runs, same tree, same commit:

```text
"stat -c","49","33","ROSE"   →  "stat -c","49","49","ok"
"stat -c","49","33","ROSE"   →  "stat -c","49","49","ok"
"stat -c","49","33","ROSE"   →  "stat -c","49","49","ok"
```

(before the fix the same three runs gave 38, 34 and 32)

## Files

- `bin/gates/checks/portability-ratchet.sh`
- `hodd/data/portability-baseline.yaml` (in `$YMIR_HOME`, re-recorded and shipped with this mend)

## CHANGE LOG

- 2026-11-14 — written with the mend; found while proving the whole-tree gate green, not on the list of
  known reds.
