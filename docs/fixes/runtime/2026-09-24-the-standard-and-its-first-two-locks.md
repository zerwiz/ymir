## runtime · unversioned · 2026-09-24 — the standard, and its first two locks

### Why
Two classes of failure produced most of the mess in this tree, and both recur because nothing
refuses them:

- **a runtime writing into its own source tree** (`node_modules`, `apps/*/dist`, `.run`,
  `state`), which is why a checkout is never clean and why a `git reset` can take a running
  system with it;
- **a script carrying its own idea of where the home is.** Nine were fixed by hand, and a
  tenth was found a week later by reading. Hand-convergence does not hold.

Doctrine without a lock is what allowed both. `STANDARD.md` states the rule this pair exists to
enforce: **a rule without a lock is a wish.**

### What
- **`STANDARD.md`** — the purpose, five clauses each bound to a command that can falsify it,
  the two modes a checkout can be in, the acceptance test a stranger applies, and an explicit
  list of what we do not claim. Two clauses are named as debts; one is marked not provable by
  us, because only a buyer can close it.
- **`bin/runtime-guard.sh`** — *the tree is not a runtime.* Declared means ignored, tracked, or
  named in `RUNTIME-GUARD.allow`. It also carries `snapshot` and `verify`, which cover the other
  half: run the stack, then prove the tree did not move.
- **`bin/defaults-guard.sh`** — *one place knows where things live.* It reads code, not prose,
  so a runbook may quote a path and an executable may not guess one. One allowlist (the
  resolver), and a waiver written on the line it applies to.
- **`RUNTIME-GUARD.allow`** — the declaration mechanism, and it was created by lock 1's first
  real finding rather than designed in advance.

### The finding that made the mechanism
Lock 1 fired on `apps/smidja-factory/apps/visualizer/dist/`, and the repository's own
`.gitignore` explains why it is there: the visualizer's built UI must **ship in the npm
package**, npm honours `.gitignore` when there is no `.npmignore`, and the blanket `dist/` rule
had dropped the whole interface from the tarball. So the path was **deliberately un-ignored**:
neither ignored nor tracked, a third state the ward's two-state model did not cover.

The honest fix is not to widen the ward's silence but to make the exception **written and
reviewable**, so an undeclared artifact stays a fault and a declared one is a decision. The
better remedy is recorded in that file as a debt: an `.npmignore` or a `files` field is the
mechanism designed for this, and when it lands, the un-ignore disappears from `.gitignore` and
the declaration line is deleted.

### Verified
- **lock 1: green with the declaration, and it fires without it** (`RUNTIME_GUARD_ALLOW=/dev/null`
  reproduces the finding). A lock that cannot fail is theatre.
- **lock 3: fires on 48 sites today.** The convergence is the next change, and the gate is
  deliberately **not** wired into pre-push until it is green, because a gate over a failing tree
  blocks the whole team rather than teaching it.
- Both wards pass `bash -n`.

### Files
- `STANDARD.md`
- `RUNTIME-GUARD.allow`
- `bin/defaults-guard.sh`
- `bin/runtime-guard.sh`
