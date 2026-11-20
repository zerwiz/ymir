# The release could not be proved, because a version probe tried to start a browser

**Date:** 2026-11-20 · **Component:** engine (`bin/engine/release.sh`) and desktop (`bin/desktop/electron-lib.sh`) ·
**Errand:** `electron-probe-headless`

## What was wrong

The first release built on this machine under the adopted road stopped at the proof:

```
bin/desktop/electron-lib.sh: line 208: 862629 Trace/breakpoint trap   (core dumped)
+ exit 14
```

Run by hand, the binary says exactly why:

```
[...:FATAL:sandbox/linux/suid/client/setuid_sandbox_host.cc:166] The SUID sandbox helper binary was found, but is
not configured correctly. Rather than run without sandboxing I'm aborting now. You need to make sure that
…/node_modules/electron/dist/chrome-sandbox is owned by root and has mode 4755.
```

That condition can **never** hold in a per-user npm install: `chrome-sandbox` belongs to the user, not to root. So
the release's proof was asking a GUI browser to start, on a headless box, in order to learn a version number — and
failing every time, which means the release road could never complete here.

## What was built

A probe is not a browser.

| file | change |
|---|---|
| `bin/engine/release.sh` | the version is read from the **`dist/version` file the package ships**; only where no such file exists does it run the binary, and then with `ELECTRON_DISABLE_SANDBOX=1 … --no-sandbox`, which is what a version probe is. The `node-pty` load check gets the same flag |
| `bin/desktop/electron-lib.sh` | the health probe (`electron --version`) asks the same way, for the same reason |

Nothing about how the app RUNS changes: a desktop launch still uses the sandbox when the machine can provide one.

## The proof

```
$ cat …/node_modules/electron/dist/version
43.8.9
$ ELECTRON_DISABLE_SANDBOX=1 …/electron --version --no-sandbox
v43.8.9
```

Both roads answer the same version; the file needs no execution at all, and the flag makes the second safe on a
machine where the sandbox helper cannot be root-owned.

## What this does not decide

- **Whether this box could ever run a sandboxed Electron.** It cannot, for a per-user install; a system-wide
  install with a root-owned `chrome-sandbox` could. The probe no longer cares, which is the point.
- **Whether the release builds after this.** The build had to be re-run after the fix landed; that is the next step,
  and this note does not claim it.

## CHANGE LOG

- 2026-11-20 — written when the first adopted release could not be proved.
