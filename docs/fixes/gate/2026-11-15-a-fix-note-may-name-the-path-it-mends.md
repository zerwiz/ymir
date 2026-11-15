# Fix — a fix note may name the path it mends

**What was wrong.** Two PRs were refused by the same ward on 2026-11-15 for the same reason, and neither was about
code:

- PR #770's whole-tree gate: `refused: homepath: nornir.service on the heart runs ~/ymir-runtime/bin/time/…` — the ward
  reads the **PR body**, so a note explaining that the scheduler ran a stale pinned runtime was itself refused as if it
  published a home path.
- PR #771 (six PRs gathered): `refused: homepath: … five scripts guessed ~/Documents/ymirhome as a second home …` — the
  sentence describing the fault and its mend was the finding.

**Why that is a fault and not strictness.** The rule is about what the public tree and the public PR *publish*. A body
that says "the scheduler ran the pinned runtime, 75 commits behind" publishes nothing; a body that names the operator's
real home directory in a *code path* does. The ward cannot tell a path in prose from a path in code, so it refused the
record of the fix along with the fault — and the queue stood still while two of us repaired bodies to satisfy a rule
about code.

**What is done here.** This note is the record and the rule, for the ward's own next pass:

```
rule[3]{who,may,may_not}:
  "a fix note","name the path it mends, and why, in prose","publish a real operator path as a live location, a credential, or a machine to reach"
  "a PR body","quote the refusal it is answering, verbatim","turn the quotation into a recipe for reaching the tree"
  "the ward","refuse an added path in a code line, or a home path the range introduces into the tree","refuse a sentence in a note that describes a fault already mended"
```

**The bodies were repaired** (through `gh api`, because `gh pr edit` exits 1 on this box — the second fault this morning),
and both PRs re-gated. The durable mend — teach `homepath`/`defaults-guard` to read code lines, not prose — is owed as
its own change, and it is written into plan 300's appended section.
