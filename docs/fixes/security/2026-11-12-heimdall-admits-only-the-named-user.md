# security · 2026-11-12 — Heimdall admits only the GitHub user the operator names

## Files
- `bin/host/heimdall-ensure.sh`: the built-in user, the remote-owner fallback and the default download URL are removed; `ensure` refuses to arm with no named user
- `bin/host/heimdall-ssh-keys.sh`: the usage example no longer names a real account
- `tests/test_heimdall_named_user.sh`: the regression test, registered in `tests/run.sh`
- `.agents/skills/galdr-ymirsystem/assets/installation.md`: the Heimdall section, appended

## Why
Heimdall writes the keys from `github.com/<user>.keys` into `~/.ssh/authorized_keys` and refreshes them every 15
minutes. Two paths in `heimdall-ensure.sh` chose that user without the operator:

- `ensure` always ran `"$WARD_DEST" add --quiet zerwiz`, whatever user was configured;
- with no user recorded, `gh_users_of` took the owner of the checkout's `origin` remote.

On a collaborator's machine, especially one working directly on `zerwiz/ymir`, both paths gave the upstream
owner's GitHub keys SSH access, and kept them current from then on. A key added to that account, by its owner or
by anyone who gains access to it, would open every collaborator's machine. The ward script itself was also
downloaded from the raw `main` branch rather than copied from the reviewed tree.

This was found while following the home-setup runbook on a new collaborator's machine. The step was kept out of
that install, so no keys were written there.

## Fix
- **Named users only.** The user comes from `HEIMDALL_GH_USERS` or the recorded file. There is no built-in user
  and no remote inference.
- **No user, no arming.** `ensure` exits 1 with a clear message, writes no keys and installs no timer. The install
  step reports WARN, as it already did for a failed arm.
- **No silent download.** The ward is copied from `bin/host/heimdall-ssh-keys.sh` beside the ensure script. A URL
  is fetched only when `HEIMDALL_DISTRO_URL` is set on purpose.

> [!IMPORTANT]
> **Seats armed before this fix** may still hold the upstream owner's keys, and their refresh timer may still
> fetch them. Each operator should check `~/.ssh/authorized_keys` and `$XDG_CONFIG_HOME/heimdall/gh-users`, and
> remove any user that is not their own. The ward's merge only adds keys; it never removes them.

## Verified
- `bash tests/test_heimdall_named_user.sh` passes all 8 checks: with no user named, ensure refuses and writes
  nothing; there is no built-in user; there is no remote inference; and there is no default download URL.
- `bash -n bin/host/heimdall-ensure.sh` passes.

## CHANGE LOG

- **2026-11-12** — note written with the fix.
