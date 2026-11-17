# gate · 2026-11-16 — the ward judges what the push ADDS, not the whole file it touched

## What it refused

`bin/gates/guards/public-data-guard.sh` was scoped to the changed FILES and then judged every line
in them. A note edited to record a new fix re-carries every sentence it already had, so a line that
had been on `main` for days refused the new push. That is the "inherited" rule of plan 243 §3 part D
applied to the wrong unit: a path, where the fault is a line.

## The mend

`bin/gates/guards.sh` now exports the base it resolved (`YMIR_GUARD_BASE`), the scoped ward passes it
on, and `public-guard.py` gains `--added REV`: only the lines the range adds are judged, the rest are
COUNTED and printed as inherited.

```
public_guard_scope[1]{judged,exempt,words,machines,machine_class,lines}:
  "1","0","2","7","advisory","added since origin/main"
public_guard_inherited[1]{lines,verdict}:
  "3","carried by the base — the range did not add them, so they cannot refuse this push"
```

CI (`guards.sh --full`) and a person running the ward by hand still judge every line of every file.
Nothing is scoped away: the binding gate keeps the last word, which is what makes the fast one safe.

## What a name still does — and why the refusal stands

A word from the operator's own list is still refused wherever it appears, prose included. RULES/04
is explicit: *a name in this tree is not a detail, it is a person's data, published for ever*, and
its 2026-11-03 entry records a name and two mailboxes in a feature page and two fix notes that **no
ward caught**. Relaxing that to "code lines only" would re-open exactly that hole.

What changed is that the finding now names the remedy in the same breath, so the sentence is mended
in one pass instead of after a hunt through the rule:

```
names the operator (RULES/04) — write the ROLE instead
(the operator · the client · a prospective collaborator)
```

## The proof

`bin/gates/checks/public-data-ward.test.sh` (already wired, `0100-public-data.sh`) gains two cases in
a throwaway repository:

- an address that stood in the base is reported as inherited and does not refuse the push;
- an address this range adds is still refused.

Run it: `bash bin/gates/checks/public-data-ward.test.sh`.
