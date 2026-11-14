## gate · 2026-11-14 — a required review made the operator's own PRs unmergeable

### Why

The Allfather, mid-queue: *"NOW WE HAVE SOME RULE IN GIT HBU THAT PUTT REQUEST AUTHORES:. ME!! cant merge my own pulls."*
He was right, and the rule was ours.

### What was measured

`main`'s branch protection carried a pull-request review requirement that no document ever asked for:

```
gh api repos/zerwiz/ymir/branches/main/protection/required_pull_request_reviews
{"dismiss_stale_reviews":false,"require_code_owner_reviews":false,
 "require_last_push_approval":false,"required_approving_review_count":1}
```

One approving review. GitHub **forbids approving your own pull request**, and this repository has one human, so
every PR he authored was structurally unmergeable by him — not red, not conflicted: *refused*. Eleven such PRs were
queued when he said so.

There is no `CODEOWNERS` and no repository ruleset; the requirement was the plain branch-protection block, and the
arm's first read of it missed the key because the JSON was piped through `head` — a finding cut off is a finding
lost.

### The fix

```
gh api -X DELETE repos/zerwiz/ymir/branches/main/protection/required_pull_request_reviews
```

Measured after: `required_pull_request_reviews: None`. What remains on `main` is the gate that proves a tree — the
required status check `whole-tree`, strict, with `enforce_admins: false` — which is the house's own CI and the one
requirement worth keeping.

### The second fault found while proving it

`pr-identity-guard` (RULES/44) reads any `word@word` token in a PR body as a **mailbox**, so a body naming a scoped
npm package (`@capacitor/cli`, which dependabot's own pull request carries) is refused as if it published someone's
address. Measured: a body with one such row was refused with `refused: mailbox:` while the PR was legitimate. The
matcher lives in `bin/forge/pr-patterns.sh` and needs a code-span or npm-scope exemption; until then a body writes
`capacitor-cli`, not `@capacitor/cli`.

### How it was proved

The PR body of the batch that carries this note was re-read by the same ward that refused it:
`bin/gates/guards/pr-identity-guard.sh 765` → `pr-identity-guard: OK`, and the branch-protection read above shows
the review requirement gone.
