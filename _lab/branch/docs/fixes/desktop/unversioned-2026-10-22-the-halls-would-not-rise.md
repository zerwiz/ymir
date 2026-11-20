## desktop · unversioned · 2026-10-22 — the halls would not rise, because the buttons named a directory that was gone

### Why

The Allfather asked: *"why can't I raise any of the halls from omarchy's menu?"* Every
Ymir launcher — the four menu entries in `~/.local/share/applications` and the four
`SUPER` keys in `~/.config/hypr/ymir-launchers.lua` — named the same path:

```
/tmp/npm-pretest-GvEQAf/seat-local/node_modules/@zerwiz/ymir/scripts/electron.sh
```

`ls` on it: **No such file or directory**. An npm pretest had run
`bin/desktop/desktop-place.sh apply` from a temporary install, and the generator baked
`$ROOT` — the directory the script happened to be running from — into the user's config.
The menu still *showed* the four buttons, because a `.desktop` file is only text; every
click started `bash` on a path that no longer existed, and nothing said so.

### Two faults, one generator

1. **A temp root was baked.** `install_entries` resolved a root of its own (the `ymir`
   CLI's package, else `$ROOT`) and `write_launchers` used `$ROOT` — two answers for two
   halves of the same integration, and neither refused a temporary directory.
2. **Sessrúmnir named a file that does not exist anywhere.** The template's `Exec` was
   `bin/desktop/sessrumnir.sh`; the real launcher is `bin/desktop/sessrumnir-launch.sh`.
   That button would have been dead even with a correct root.

### The fix

One resolver, `launcher_root()`, used by **both** halves:

- it prefers `$YMIR_LAUNCHER_ROOT`, then the `ymir` CLI's package, then this checkout;
- it **refuses any path under a temp directory** (`/tmp`, `/var/tmp`, `$TMPDIR`) — a
  pretest install lives hours, a launcher years;
- it requires the files the entries actually name (`scripts/electron.sh` and
  `bin/desktop/sessrumnir-launch.sh`) — a root missing them is not a launch root;
- if nothing qualifies it **fails loudly and writes nothing**, because a silent bad entry
  is worse than a loud failure.

`desktop-place.sh status` now prints the path each button runs and whether it exists, so a
vanished root is named instead of guessed at. The template's `Exec` is corrected.

### Measured

```
before   status → 3 launchers "MISSING" at /tmp/npm-pretest-GvEQAf/… · dead buttons
temp offered  YMIR_LAUNCHER_ROOT=/tmp/npm-pretest-…  → refused, fell back to /home/heimdall/ymir
after    status → every launcher "present" at /home/heimdall/ymir
verify   desktop-verify.sh → 4/4 surfaces runnable Electron, class agreement 4/4
click    gtk-launch ymir-hlidskjalf  → window class ymir-hlidskjalf, desktop 3  ✓
         gtk-launch ymir-sessrumnir  → window class ymir-sessrumnir, desktop 9  ✓
```

The two clicks were made with `gtk-launch`, which is the same door a menu button uses.
