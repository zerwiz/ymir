## install · unversioned · 2026-09-17 — a stale install cannot hide, and the one-liner cannot be stranded

### Why
- **The fault the Allfather hit:** `npm install -g @zerwiz/ymir` reported *"changed 200 packages"* and changed nothing — npm resolved a **cached `latest`**, saw the same version, and left the old build in place. The installed copy stayed 0.1.14 while the registry served 0.1.26, and nothing told the user. With 750+ downloads, that is not a detail.
- **The CLI now says when it is out of date** — once a day, on a terminal, silenced by the same `ymir config notice version off` as every other notice: *"a newer Ymir is on npm 0.1.14 → 0.1.26 · update: npm i -g @zerwiz/ymir"*.
- **The one-liner is cache-proof**: it installs `@latest` with `--prefer-online`, so a stale packument cannot strand a fresh machine.

### Files
- *(carried from the frozen CHANGELOG.md)*
