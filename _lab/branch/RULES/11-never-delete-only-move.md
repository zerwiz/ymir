# Rule 11 — Never delete, only move

**A file is never deleted from this repository.** Ever. Not a shell script, not a vendored
`fm-*` provenance file, not a document, not a test. When something must go, it **moves** — and the
move is recorded so the next session can learn from it.

**The Allfather, 2026-10-02:** *"we can not never ever delete a file if we don't have made that into
a new feature. And essentially we should never delete a file. If we need to delete it, we move it
into ymir home to a reference folder so we can always learn from it. And if we are porting anything,
I have been doing a lot of porting and it's always getting features lost in the porting so we can
never delete files."*

## The law

```
never_delete[5]{artifact,what_happens_instead}:
  "bin/*.sh","moves to $YMIR_HOME/hodd/reference/bin/ with a note: why it went, what replaced it"
  ".agents/backend/*.sh (the vendored fm-* runtime)","never deleted - they are the byte-comparable reference a port is checked against"
  "docs/**","moves to $YMIR_HOME/hodd/reference/docs/; the index row is annotated, never rewritten away"
  "a test","moves to the reference shelf; a test is retired only when the capability it proved is retired"
  "an asset or a rule","moves with a dated supersede note; Rule 06 still governs the record"
```

## Why it is a rule and not a preference

1. **A port loses features.** Every port in this project's history has quietly dropped something.
   If the old file can be deleted, the drop is invisible; if it cannot, the drop is a visible
   missing item — which is the only way anyone notices.
2. **The reference is the teacher.** The house has re-solved problems it had already solved, in
   shell and in plans. A moved file is a **read**, not a re-invention.
3. **Deletion is the failure mode we can see.** `bin/` holds 390 doors and the audit found features
   that exist only as code somewhere. Deleting one would have erased the only trace that it ever
   existed.

## The companion law — a port may not lose a feature

> If the new home does not cover a capability the old one had, **the port is not finished, and the
> old file stays where it is.**

The proof of a completed port is a **capability list compared**, not a successful run. The
inventory's `disposition` column is that comparison, and it must read `migrate → src/…` with the
new path **proved** before the old path moves.

## The ward (enforcement, not intention)

`bin/no-delete-guard.sh` refuses a commit or push that **deletes a tracked file**. The only way
past is an explicit, logged reason:

```sh
YMIR_ALLOW_DELETE="superseded by src/ymir_runtime/lease.py — see the fix note" git commit …
```

which the guard prints loudly and appends to `$YMIR_HOME/hodd/memory/deleted-on-purpose.log`.
**A deletion is therefore always deliberate and always visible, and never silent** — which is the
part that was missing before. The guard runs in the pre-commit and pre-push chains and in CI.

## What this rule does *not* do

It does not keep dead code alive in a build. Moving is not a licence to keep calling something
that no longer works: a moved file is **reference**, and `bin/` keeps only what a human or a cron row
must still be able to run (Rule 07's inventory measures it).
## 2026-10-21 — a clobber is a deletion too (appended)

**Measured twice in one day.** A hand-edit of the vault decrypted to nothing and the re-encrypt
replaced **90 secrets with 3** (a backup taken seconds earlier saved it). Hours later, proving a
documentation ward could fail, a fake claim was appended to `README.md` and removed with
`git checkout README.md` — which restores the **last commit, not the previous minute**, and threw
away the uncommitted corrections that had just been made.

Neither was carelessness about the target. Both were commands whose **blast radius was wider than
the thing being changed**, and this rule's subject is deletion — which uncommitted work undergoes
just as surely as a tracked file.

```
clobber_law[4]{rule,why}:
  "a command that discards uncommitted work is a DELETION of work that was never recorded","Rule 11's subject arriving through a door the rule had not named"
  "name the target: `git checkout <ref> -- <path>` on a file you have committed, or `git stash push` first","`git checkout <path>` and `git restore .` do not say what they are about to lose"
  "a destructive command in a script is WAIVED IN WRITING, or it is refused","`# clobber-ok: <why>` on the same line, on a line a person can read"
  "the same applies to the vault: never re-encrypt it by hand — `bin/vault/hodd-set.sh` carries the guards","a hand-edit has no round-trip check, and this one failed by succeeding"
```

**Enforced by `bin/gates/guards/git-clobber-guard.sh`** (in `guards.sh`): it judges the added lines
of a push — and the whole tree with `--scan` — for `checkout --`, `checkout <ref> --`, `restore`,
`reset --hard`, `clean -f`, `stash drop|clear` and `worktree remove --force`. A branch switch is
**not** a clobber and is not flagged, because a noisy ward gets disabled and then the real one gets
through. Its first run found a genuine case in `bin/desktop/sessrumnir-sync.sh`, which is now waived
in writing with the reason (it runs inside a throwaway three-way merge repo).

**The safe habit, in one line:** commit before experimenting, or revert a **hunk** with
`git diff <file> | git apply -R`; never let a command decide what to throw away.
