## records · 2026-11-14 — the four registries are brought up to current main, and stop guessing the home

### Why

PR #746 (`feat/the-four-registries`) was **BEHIND** main, and its push was refused by two wards. Both faults were
the branch's own, not main's.

### The merge

`git merge origin/main` into the branch — a merge, never a rebase and never a force-push. It merged **cleanly**: no
file conflicted, so nothing was resolved and no generated register was hand-merged. The registers are derived by
their own doors (`bin/records/registry-audit.sh`, `bin/gates/registers.sh`) and were left to them.

### The ward that refused the push

`defaults-guard` named eight of the branch's own new doors, each carrying a second knowledge of where the home lives:

```
HOME_DIR="${YMIR_HOME:-$HOME/Documents/ymirhome}"
```

That is one machine's layout written into a shipped tool, and the guard is right to refuse it (RULES/07). Every file
now resolves the home through the one resolver instead, exactly as `bin/records/atlas.sh` does:

```bash
if [ -z "${YMIR_HOME:-}" ] && [ -r "$_ROOT/bin/vault/hoard-lib.sh" ]; then
  . "$_ROOT/bin/vault/hoard-lib.sh" >/dev/null 2>&1 || true
  if command -v ymir_home_root >/dev/null 2>&1; then _h=""; ymir_home_root _h; [ -n "$_h" ] && export YMIR_HOME="$_h"; fi
fi
```

A home that cannot be resolved now fails loudly (`exit 2`) instead of silently addressing `/hodd/...`.

The eight files: `bin/fleet/registry-check.sh`, `bin/records/cron-registry.sh`, `bin/records/gimle-tunnels-check.sh`,
`bin/records/registries-refresh.sh`, `bin/records/registry-audit.sh`, `bin/records/running-inventory.sh`,
`bin/records/tunnels-registry.sh`, `bin/time/nornir-job-agnostic-audit.sh`.

### How it was proved

`bash -n` is clean on all eight, and `defaults-guard.sh check <the changed paths>` now answers `"none"` on every
section. The remaining ward finding — five systemd units on this box running from a working tree — is the machine's,
not this branch's, and the guard classifies it as INHERITED.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #765
