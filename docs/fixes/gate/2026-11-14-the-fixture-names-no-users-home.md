## gate · 2026-11-14 — the fixture names no one's home

The gate's own `config` check (Rule 07: no hardcoded models, providers or user paths) refused this branch's first
green run: `bin/gates/tests/test_guards_inherited.sh(path)` — the test's fixture used a **real shape** of a user home
(`/home/<user>/…`) to prove that a neighbour checkout's path is not ours.

The fixture now names a neutral absolute root instead, and the test still proves the same five cases. A test that
needs a user's home to make its point is a test that cannot run on a machine that is not that user's.
