# npm's allowScripts named Electron versions the lock no longer installs

**Date:** 2026-11-20 · **Component:** engine (`package.json`) · **Errand:** `open-ends`

## What was wrong

The lock installs `electron@43.8.9`, and `apps/hlidskjalf` declares it. The root `package.json` `allowScripts` named
only `43.7.3` and `33.4.11`, so npm 11 skipped Electron's postinstall and the binary had to be fetched by the
house's own fallback. The heart's old checkout carried this one-line fix as a hand edit; it was saved on the branch
`eindri/heart-local-edits` and is carried here.

## What was built

`"electron@43.8.9": true` is added. The older entries stay, so an older lock still installs.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #856
