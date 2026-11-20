# Security policy

## Secrets

Never commit a secret. Credentials live in the gitignored `.env.local`
(platform) or `svartalfaheim/<realm>/.env.realm` (realm); committed examples
end in `.example` and carry empty values.

`bin/secret-guard.sh` scans the staged change (installed as the `pre-commit`
hook) and every tracked file (`--all`, run in CI) for private env files and
obvious keys (`AKIA…`, `ghp_…`, `sk-…`, `xox…`, `AIza…`, private keys). A hit
blocks the commit.

**If a secret reaches a commit:** rotate it immediately — rewriting history does
not un-leak it — then purge it with `bin/repo-scrub.sh --yes`.

## Private data

The operator's world-tree is private by design: `workspace/{work,personal,
memory,companies}/` and `assets/reference/state/` are gitignored. A clone must
never inherit another operator's data. Keep it that way.

## Reporting a vulnerability

Do not open a public issue. Report privately to the maintainers (GitHub
Security Advisory on the repository), including steps to reproduce and the
affected version. We will acknowledge and coordinate a fix before disclosure.
