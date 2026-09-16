# Runbook — secrets and the Hoard (Hodd)

Everything private lives in **one** place: **YMIR_HOME**
(`$HOME/Documents/Ymir` — secrets · docs · tenants · identity).
The repo tracks only the guard and README at `hodd/`.
Law: `RULES/04-hoard.md`.

## Load a secret (never inline it)

Secrets are **referenced by path**, never pasted into a tracked file.

```bash
bin/hodd.sh path                                   # the Hoard root (YMIR_HOARD)
bin/hodd.sh ls                                     # what it holds (names, not values)
bin/hodd.sh init                                   # create the layout

# set an env file's vars in YOUR shell (quoting-safe):
eval "$(bin/hodd.sh emit secrets/platform.env)"
# a tenant's env (into that tenant's work only):
eval "$(bin/hodd.sh emit tenants/<tenant>/.env)"   # or: bin/hodd.sh tenant <tenant>
```
`YMIR_HOARD` overrides the location.

## The guards

- **Outer ward** — `bin/secret-guard.sh`: blocks a commit that stages a private
  env file or an obvious secret. Install once:
  ```bash
  bin/secret-guard.sh --install     # .git/hooks/pre-commit
  bin/secret-guard.sh --all         # scan every tracked file (also runs in CI)
  ```
  Test fixtures that contain fake secret-shaped strings go in
  `.secret-guardignore`.
- **Inner ward** — `hodd/.gitignore` at the repo (tracks only the guard + README + `*.example`).
  The real data lives at `$YMIR_HOME` (committed, shareable).

## If a secret reaches a commit

Rotation first — rewriting history does not un-leak a key.

```bash
# 1) revoke the key at the provider, mint a new one, update where it lives
# 2) purge it from history:
cd ~/Ymir && git status --porcelain          # must be empty
bin/repo-scrub.sh --dry-run <paths…>
bin/repo-scrub.sh --yes <paths…>             # mirrors a backup to /tmp, rewrites
git remote add origin <url>                  # filter-repo drops origin
git push --force --all && git push --force --tags
bin/secret-guard.sh --all                    # expect CLEAN
```
Force-push rewrites the remote — any other clone must be re-cloned.

## What belongs where

| Path | Holds |
|------|-------|
| `$YMIR_HOME/secrets/` | env files, keys, tunnel tokens |
| `$YMIR_HOME/docs/` | private strategy, plans |
| `$YMIR_HOME/tenants/<t>/` | per-tenant private trees |
| `$YMIR_HOME/identity/` | company/domain cards, portfolio, project registry |
