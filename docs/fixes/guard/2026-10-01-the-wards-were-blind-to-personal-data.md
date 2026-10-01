# The wards were blind to personal data

**Date:** 2026-10-01
**Component:** guard (bin/private-guard.sh, bin/secret-guard.sh)
**Severity:** the first law was half-enforced; personal data reached a public remote

## What

`first_law` forbids personal **or** private data in this repo. Two wards enforced
it, and between them they covered only half the law:

| Ward | What it scanned | What it never saw |
|---|---|---|
| `bin/secret-guard.sh` | file **content** for credential values | a username, a domain — personal but not secret |
| `bin/private-guard.sh` | **paths** for private roots | the content of a public-looking file |

So identity and topology passed straight through, and `origin` is a **public**
GitHub remote. Measured on the tree: 21 tracked files carried the operator
username, the tailnet domain, personal hostnames and the fleet GPU inventory.
Tailnet IPs and credentials were absent — this was identity, not secrets, which
is precisely why a secret-scanning guard slept through it.

The same class of leak had already forced one migration: commit `cb5c2f1`
(2026-09-12) moved the `modeltesting` skill out of the repo into a galdr asset,
because the skill "had accumulated host-specific material that must never be
public."

## Root cause

The ward tested for **shape of secret**. There was no ward for **shape of
identity**. Rule 04's own text said "not a secret, a key, a name, a plan, a
schedule, a client, a credential, or a note" — the implementation honoured the
first two and dropped the rest.

A second, sharper cause: the operator-specific model knowledge was parked in a
*public* asset (`assets/local-models.md`) rather than the operator's own shelf,
where the Allfather's law says it belongs.

## Fix

- `bin/private-guard.sh` gained a **content** scan for operator identity and
  topology, matched by **shape and never by value**: a literal `/home/<name>/`,
  a `*.ts.net` tailnet host, a CGNAT `100.64/10` address.
  - The guard contains **no** operator name, domain or hostname. Writing them
    there would re-create the leak it exists to prevent.
  - Synthetic fixtures (`*.test.*`, `*/tests/*`, `*/fixtures/*`) and `.example`
    files are exempt — a test's `/home/alice` is a teaching shape, not a person.
  - Public placeholders are the blessed way to say it: `$HOME`, `$HOME_SEAT`,
    `<user>`, `<host>`, `<tailnet>`, `<gpu>`, `<seat>`, `<home>`.
- All identity/topology runes were scrubbed from the 21 tracked files.
- Rule 04 gained an appended entry stating the law; the modeltesting skill was
  restored to `$YMIR_HOME/.agents/skills/modeltesting` (the Allfather's own
  shelf, latest cut, md5 `3adf35b6`).
- `.agents/tests/private-guard-identity.test.sh` asserts the ward **fails** on a
  planted leak — a test that cannot fail on the leak is not a test (Rule 04 §4).

## Verified

- `bash bin/private-guard.sh --all` → exit 1, names the offending file and line.
- Planted-leak proof: a staged file containing `/home/realoperator/x` is
  **blocked**, exit 1.
- Post-scrub sweep for the identity class across all tracked files → **0 hits**.
- `bash bin/secret-guard.sh --all` → clean; no credential was ever present.

## Known, not fixed here

`svartalfaheim/examples/SECRETS.md` is a tracked private path and reds
`private-guard.sh --all`. It predates this work and is a public how-to whose
placement is a separate judgement; it is reported, not silently absorbed.

The **published history** of the public remote still contains the pre-scrub
commits. Removing them from history is a rewrite-and-force-push that breaks
existing clones, and it is the Allfather's explicit decision, not an agent's.

## Addendum — data comes FROM the hoard (same day, Allfather's law)

The Allfather's ruling went further than "do not leak it": the repo must not
**contain a copy of operator data in any form**, and every datum is read at run
time from `$YMIR_HOME`. The repo ships only the *craft* — the doctrine, the
`.example` **shapes** with synthetic names, and the functions that resolve the
real thing through `bin/hoard-lib.sh`.

Appended to `RULES/04-hoard.md` as a second entry the same day: the modeltesting
skill, benchmarks, VRAM ceilings and host profiles are operator data and live at
`$YMIR_HOME/.agents/skills/modeltesting`; this repo keeps the doctrine and the
readers.
