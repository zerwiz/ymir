## install · unversioned · 2026-09-18 — the README leads with the doors that work

### Why
- **The npm page and GitHub both render `README.md`**, so a user meets it first — and
  it buried the door that always works (`npx @zerwiz/ymir`) and the PATH cure inside
  a later section. It now opens with the one-liner (install into a prefix you own, PATH
  written, setup run, door proven), names `npx` second, and answers *"ymir: command not
  found"* and the stale-install trap where they happen.
- The three doors and their honest reasons: `npx` needs no PATH at all; the one-liner
  sets it once; `npm install -g` works wherever npm's global bin is on PATH.

### Files
- *(carried from the frozen CHANGELOG.md)*
