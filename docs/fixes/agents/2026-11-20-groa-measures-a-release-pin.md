# Gróa held every seat's pin as "dirty (4)" — a release is measured, never merged in place

**Date:** 2026-11-20 · **Component:** agents (`bin/agents/groa-update.sh`, `bin/agents/tests/test_groa_release_pin.sh`) ·
**Errand:** `open-ends`

## What was wrong

Gróa carried the pin forward with the same guarded fast-forward she uses for a working tree. Once the pin became a
link to a release (plan 275 S9), that was wrong twice over:

- **Every seat read "dirty (4)".** A release holds four things git does not know: the links `.run`, `.a2a` and
  `.yggdrasil`, and its `.release-proved` stamp. Measured on the heart, the dev machine and a second machine the same
  evening: `"pin","…/ymir-runtime","skipped","dirty (4)"`. So no seat's pin was ever moved by Gróa.
- **Had it been clean, she would have merged inside a proved release.** A release is named for its sha and proved
  as that sha. A fast-forward inside it runs code its proof never saw, under a name that lies.

Run from the pin itself (the heart has no working tree on its schedule), row 1 made the same mistake on the home.

## What was built

- `release_pin_state <pin>` measures a release against `origin/<branch>` and never merges. Current → `current`;
  behind on a check → `behind`; behind on an apply → `rebuild`, which sets `PIN_MOVED=1`, so the existing
  `runtime-deploy.sh` step builds a new release beside it, proves it and flips.
- A release whose code is not the sha it is named for is named **moved in place**, and is rebuilt.
- Row 1 takes the same road when Gróa runs from a release (`.release-proved` or `.release-adopted` present).

## Proof

`bash bin/agents/tests/test_groa_release_pin.sh` — 8 passed; `bash bin/gates/tests/test_groa_steps.sh` — 17 passed.
Live on the dev machine: `"pin","…/ymir-runtime","behind","release abefc4f06932 carries 149f38ebd294 — moved in place; a new release is built and flipped"`.
