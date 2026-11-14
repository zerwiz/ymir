## gate · unversioned · 2026-11-14 — the Scorecard action has no v2 tag, so its first run on main failed in a second

### Why
run 43554892680 on main (2026-11-14) died at 'Set up job': 'Unable to resolve action ossf/scorecard-action@v2, unable to find version v2'. The action publishes full versions (v2.5.0 = fa7117db) and no floating major tag, so the pin was wrong, not the workflow. Pinning the tag's commit sha fixes it and earns the Scorecard's own Pinned-Dependencies check at the same time.

### Files
- `.github/workflows/scorecard.yml`
- `docs/fixes/gate/unversioned-the-scorecard-action-has-no-v2-tag.md`
### What
`.github/workflows/scorecard.yml` pins `ossf/scorecard-action` to the commit sha of its `v2.5.0` tag
(`fa7117db83c52d787ae5a89f350999701505d78e`) instead of `@v2`, and the comment beside it says why, with the run id.

### Verified
The tag list read from the API: the action publishes `v2.5.0` … `v2.3.2` and no `v2` (matching-refs for `tags/v2`
returns only full versions). `gh api repos/ossf/scorecard-action/git/matching-refs/tags/v2` returns only full versions (`v2.5.0`, `v2.4.4`,
`v2.4.3`, …) — no `v2` — which is what run 43554892680 hit. The other three actions in the file keep their
floating major tags; each was checked the same way and resolves (`actions/checkout` → `v4`,
`actions/upload-artifact` → `v4`, `github/codeql-action` → `v3`).

## CHANGE LOG

- 2026-11-13 — review-mend: added missing heading for #735
