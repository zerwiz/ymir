# The pin refresher merged inside a proved release

**Date:** 2026-11-20 · **Component:** engine (`bin/engine/pin-refresh.sh`, `bin/engine/release.sh`,
`bin/gates/tests/test_pin_refresh.sh`) · **Errand:** `open-ends`

## What was wrong

On the dev machine the pin linked to `releases/abefc4f06932`, and that folder carried `149f38ebd`. Its reflog says
how: `merge origin/main: Fast-forward`. The helm's session start runs `pin-refresh.sh`, and the door fast-forwarded
the pin as if it were a checkout. A release is a proved copy named for its sha; the seat ran code its proof never
saw, and every reader of the folder name was told the wrong version.

## What was built

- **`pin-refresh.sh`:** when the pin is a link (a release), an apply that would move it is refused with exit **6**
  and the road named: Gróa's `runtime-deploy.sh` builds a new release of `origin/<branch>` and flips it. A release
  whose code is not the sha it is named for is reported as `moved-in-place` (exit 3 on a check, 6 on an apply).
  A working-tree pin is moved exactly as before.
- **`release.sh`:** the shared links and the release's own stamps are written to the release's `.git/info/exclude`,
  so `git status` in a release is empty and no reader mistakes them for hand edits.

## Proof

`bash bin/gates/tests/test_pin_refresh.sh` — 27 pass (three new: the refusal, the release left on its sha, and
`moved-in-place`). Live: `pin: moved-in-place — release abefc4f06932 carries 149f38ebd294 …`, rc 3.
