# The mocks gate learned to tell a stub from a vocabulary

**Date:** 2026-11-08 · **Component:** gate · **Door:** `.agents/skills/galdr-ymirsystem/scripts/mocks-scan.sh` ·
`bin/gates/ci-verify.sh` · `bin/desktop/factory-check.sh`

## What was wrong

The `mocks` row of the compliance check was an **inline pipeline** inside `compliance-check.sh`: a grab-bag of
`grep -v` exclusions that had grown one false red at a time. Every exclusion was judged by eye, because no test
could reach a pipeline — so the gate drifted in both directions at once. On 2026-11-07 it was red on `main` with
nine legitimate uses of the four words:

```
hits[9]{file,why_it_is_not_a_stub}:
  "bin/day/day.py:15,80","a PATH ending in `hodd/life/personal/me/todo.md` — the operator's own note file"
  "bin/seat/ymir-mcp.py:239,254,271","a TOOL NAMED `todo`, mirroring Pi's own tool (the gate already excused the same name in bin/mcp)"
  "bin/desktop/factory-check.sh:28","a REFUSAL STRING describing a template's blank field"
  "bin/forge/utgard-box-door.py:6","a docstring about handing the box a throwaway key"
  "bin/seat/tests/test_core_four_pending_factory.sh:22","a test asserting that refusal"
  "bin/collab/kit/docs/advantage.md:101","prose describing what the audit refuses"
  "bin/collab/kit/scripts/advantage-audit.sh:109","the audit's own regex and verdict — its job IS to name those words"
```

A red gate that everyone learns to ignore is worse than no gate: the next real stub hides behind nine accepted
reds.

## The mend, in two halves

**1 · The scan became a file.** `.agents/skills/galdr-ymirsystem/scripts/mocks-scan.sh <root>` is now the one
implementation; `compliance-check.sh` calls it and keeps its row. Nothing else about the row changed — same four
words, same `bin/` scope, same first-hit reporting.

**2 · The excuses became narrow and written down.** Each exclusion now carries its reason in the file it governs:
a comment line · `PUBLIC=` · the RULES/42 KIND list (matched as the LIST, so a lone `stub` is still caught) ·
the RULES/17 `consumer:`/`todo:` PAIR · Pi's own tool names in **both** ymir-mcp doors (`bin/mcp` and `bin/seat`)
· a path ending in `todo.md` (a filename; `public-guard.sh` already allows `TODO.md` for the same reason) · the
collab kit's advantage audit, whose regex and verdict *are* the vocabulary.

**3 · Four strings were reworded rather than excused**, because the word was decoration and the gate should keep
biting there: `factory-check.sh`'s refusal now says *"an unfilled field … still the template's blank"*, its seat
test greps the new string, `utgard-box-door.py` hands the box *"a throwaway key"*, and the collab kit's page says
*"an unfilled blank"*.

## The probe

`.agents/tests/mocks-scan.test.sh`, wired into `bin/gates/ci-verify.sh` as its own gate row. It proves both
directions on a scratch tree:

- **it bites**: a real stub (`return "stub - the real work is not here"`) is caught and the scan exits non-zero;
- **it excuses only vocabulary**: comment · `PUBLIC=` · kind list · consumer/todo pair · both mcp doors · a
  `todo.md` path · the audit's vocabulary all pass;
- **the excuses stay narrow**: a lone `todo`, a look-alike door (`bin/seat/ymir-mcp-extra.py`), and an ordinary
  `placeholder` are all still caught — three findings, counted;
- **the shipped tree passes its own scan**, which is the row `compliance-check.sh` prints.

## Verification

```
proved[4]{what,how,result}:
  "the scan is clean on this tree","mocks-scan.sh .","rc 0, no hits (was 5 after the four rewordings)"
  "the probe passes","bash .agents/tests/mocks-scan.test.sh","4 ok, rc 0"
  "the gate still runs the same row","bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh","mocks PASS"
  "the CI wiring parses","bash -n bin/gates/ci-verify.sh","silent"
```

## What is still owed

The same audit is owed to the other compliance rows written as inline pipelines — `naming` and `config` are the two
longest, and neither has a probe that plants a violation. This change makes the mocks row testable; it does not
make the pattern universal.

## CHANGE LOG

- **2026-11-08** — written with the change (nidavellir): the scan extracted to a file, the excuses narrowed and
  written down, four strings reworded, the probe added and wired into `ci-verify.sh`, and `galdr.md`'s missing
  mirror row restored.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
