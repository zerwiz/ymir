## install · unversioned · 2026-09-23 — the fleet door + the dotfolder self-heal

### Why
The #119 merge dropped `ymir-fleet.sh` (its push was guard-refused), and npm's
packer refuses `.agents`/`RULES` — an npm-installed essence stayed blocked.

### What
- `bin/ymir-fleet.sh` (shipped) — the user's fleet-mode door.
- `bin/essence-fetch.sh` — seats `.agents` + `RULES` from the repo when absent;
  wired into `ymir-fleet.sh ensure` so the npm world self-heals first.

### Files
- `bin/ymir-fleet.sh` · `bin/essence-fetch.sh`
