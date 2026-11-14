## time · 2026-11-14 — the agnostic-audit job fix is brought up to current main, and resolves the home

### Why

PR #741 (`fix/agnostic-audit-job`) was **BEHIND** main, and its push was refused by `defaults-guard`.

### The merge

`git merge origin/main` into the branch — a merge, never a rebase and never a force-push. It merged **cleanly**: no
file conflicted, so nothing was resolved and no cron row was reordered by hand.

### The ward that refused the push

`bin/time/nornir-job-agnostic-audit.sh` carried its own knowledge of where the home lives:

```
HOME_DIR="${YMIR_HOME:-$HOME/Documents/ymirhome}"
```

That is one machine's layout inside a shipped job, and the guard is right to refuse it (RULES/07). The job now
resolves the home through the one resolver, exactly as `bin/records/atlas.sh` does:

```bash
if [ -z "${YMIR_HOME:-}" ] && [ -r "$_ROOT/bin/vault/hoard-lib.sh" ]; then
  . "$_ROOT/bin/vault/hoard-lib.sh" >/dev/null 2>&1 || true
  if command -v ymir_home_root >/dev/null 2>&1; then _h=""; ymir_home_root _h; [ -n "$_h" ] && export YMIR_HOME="$_h"; fi
fi
```

A home that cannot be resolved now fails loudly (`exit 2`) instead of silently addressing `/hodd/...`.

### How it was proved

`bash -n` is clean, and `defaults-guard.sh check <this push's paths>` answers `"none"` on every section. The
remaining ward findings on this machine — five systemd units running from a working tree — are the box's, not this
branch's, and the guard classifies them as INHERITED.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #765
