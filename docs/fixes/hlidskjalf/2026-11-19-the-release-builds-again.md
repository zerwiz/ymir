## hlidskjalf · 2026-11-19 — the release builds again (a mangled gather and a lost realm)

Plan 325 step 1, at the Allfather's word: *"send an endri. make a plan."* Hliðskjálf stays in Ymir, whole with its
gate; this note changes nothing about where it lives.

### Why

`bin/engine/release.sh build --ref main` died at `npm run build -w apps/hlidskjalf` (`tsc --noEmit && vite build`,
npm lifecycle exit 2), so the pin could not follow `main` and sat 73 commits behind it.

`tsc --noEmit` named two files, both left broken by the batch gather `36af1564b`:

- **`src/gates/Runtime.tsx`.** The gather added 147 lines and removed none: the Releases panel, the soak panel, the
  Markers panel and the raw digest were spliced in twice more, mid-JSX, so the parser met an unclosed fragment at
  line 261. The file at the gather's parent is byte-for-byte the source branch (`eindri/leak-health-view`), so the
  intended content was never in doubt.
- **`src/gates/OmniChat.tsx`.** The thread-first layout moved the realm display into the drawer's `RealmScope` and
  dropped the `realm` selector, but the input's placeholder still reads ``Command the ${realm} realm…``.

### What changed

1. `Runtime.tsx` is restored to its pre-gather content (305 lines, the soak panel included once).
2. `OmniChat.tsx` reads `realm` from the store again, for the placeholder only. The drawer still changes it.

No feature was removed: every panel `Runtime.tsx` renders is still rendered, now once.

### Proof

- `npx tsc --noEmit` in `apps/hlidskjalf` exits 0 (was 15 errors in `Runtime.tsx`, then 1 in `OmniChat.tsx`).
- `npm run build -w apps/hlidskjalf` ends `✓ built in 5.82s`.

### Owed

The gather that produced the triplicate passed its own gate, so its merge step can splice a file without a type
check catching it. A type check of every touched app inside the gather is the guard that would have refused it.
