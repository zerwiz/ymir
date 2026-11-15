# Electron is found on a Mac

**Date:** 2026-11-16 · **Component:** platforms / desktop · **Found while:** launching every Ymir app on a Mac

## What went wrong

`bin/desktop/electron-lib.sh` knew only the Linux shape of the Electron runtime. It looked for `dist/electron` and
fetched `electron-v<version>-linux-x64.zip` on every OS. On a Mac the real binary is
`dist/Electron.app/Contents/MacOS/Electron`, so the resolver never found it. The fallback then unpacked a Linux build
into `dist/`, which a Mac cannot run. Every app stopped at "the Electron runtime could not be mended".

## What changed

| File | Change |
|---|---|
| `bin/desktop/electron-lib.sh` | `_electron_exe` gives the binary's path per OS; `_electron_artifact` names the release zip per OS and CPU. The resolver, the checks and both fetch roads use them. |
| `scripts/electron.sh` | The running-window probe matches any binary under `electron/dist/`, so it also finds a Mac window. |

Linux behaviour is unchanged: there both helpers still answer `electron` and `linux-<arch>`.
