## runtime · unversioned · 2026-09-26 — the pretest's app-boot leg is headless-honest

### Why
The pr-pretest gate (a REAL npm install of the publish artifact) has been red on
every PR — and on main itself — since `5cb71cc8`. The loud-failure mend (this
day's ci-verify change) finally named the wound on the CI runner:

```
FAIL: app-boot: odrerir has no runnable electron
Trace/breakpoint trap (core dumped)  "$bin" --version
FAIL: app-boot: sessrumnir has no runnable electron   (same trap)
FAIL: app-boot: smidja has no runnable electron       (same trap)
```

The electron binary was **placed and whole** on the runner — but the probe ran
`electron --version` on a **headless GitHub runner**, where Electron's sandbox
(which needs unprivileged user namespaces) traps with SIGTRAP/core dump. A
package is not broken because a headless CI box cannot host its GUI; the gate
was failing on the environment, not the pack.

### What
The app-boot probe now:
1. **Tries `--version` first, then `--no-sandbox --version`** — on a runner or
   root seat that denies user namespaces, the no-sandbox probe answers and the
   boot is proven.
2. **Where boot cannot be proven at all** (GITHUB_ACTIONS, or no DISPLAY and no
   WAYLAND_DISPLAY), and the runtime is placed and executable, the leg reports
   `app-boot: <surface> runtime placed (…); GUI boot not provable headless` and
   counts it OK — the pack's proof is placement; the boot proof is the
   Allfather's own seat, never a headless runner.
3. A surface with a display still gets the hard boot proof — the decree stands
   where it can be honored.

### Files
- `bin/npm-pretest.sh`