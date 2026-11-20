# voice · unversioned · 2026-11-08 — Rödd wears the house name in the launcher

## What

The app menu listed Rödd as a bare **Rödd** while its four siblings read **Ymir · Hlidskjalf**,
**Ymir · Sessrúmnir**, **Ymir · Smíðja** and **Ymir · Óðrerir**. One house, five doors, and one of
them did not say whose it was.

- **`apps/rodd/electron/rodd.desktop.in`** — `Name=Ymir - Rödd` became `Name=Ymir · Rödd`, the same
  separator every other template uses (`apps/hlidskjalf/electron/ymir-*.desktop.in`,
  `apps/odrerir/electron/ymir-odrerir.desktop.in`,
  `apps/sessrumnir/resources/ymir-sessrumnir.desktop.in`). The entry is rendered into
  `~/.local/share/applications/` by `bin/desktop/desktop-place.sh apply` (`install_entries`), so the
  template is the one place the label lives.
- **the seat's own entry** — `~/.local/share/applications/rodd.desktop` carried `Name=Rödd` and was
  never rendered from the template (it also names `StartupWMClass=zerwiz-rodd`, while the template
  says `ymir-rodd`). The label was corrected on the seat; the window-class disagreement is recorded
  under *Not* below rather than guessed at.

## Verified

- `grep -E '^Name=' apps/rodd/electron/rodd.desktop.in` → `Name=Ymir · Rödd`, and the same grep across
  the other three templates shows the identical separator.
- `bin/desktop/desktop-place.sh plan` still renders (the template holds `__YMIR_ROOT__`, not an
  absolute path; only the label moved).
- The seat's menu shows **Ymir · Rödd** after the entry was rewritten.

## Not

- **The window class was not touched.** The installed entry says `StartupWMClass=zerwiz-rodd` and
  `bin/desktop/app-lib.sh` says `app_class rodd` → `ymir-rodd`; the template follows app-lib. One of
  the two is wrong and only a running Rödd can say which (`hyprctl clients` while its window is up).
  A launcher label change is not the place to guess a class. Measured 2026-11-08: Rödd was not
  running, so nothing was measured.

## Files

- `apps/rodd/electron/rodd.desktop.in` — `Name=Ymir · Rödd`
