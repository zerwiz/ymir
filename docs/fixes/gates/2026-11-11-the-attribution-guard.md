# Fix — a push that carries AI attribution is refused

**What was wrong.** Coding harnesses add an attribution trailer to commits and a footer to pull requests by default
(`Co-Authored-By: Claude …`, "Generated with …"). Nothing in the house refused it, and RULES/53 forbids it: the work
belongs to the people and companies who deliver it, and in a client's repository the line is improper.

**What was done.** `bin/gates/guards/attribution-guard.sh` refuses an AI attribution line in the commits a push adds
(`--base origin/main`, wired into `.githooks/pre-push` after the identity guard), in one commit message (`--msg`, for a
commit-msg hook) or in any text (`--text`, for a PR body or a letter). A person named as co-author passes. Published
history is not judged and never rewritten (Rule 06).

**How it is proven.** `bin/gates/tests/test_attribution_guard.sh` runs `--self-test`: a model trailer and a "Generated
with" footer are refused; a person's co-author line and a commented-out line pass.

## CHANGE LOG

- **2026-11-11** — written with the guard, at the Allfather's word.
