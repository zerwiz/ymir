# A borrow does not raise a departed app

**Component:** engine · **Date:** 2026-11-20

## What was wrong

`bin/engine/release.sh build` borrows the running release's `node_modules` as hard links when the lockfiles
match. Earlier the same day, the borrow learned to carry every nested `node_modules` too. It did that with
`mkdir -p`, so it recreated the parent folder whether or not the new tree still had it.

On a second machine, the running release was older than the app split and still held
`apps/sessrumnir/node_modules`. The borrow recreated `apps/sessrumnir/` in the new build. The build then saw
that folder, took Sessrúmnir to be in this tree, and failed:
`Could not read package.json: … apps/sessrumnir/package.json` (exit 16). The machine stayed on its old release.

## What changed

`borrow_closure` carries a nested `node_modules` only into a workspace folder the new tree already has. An
app that left keeps its modules in the old release and is not raised again here. The completeness check is
unchanged: a workspace the lock nests packages in must still exist in the source.

`bin/engine/tests/test_release_borrow_closure.sh` gains a case for a departed app (10 of 10 pass). Its first
case now stands the workspace folder in the new tree, as a real clone does.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #855
