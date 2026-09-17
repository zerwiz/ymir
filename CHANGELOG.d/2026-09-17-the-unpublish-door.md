## 2026-09-17 — the house gains an unpublish door

- **`bin/npm-publish.sh --unpublish @scope/name@<version>`.** Publishing had a
  door in this house and unpublishing had none, so the act was done by hand on a
  machine whose `~/.npmrc` holds a stale token — the very reason the door exists.
  The new mode resolves the token from the hoard exactly as publishing does,
  demands a spec that names the version (a whole package is not a one-word act),
  supports `--dry-run`, and says plainly that the registry's CDN may serve the
  tarball for a while after the removal.
- **The window is 72 hours.** npm allows one version back within 72 hours of its
  publication; past that only npm support can remove it. The help text says so,
  because a door that does not name its own clock invites a late knock.
- **`@zerwiz/ymir@0.1.5` was unpublished** — the version that carried the memory
  well. Publishing the clean 0.1.7 moves the `latest` tag off the tainted build at
  once, which is the half of the repair that does not wait for propagation.
