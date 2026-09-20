## install · unversioned · 2026-09-17 — the apps leave the monorepo; installation pulls them from their own repos

### Why
- **The app split lands in the installer.** The five apps (hlidskjalf,
  hlidskjalf-mobile, odrerir, sessrumnir, smidja) now live in their own repos
  registered in the home registry (`$HOARD/identity/projects.yaml`) — the
  monorepo never tracks them, and **`step_apps`** clones or fast-forwards each
  `apps/<path>` from its registered `git{}` block (never guessing a remote,
  always reading the registry). The smithy engine (`apps/smidja`) is stamped
  from the cloned factory's `templates/smidja`, exactly as `install.py` does
  for a target repo — so a fresh clone still gets a working smithy.
- **The vendored app trees leave the index.** `apps/{hlidskjalf,
  hlidskjalf-mobile,odrerir,sessrumnir,smidja,smidja-factory}` are gitignored
  and `git rm --cached`-ed (751 files, 135k lines); `apps/README.md` stays.
  A dir present that is not a git clone is reported (`move it aside and
  re-run`) rather than silently replaced.

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/installation.md` — the
step table (`22 steps`, `24` `step_*` functions), the new `apps` row, and the
Sessrúmnir rows now say "its own repo", not "vendored".

### Files
- *(carried from the frozen CHANGELOG.md)*
