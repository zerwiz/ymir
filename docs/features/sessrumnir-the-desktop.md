# Sessrúmnir — the desktop seat

## What it is

**Sessrúmnir** is the desktop GUI — the seat‑hall: a native window over your workspace,
built on Electron. It is the app you open to *use* a project, rather than the control
plane (Hlidskjalf) you look at the system from.

## What you need

- Ymir installed. Its dependencies are installed + built on first run (they are never
  committed).

## Do it

```bash
bin/desktop/sessrumnir-launch.sh                 # launch (deps installed on first run)
bin/desktop/sessrumnir-launch.sh start ~/project # launch with a workspace
bin/desktop/sessrumnir-launch.sh status
bin/desktop/sessrumnir-launch.sh stop
```

The underlying ensure surface builds it:

```bash
bin/desktop/sessrumnir-ensure.sh   # deps + build
```

There is also a desk placement helper that puts its window on its **own numbered
desktop**:

```bash
bin/desktop/desktop-place.sh       # prefers an EMPTY desktop
```

## Notes and limits

- **First launch is slower** — it installs and builds its deps.
- **Own desktop.** The placement helper prefers an empty Omarchy desktop; it does not
  fight the control plane's window.
- **A clone and a package are one tree** — the app resolves through the same lib as the
  rest of Ymir.

## If it does not work

| What you see | What to do |
|---|---|
| First run hangs | It is building; let it finish, or run `sessrumnir-ensure.sh` and read the output. |
| A blank window | Rebuild: `sessrumnir-ensure.sh ensure --install`. |
| It opens on the wrong desktop | `bin/desktop/desktop-place.sh` to place it deliberately. |

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.

## 2026-11-19 — where Sessrúmnir lives now

Sessrúmnir has its own repo, `zerwiz/sessrumnir` (still a fork of pi-desktop, synced by its `scripts/sync-upstream.sh`),
and installs into its own home with `bin/apps/apps.sh install sessrumnir` (Gróa's update installs it on every dev seat
that lacks it). Paths above that start `apps/sessrumnir/` now live in that home
(`~/.local/share/ymir-apps/sessrumnir/current/`); the launcher, `ymir-app sessrumnir` and the seat wire find it there.
Its store, `~/.config/sessrumnir`, did not move.
