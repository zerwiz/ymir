# gate · 2026-11-16 — an empty re-gate owes no fix note

## What it refused

`bin/gates/guards/fixes-guard.sh` refused any push whose range carried no new fix note. It did not
ask whether the range changed anything. So a `git commit --allow-empty` that existed only to
re-trigger the gate — and a branch re-pointed at a tree the gate had already judged — was refused
for carrying no record of a change it did not make.

The remedy a hand reached for was to write a note about nothing, or to push with
`YMIR_SKIP_FIXES_GUARD=1`. Both are the precedent this house has paid for twice: a gate that must be
routinely overridden is a gate nobody trusts.

## The mend

Before asking for a note, the guard asks what the range CHANGES. Every non-merge commit in the range
is inspected; when none of them changes a file, the range is a re-gate:

```
fixes-guard[1]{gate,result}:
  "push","ok — an empty range carries no change to record (a re-gate, 2026-11-16)"
```

A range that does change a file and carries no note is refused exactly as before, and the refusal
still names the `fixes.sh record` command that writes one.

## The proof

`bin/gates/tests/test_fixes_regate.sh` plants a real git range for each case, in a throwaway repo,
and is run by CI (`bin/gates/checks.d/0494-fixes-regate.sh`):

- an empty re-gate passes and says why;
- a real change with no note is still refused;
- a correct note answers the change.

Run it: `bash bin/gates/tests/test_fixes_regate.sh`.
