# gate · unversioned · 2026-11-14 — a variable is the design, a resolved path is the leak

Plan 293 part 8. `bin/gates/guards/private-guard.py` read **every** `$YMIR_HOME/...` mention in a
public document as a *private hoard path*. That is Rule 07's own shape — one variable, one documented
default — and 277 tracked files carry it, because it is how every page in this repository says where
a thing lives. The helm's audit of 36 panes on 2026-11-14 measured it as a false signal on correct
code, and the runbook's own note was blunt: *it is the wrong ward for repository code*.

## Why

A ward that refuses the design is a ward the house routes around. Worse, this one hid the real
question: what actually leaks is not the variable, it is the **resolved** path — an expanded home
directory, a `~/` path, a **real realm's name** on the private shelf — and a real name the operator
declared.

## What changed

Three changes, each narrower than the last, and none of them a loosening of what "leak" means:

- **`$YMIR_HOME` left the pattern list.** A variable reference is the design; it is no longer flagged.
- **The resolved home walked in.** The guard computes the home once, through the one resolver it
  already called, and refuses any line that carries that actual path (`private hoard path
  (resolved)`). It is computed at run time and never written in the file — a guard that names the
  operator re-creates the leak (RULES/04).
- **A real realm is read, not assumed.** The bare `svartalfaheim/` alternative also left the pattern,
  because `svartalfaheim/<realm>/<project>/plans/` is how every plan page names the ledger and the
  repository ships `svartalfaheim/` itself. In its place: the realms that exist in the home are listed
  at run time, and a path naming a **real** one (`svartalfaheim/<a realm that exists>`) is refused as
  `private hoard path (a real realm)`.

Everything else is untouched: an absolute path, a `~/…` path, a bare `hodd/…` shelf, a vault filename,
a secret shape, and any name declared in the home's `confidential.yaml` are refused exactly as before.

## Files

- `bin/gates/guards/private-guard.py`
- `.agents/tests/private-guard-variable.test.sh`
- `bin/gates/ci-verify.sh`

## Verified

`.agents/tests/private-guard-variable.test.sh` — 9/9, and it can fail on the leak: it plants an
invented home (its own `confidential.yaml` with an invented marker, and an invented realm directory)
and proves

- the variable form passes — `$YMIR_HOME/hodd/docs/INDEX.md`, `$YMIR_HOME/svartalfaheim/<realm>/…`,
  and a bare `$YMIR_HOME`;
- the resolved home is refused, `~/Documents/…` is refused, a home-declared name is refused, a secret
  shape is refused;
- a resolved path beside a variable still refuses, so the variable never shields a leak;
- a **real** realm on the shelf is refused while the shaped shelf and the repository's own
  `svartalfaheim/examples/` pass.

Measured on the tree the same day: `docs/features/approvals.md` and every other `$YMIR_HOME/...`
mention now reads clean, while `$YMIR_HOME/svartalfaheim/<a real realm>/projects/…` is refused.

## Owed

`.agents/tests/private-guard-identity.test.sh` is stale and red on `origin/main`: it asserts identity
rules (`identity/topology`, the tenant-doc rule) that live in `bin/gates/guards/public-guard.py` now,
and it is called by no gate. It needs an owner — either re-pointed at the public guard or retired by
a move to `hodd/reference/` (Rule 11). It was not touched here, because rewriting another ward's test
is not this errand.
