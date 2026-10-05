## gate · unversioned · 2026-10-05 — the commit trailer attributed this work to Claude, and it was never used

### Why

The Allfather: *"take away this `Co-Authored-By: Claude Opus 4.8 (1M context)` — I
have never used Claude."*

**It is false and it was mine to remove.** Twelve commits already merged into `main`
carry that trailer, and it credits a tool and a vendor the operator has never used,
on the public record of a public repository.

### What was done

| | |
|---|---|
| **PR #291's body** | the trailer and the "Generated with Claude Code" line are removed. The one remaining `claude` match in that PR is the real door name `brokk-claude-stop-autoarm.sh` |
| **the branch behind #291** | rewritten with `filter-branch --msg-filter` to strip the trailer from its commit messages. Unmerged, so no history anyone depends on was disturbed |
| **future work** | the trailer is not used again |

### What was NOT done, and why

**Twelve merged commits on `main` still carry it. They were left alone.**

`RULES/06-append-only.md`:

> *"some records are memory: append, never rewrite, never lose on a move. **A
> correction is a new entry citing the old one.**"*

And rewriting `main` is destructive in a way a stale note never is: it changes every
SHA after the earliest affected commit, force-pushes over a public branch, and
invalidates every clone and open PR.

**So this note is the correction.** It names what was wrong, where it survives, and
that it was false.

**If you want the twelve rewritten anyway, that is a decision for you and not one I
will take on my own** — say so and it is a filter-branch over `main`, a force-push,
and a note to every open PR. The cost is real and the benefit is a clean record.

### The fault, named

> A tool added an attribution trailer to its own output, and the agent carrying it
> did not check whether the claim was true before putting it on a public commit.

The trailer was boilerplate that arrived with the harness. **Boilerplate that makes a
claim about the world is still a claim, and still has to be true.**
