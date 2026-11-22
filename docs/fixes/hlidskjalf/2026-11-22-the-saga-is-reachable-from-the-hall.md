# The saga was not reachable from the hall

**Date:** 2026-11-22 · **Component:** hlidskjalf (`Topbar.tsx`, `AccountMenu.tsx`, `Rail.tsx`, `MobileNav.tsx`) ·
**Errand:** `saga-link`

## What was wrong

At the operator's word: *"Dude amazing work. Can we add this also to the drop down modal. And add to more places
on the dash bord and a button to every other page also to get here. https://ymir.zerwiz.org/saga/"*

The saga (YMIR — The Lore) is served at `https://ymir.zerwiz.org/saga/` but nothing in the hall linked to it.
The operator had to know the URL and type it.

## What was built

Four places in the Hlidskjalf SPA now carry a link to the saga:

| place | file | where |
|---|---|---|
| the top bar | `Topbar.tsx` | a rune button between Ward and the accent picker — on every page |
| the account menu | `AccountMenu.tsx` | a link in the drop-down popover |
| the rail foot | `Rail.tsx` | a small link above the node status |
| the mobile "More" sheet | `MobileNav.tsx` | a cell in the gate grid |

All four open the saga in a new tab with `rel="noopener noreferrer"`.

## CHANGE LOG

- 2026-11-22 — written at the operator's word.
