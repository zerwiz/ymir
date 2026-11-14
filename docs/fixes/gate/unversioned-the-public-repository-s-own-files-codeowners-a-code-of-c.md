## gate · unversioned · 2026-11-14 — the public repository's own files: CODEOWNERS, a code of conduct, gitleaks from the home's deny list, Dependabot, and the weekly Scorecard

### Why
plan 287 §8 measured the repository against the published practice for public repositories: no CODEOWNERS, no code of conduct, no Dependabot config, no Scorecard, and secret scanning that knew the shared key shapes but none of the operator's own words. Every one of those is a file a stranger can read and every one of them was missing.

### Files
- `.gitleaks.toml`
- `CODE_OF_CONDUCT.md`
- `.github/CODEOWNERS`
- `.github/dependabot.yml`
- `.github/workflows/scorecard.yml`
- `.github/workflows/ymir-secret-scan.yml`
- `bin/gates/secret-scan.sh`
- `hodd/identity/public-deny.txt.example`
- `SECURITY.md`
- `docs/features/secret-scanning.md`
### What
The public repository grew the files the published practice asks for, and the scan that judges secrets now knows two kinds of thing instead of one.

- `CODEOWNERS` (public handles only), `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1, reporting through the repository's private vulnerability door), `.github/dependabot.yml` (weekly, npm and pip, grouped), `.github/workflows/scorecard.yml` (weekly OpenSSF Scorecard).
- `.gitleaks.toml` holds the SHARED half only: gitleaks' defaults plus a short allowlist where a secret shape is on purpose, each entry with its reason. The operator's words are never in it.
- `bin/gates/secret-scan.sh` generates the second half at run time from the home's deny list (`hodd/identity/public-deny.txt`, unioned with the ward's `hodd/security/operator-words.txt`) into `$YMIR_HOME/state/gitleaks/`, and runs the scan: `config` · `status` · `tree` · `dir` · `staged`. Kind-aware: `name:`/`domain:` judged anywhere, `host:`/`user:` only where the word is used as a host, so a figure of the lore does not bury a real finding.
- `hodd/identity/public-deny.txt.example` seats a fresh home with invented entries (RULES/42).
- `ymir-secret-scan.yml` keeps the ward job and adds a gitleaks job over the tree and the whole history with `fetch-depth: 0`, the binary pinned by version and SHA-256. `.githooks/pre-commit` adds the scan over the staged diff, shared shapes only.
- `SECURITY.md` gains a dated section: the contact, what to send, the 7/30/90-day process, the scope, and what to do about a committed secret.

### Verified
gitleaks 8.30.1: `dir` clean, and `git --log-opts=--all` clean over 4,073 commits / 126.9 MB. A seeded `AKIA…` key was caught, then clean after removal. With the home's real deny list the tree reports 415 findings in 217 files — the plan-287 §1 debt, measured again by a second tool, and left to the sweeps. The generator's config parses and its kind rules behave as documented on a seeded file. OpenSSF Scorecard baseline recorded in plan 287: 2.8 at `4f5f6b13ac8a`. Gates: `guards.sh` all PASS, `inventory.sh --check` sources clean, `features-guard` PASS, `dead-code-guard` does not name the new door, `weave-features.sh --check` weaves.
