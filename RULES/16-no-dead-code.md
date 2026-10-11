# Rule 16 — No dead code

**Code that exists and is never reached is a claim that a feature exists.** A file nothing imports,
a shell function nothing calls, a branch that cannot run, a constant nothing reads — each one tells
the next reader that something works. It does not.

> Adopted 2026-10-10, from the same finding that produced `RULES/15` in the Treasury Demo tree.
> The two rules are deliberately identical in substance: one house, one standard.

## The law

```
dead_code[6]{kind,what_it_claims}:
  "a file with no importer","this module, component or API is used"
  "a shell function never called","this script can do this"
  "an export with no consumer","this function is used"
  "a branch that cannot be reached","this case is handled"
  "a constant nothing reads","this value matters"
  "a file named only in a doc comment","the doc describes the code"
```

**Every one is fixed the same way, and there are only two ways:**

```
resolution[2]{action,when}:
  "USE IT","the feature it belongs to is wanted. Wire it in, and prove it renders or runs."
  "DELETE IT","the feature is not wanted, or not scheduled. Remove it and what pointed at it."
```

**Keeping it "in case" is not a third option.** A file kept against a future need lies until the
day it is used — and the day it is used is the day it is finally tested, which is the worst day to
discover it was wrong.

## Why this is a rule here

This tree already forbids a placeholder that pretends to be a screen and an agent that claims a
capability it does not have. This is the same failure one layer down, and it is **harder to see**: a
doc comment is written with more confidence than a placeholder and is read by more people.

In a tree of this size the shell form is the common one. A helper defined in a `bin/` script and
called by nothing reads as working plumbing; a reader who finds it will assume something calls it.

## The two exceptions, and their cost

```
exception[2]{kind,rule}:
  "a named external consumer","an SDK, a published package, a template that is COPIED rather than imported — the line must say WHO reads it"
  "a tracked work item","the file is dead TODAY and a line names what will resolve it. Closing that work DELETES the line."
```

Neither is self-declaring. Both are written in `dead-code.allow`, and the guard rejects a line with
no reason, or one that says *later*, *maybe*, *for now*, *temporary* or *TODO*.

**A ticket line is a work queue with a date on it, not amnesty.** An entry that outlives its code is
a lie of exactly the kind this rule forbids.

## How it is enforced

`bin/gates/guards/dead-code-guard.sh`, registered in `bin/gates/guards.sh` — the one list, so it
runs wherever the tree wards run.

```
dead_code_guard[4]{shape,what_it_finds}:
  "a source file with no importer","scans apps/ packages/ tools/ src/ against an index of every import specifier in the tree"
  "a shell function never called","scans bin/ and scripts/"
  "a bad allowlist line","a reason that is a deferral, or absent"
  "a template or fixture","EXCLUDED — copied or read, never imported. A false positive is how a guard gets switched off."
```

**What it cannot see, stated so nobody assumes it does:** an export used only inside its own file; a
branch that cannot be reached; a constant nothing reads; a file reached only through a string built
at runtime. Those are dead code by the rule. The guard catches the shapes that actually occur, and a
guard that claims more than it checks is the failure this rule exists to stop.

```
related[4]{doc}:
  "bin/gates/guards/dead-code-guard.sh","the ward, and the list of what it cannot see"
  "dead-code.allow","the two kinds of exception, each with its reason"
  "RULES/14-features.md","a feature with no page is a feature nobody can use — this rule is the same discipline for code"
  "RULES/11-never-delete-only-move.md","DELETING here means removing code nothing reaches; a live artifact is still moved, never lost"
```
