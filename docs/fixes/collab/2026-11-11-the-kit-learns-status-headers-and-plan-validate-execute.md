# The kit learns the status script, headers, RULES/19 and the tickets shelf (1.3.0 → 1.4.0)

**2026-11-11 · component: collab**

## What was wrong

The collaboration kit gave a repository its baton, fix notes, gates and areas, and nothing about the *state of
its documents and plans*. Example5 proved the missing pieces first (branch `agent/claude-process`): a status
script that reads headers, a header format, a rule that no implementation precedes a validated plan, and a
tickets shelf under it. The operator's words (2026-11-11): *"plan, validate plan, then execute. no
implementations before validations are proven"* and *"tickets are not validated plans. there can be several
tickets on one plan"*. None of it travelled, so every other repository would have had to reinvent it.

Two faults sat beside it. `smidr-the-workbench/SKILL.md` had an unquoted `description:` containing `: `, so YAML
failed with `mapping values are not allowed here` and a harness refused to load the skill. And
`standardise.sh` excluded **every** `README.md` from the kit, so a `plans/tickets/README.md` could never install.

## What was forged

Kit **1.4.0** (a referee change, so it carries this note and a version):

- `scripts/status.py` — the status of plans, tickets and documents from their headers, standard library only.
  Made generic: no `FOREMAN-` prefix; it reads `plans/.prefix` when present, else the prefix the plan files
  share, else `PLAN`. It still skips `docs/kit/` and `docs/fixes/`.
- `RULES/19-plan-validate-execute.md` — written for any project; the validator is the area owner named in the
  project's `AGENTS.md`.
- `plans/tickets/README.md` and `TEMPLATE.md` — generic (`<PREFIX>-<plan>-T<nn>-<slug>`).
- `docs/headers.md` — the document and plan header, the statuses, the References rule.
- Every kit document under `docs/` now carries the header and a References section.
- The workbench skill's `description:` is quoted.
- `standardise.sh` excludes `README.md` except under `plans/tickets/`; version 1.4.0; the kit README's
  `contents[...]` block gains four rows (15 → 19).

## What was run

```
yaml.safe_load(SKILL.md header), before → ScannerError: mapping values are not allowed here
yaml.safe_load(SKILL.md header), after  → name, description, domain, … (loads)
standardise.sh --check <throwaway git init under /tmp> → kit 1.4.0, missing 44, incl. scripts/status.py,
  docs/headers.md, RULES/19-plan-validate-execute.md, plans/tickets/{README,TEMPLATE}.md
standardise.sh --apply, then scripts/status.py --check in that repo → 0 problems, 7 documents, rc 0
scripts/status.py in a repo with ACME-001 plan + ticket → prefix found, plan and ticket ok; with
  plans/.prefix=OTHER → ACME plans not read (the file wins)
bin/collab/tests/test_collab.sh → 21 passed, 1 failed ("a complete baton passes") — the same failure on HEAD
  before this change, so not caused by it
```

## What is not done

The kit's text still uses Ymir's house vocabulary, which business projects refuse; a plain-words variant is
proposed in the delivery report, not written here. A guard that reads a pull request body for its ticket is not
part of this change.

## CHANGE LOG

- **2026-11-11** — written by the errand that shipped it; CHANGE LOG section added when the branch was merged for one PR.
