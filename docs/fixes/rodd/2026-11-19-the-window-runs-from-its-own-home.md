## rodd · 2026-11-19 — the installed window runs from its own home, not from the pin's old copy

### Why
The first install of Rödd into the apps home (`bin/apps/apps.sh install rodd`, release `0d049293d58f`) raised a window,
but not the installed one. The unit's journal said so in one line:

```
start.sh: handing over to the pin    /home/<user>/ymir-runtime/apps/rodd/start.sh
```

### Cause
The split note (`2026-11-19-the-voice-window-leaves-for-its-own-repo.md`) says `start.sh` hands over to the pin only when
the window sits in a Ymir tree. That held for the first block of `start.sh`, but its later **step 0** still asked the pin
for `apps/rodd/start.sh` on every start.

- A pin cut **before** the split still carries the old in-tree copy, so the start was handed to it. The installed release
  never ran.
- A pin cut **after** the split carries no `apps/rodd`, so the start would refuse outright: *"the pin … carries no
  apps/rodd"*.

### The fix
In `zerwiz/rodd`, commit `56382b4` on branch `eindri/e2e-rodd`, file `start.sh`. When the window is outside a Ymir tree,
step 0 takes the pin only as the Ymir that gives her a voice: the door, the head and the toolbox. It falls back to the Ymir
that `scripts/ymir-root.sh` found. It never hands the window away. A window inside a Ymir tree keeps the old road unchanged.

### Proof
After the fix, the same launcher (`~/.local/bin/ymir-app rodd`, exit 0) printed:

```
start.sh: code root (Ymir, the voice)   /home/<user>/ymir-runtime
start.sh: window (her own home)         /home/<user>/.local/share/ymir-apps/rodd/current
```

The running Electron's command line named `~/.local/share/ymir-apps/rodd/releases/<sha>/node_modules/electron/dist/electron`.

> [!IMPORTANT]
> The fix lives in `zerwiz/rodd` on branch `eindri/e2e-rodd` (in the apps home's clone), not yet pushed. The apps home
> on this machine runs a release built from that branch by hand. The next `apps.sh update rodd` flips back to
> `origin/main` and brings the fault back until the branch is merged there.
