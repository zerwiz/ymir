# 2026-11-24 — a symlinked node_modules is declared, and the cloth page has a change log

Two pre-push wards refused the gather branch.

- `runtime-guard` named `node_modules`: a Yggdrasil worktree seats it as a symlink, and the existing
  `node_modules/` pattern only matches a directory. `.gitignore` now also carries `/node_modules`.
- `rules-compliance-guard` (RULES/06) wanted a CHANGE LOG section on the new page
  `docs/features/terminal-cloth.md`. The page now ends with one.

## CHANGE LOG

- 2026-11-24 — review-mend: added missing heading for #923
