## hlidskjalf · unversioned · 2026-10-23 — the terminal imported three packages nobody had declared, so the SPA could not build

### Why

`bin/forge/npm/npm-pretest.sh` — the gate that packs the publish artifact and installs it for
real — failed on `fix/the-gate-parses` and on `main`. It named one app of four:

```
app-build[1]{built,skipped,failed}: "3","0","1"
    > tsc --noEmit && vite build
    src/components/Terminal.tsx(2,48): error TS2307: Cannot find module '@xterm/xterm' …
    src/components/Terminal.tsx(3,26): error TS2307: Cannot find module '@xterm/addon-fit' …
    src/components/Terminal.tsx(4,31): error TS2307: Cannot find module '@xterm/addon-web-links' …
    src/components/Terminal.tsx(136,34): error TS7006: Parameter 'd' implicitly has an 'any' type.
```

Þráðr's terminal (plan 93) imports xterm.js — the emulator VS Code uses — and **declared none
of the three packages**. It built on the seat where a prior install had hoisted them into
`node_modules`; a clean install resolves nothing, so `tsc` failed and `vite build` never ran.
That is the whole fault of this PR wearing a fourth face: **the app could not build, so it could
not start**, and the only thing that says so is the gate that builds the real artifact.

The fourth error is not a separate fault. It is the same one: with `@xterm/xterm` unresolvable,
`new XTerm(...)` is typed `any`, so `term.onData((d) => …)` had no contextual type. Declaring the
modules resolved it — nothing was annotated by hand to make the error go away.

### Files
- `apps/hlidskjalf/package.json` — `@xterm/xterm ^6.0.0`, `@xterm/addon-fit ^0.11.0`,
  `@xterm/addon-web-links ^0.12.0` (current stable train; the build is the oracle, not a guess)
- `package-lock.json`
- `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md` — Þráðr's section, so the next hand
  knows the packages are load-bearing and that `/api/terminal/status` is what the panel asks
- `docs/fixes/hlidskjalf/unversioned-2026-10-23-the-terminal-was-never-a-dependency.md`

### Verified
```
bin/desktop/app-build.sh             hlidskjalf built — dist/    (3 built, 0 skipped, 1 failed → 4 built)
bin/desktop/app-build.sh hlidskjalf  "1","0","0"                 rc=0
bin/forge/npm/npm-pretest.sh         PASS — a REAL npm install of the publish artifact
```
A dependency a component needs is declared in the component's app, in the same change, and
`app-build` — not a seat's warm `node_modules` — is what proves it.
