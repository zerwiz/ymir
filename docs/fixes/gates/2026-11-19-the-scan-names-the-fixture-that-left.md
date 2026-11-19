# The secret scan names the fixture that left

**Date:** 2026-11-19 · **Component:** gates · **Door:** `bin/gates/secret-scan.sh tree` · **Config:** `.gitleaks.toml`

## What was wrong

The secret scan on `main` reported one finding across the history: `generic-api-key` in
`bin/gimle/mcp/test_oauth_door.py`, commit `0a60b25b1`, line 10.

That line is a test fixture JWT, not a credential. The file has since moved out of this repository to its own private
repository, so it is no longer in the tree. A history cannot be rewritten, so the finding would stay red for ever.

## What was forged

One path entry in the existing allowlist of `.gitleaks.toml`, with its reason: a test fixture, in a file that has
since moved to its own private repository; no credential. No code was copied back into this repository to satisfy
the scanner.

## Proof (measured)

The CI-equivalent run, on the shared rules alone:

```
YMIR_GITLEAKS=/tmp/gitleaks YMIR_SECRET_SCAN_CONFIG=.gitleaks.toml bin/gates/secret-scan.sh tree
before:  WRN leaks found: 1   (generic-api-key bin/gimle/mcp/test_oauth_door.py 0a60b25b1 10)
after:   INF 5028 commits scanned.  INF no leaks found   (rc=0)
```

> [!NOTE]
> The same command without `YMIR_SECRET_SCAN_CONFIG` uses the generated config that adds the operator's own deny
> list. On this seat that whole-history audit reports many older word findings. That audit is a separate ward and
> was not part of this change.
