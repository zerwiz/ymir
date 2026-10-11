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
bin/desktop/sessrumnir.sh                 # launch (deps installed on first run)
bin/desktop/sessrumnir.sh start ~/project # launch with a workspace
bin/desktop/sessrumnir.sh status
bin/desktop/sessrumnir.sh stop
```

The underlying ensure surface builds it:

```bash
bin/seat/sessrumnir/sessrumnir-ensure.sh   # deps + build
```

There is also a desk placement helper that puts its window on its **own numbered
desktop**:

```bash
bin/seat/sessrumnir/desktop-place.sh       # prefers an EMPTY desktop
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
| It opens on the wrong desktop | `bin/seat/sessrumnir/desktop-place.sh` to place it deliberately. |
