## rodd · 2026-11-19 — the window's boot names no dead variable, and the window carries its class

### Why
Once the window ran from its own home, it opened on a page that said *"The UI server did not start"*. The console said:

```
[rodd] UI SERVER FAILED — python ".../venvs/s2s/bin/python" dir ".../rodd/releases/<sha>/ui" — PIN_REFUSAL is not defined
```

Hyprland also listed the window as class `zerwiz-rodd`, while `bin/desktop/app-lib.sh`, the launcher's follow-to-desktop
watcher and the window rules all name it `ymir-rodd`.

### Cause
- **The dead names.** `src/main.js` still read `PIN_REFUSAL` and `RODD_TREE` in `whenReady`. Both were removed earlier,
  and a gather merge (`7cc1394` in the rodd history) put six lines that use them back. Every boot threw a
  `ReferenceError`, so the face never loaded. The `PIN.error` block a few lines below already refuses a missing pin.
- **The class.** `app.setName('ymir-rodd')` alone does not reach the compositor. The Wayland app id comes from the desktop
  name and the `class` switch, and Hlidskjalf sets both.
- **The test that should have caught it.** `smoke/test-boot-path.mjs` stubs Electron, but its stub had no `setName`. It
  threw on line 21 and proved nothing.

### The fix
In `zerwiz/rodd`, commit `2f6826c` on branch `eindri/e2e-rodd`:

| File | Change |
|---|---|
| `src/main.js` | The six dead lines are removed. `app.setDesktopName('ymir-rodd.desktop')` and the `class` switch are added on Linux. |
| `smoke/test-boot-path.mjs` | The stub carries `setName`, `setDesktopName` and `commandLine.appendSwitch`. |

No feature was removed: the pin refusal still stands, in the `PIN.error` block.

### Proof
- `node smoke/test-boot-path.mjs` ends `boot-path: every proof held` (8 ok). Run on the old `main.js`, it fails on
  `PIN_REFUSAL is not defined`.
- `hyprctl clients` lists `class= ymir-rodd | title= Rödd · the voice of Ymir | mapped= True`.
- `/tmp/rodd-app.log` shows `[rodd] ui server answered on port 7841`.

## CHANGE LOG

- 2026-11-19 — review-mend: added missing heading for #826
