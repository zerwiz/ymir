# A release borrowed only the root node_modules, so the pin could not build

**Date:** 2026-11-19 · **Component:** engine (`bin/engine/release.sh`) · **Errand:** `make-it-live`

## What was wrong

`bin/engine/release.sh build --ref main` stopped at step 15, the Hliðskjálf build:

```
src/components/Terminal.tsx(2,48): error TS2307: Cannot find module '@xterm/xterm' or its corresponding type declarations.
src/components/Terminal.tsx(136,34): error TS7006: Parameter 'd' implicitly has an 'any' type.
```

The first reading was that `@xterm/xterm` was undeclared. It was not. `apps/hlidskjalf/package.json`
declares it and the root `package-lock.json` locks it. Because its version differs from the copy the root
resolves, npm installs it **nested**, at `apps/hlidskjalf/node_modules/@xterm/xterm`.

The build saves time by borrowing the running release's modules as hard links when the lock files match.
It borrowed only `node_modules` at the root. The nested folder never reached the new release, so the
module was missing there and nowhere else. The second error follows from the first: `onData`'s callback
lost its type with the module.

## What was changed

- `lock_nested_dirs` reads the lock and names every `<workspace>/node_modules` folder that npm nests.
- The borrow hard-links each of those folders too.
- If the running release lacks one of them, the borrow is incomplete, so the build discards it and runs
  `npm ci` instead. A partial borrow never ships.

## Proof

- `bin/engine/release.sh build --ref origin/main --from ~/ymir` built and proved release `0d14a4d60b78`
  in 54 s, with `hlidskjalf` "ok" in the release proof.
- `bin/gates/tests/test_release_nested_modules.sh` checks the lock reader against an invented lock and the
  repository's own lock, and checks that the build calls it. It prints `all green`.
