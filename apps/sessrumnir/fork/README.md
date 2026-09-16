# The fork delta — how Sessrúmnir stays a fork without dying on update

Sessrúmnir is a vendored, re-themed fork of **pi-desktop**
(`github.com/zerwiz/pi-desktop`, the Allfather's own fork of
`FaqFirebase/pi-desktop`). The whole fork lives under `apps/sessrumnir/`
and is one commit inside the Ymir tree. Because it is vendored, a naive
copy of a new upstream release would wipe the Ymir delta — branding, the
web-shell, the hall clothes. This directory is the system that prevents
that.

## The three pieces

```
fork/owned.json   — the Ymir-owned files (added by us, never touched by a sync)
fork/mods.patch   — the delta: upstream-tree → our-tree diffs (branding etc.)
fork/PIN          — the upstream commit currently vendored
../bin/sessrumnir-sync.sh — the one command that rebases a new upstream in
```

- `owned.json` lists the files Ymir adds to the fork. A sync never
  overwrites them and never deletes them.
- `mods.patch` is the diff from the pristine upstream tree at PIN to the
  branded Ymir tree. It is regenerated after every successful sync so it
  always records the current delta against the newest pinned upstream.
- `PIN` holds the upstream commit hash + version the tree currently tracks.

## The sync (bin/sessrumnir-sync.sh <tag-or-commit>)

The script is the law's hand, and it does a **true 3-way fork-rebase**, not
a clobber:

```
base   = pristine upstream tree at PIN         (what the fork was cut from)
ours   = the branded fork as it sits now       (base + Ymir delta)
theirs = pristine upstream tree at <ref>       (the incoming release)
```

git merges `base←ours` with `base←theirs`. What falls out:

- upstream-only changes land cleanly;
- our branding survives wherever upstream did not touch the same line;
- where both sides edited the same line → a **conflict marker** in the
  working tree. Brokk resolves those by hand — the sync never guesses.

The command it replaces is what broke the seat today: copy-the-whole-tree.
That is forbidden under this system — every update to the fork runs through
the rebase.

## What the delta carries (the re-theme)

The fork's delta is branding + the Ymir web-shell:

- `app.setName('Sessrúmnir')`, `org.ymir.sessrumnir`, data dir `sessrumnir`
- `src/shared/product-name.ts`, `src/main/app-data-paths.ts`
- `src/renderer/index.html`, `src/shared/theme`, default settings, i18n keys
- theme registration for `sessrumnir` (the seat's default) and `fensalir`
- tray: sign-in / sign-out of Ymir, the hall switcher, the effigies
- the web-shell: `src/web-server.ts`, `src/shared/bridge.ts`,
  `src/shared/bridge-http.ts`, `src/main/settings-logic.ts`,
  `bin/sessrumnir-web.sh`
- the dark cloth: `src/renderer/src/index.css` `@theme`, the marks, the hall
- package.json identity: `sessrumnir` name, `org.ymir.sessrumnir` appId,
  Sessrumnir artifact names

Upstream files we do NOT touch: license, code logic, RPC, IPC contracts,
the engine integrations. The delta is a thin painted layer over a living
engine.

## Pinning

`PIN` lists the vendored upstream commit and its version string. After a
sync, `PIN` is rewritten so a future operator (or Brokk) knows the germ.
The upstream commit that fixed a build is never guessed — it is read from
`PIN` or passed as the argument.