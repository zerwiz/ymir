# The register of doors had no reader

**Date:** 2026-11-06 · **Component:** ward · **Door:** `bin/ward/services-register.sh` (new) · `bin/ward/verdr.sh`

## What was wrong

Rule 24's first sentence is *"a door is named"*, and the register that holds the names
(`$YMIR_HOME/config/services.yaml`) was read by **nothing**. Not the audit, not a guard, not a script — measured by
grepping the whole tree:

```
$ rg -l "services\.yaml" --glob '!node_modules'
docs/features/distinct-gates.md
```

One document. So every row in the register was a claim with no reader, and the day before this note a **copied port**
put `gimle-share` and `gna-desk` on `8490`; the desk stopped serving, `systemctl --user is-active` stayed green, and
the only witness was a human asking why the mail was not arriving.

Two more gaps came out of the same measurement:

- `security-audit.sh` judges sockets and tunnels, so an **undeclared** wide bind is reported — but a **declared** one
  is never checked against what is actually listening, and a row's own lie is invisible.
- A row could carry `host: board.zerwiz.org` and say nothing about *how* that name is published. Whether a service is
  a window, a tailnet door or a tunnel was a property nothing recorded, which is how a plan ("all users do not have
  tailscale") becomes three different architectures in three heads.

## The mend

`bin/ward/services-register.sh` — the reader, shipping in the repo while the register stays in the home (Rule 26):

```
services-register.sh [check] [--measure] [--json] [--register PATH]
```

- **HIGH** — a row with no name, no class or no gate; a class outside Rule 18's six; two rows claiming one port.
- **MEDIUM** — a hosted row (a host or a port) that declares no `road`.
- **LOW, with `--measure` only** — a declared port with nothing listening. The register is the fleet's; a dev seat
  runs a handful of its rows, so measuring sockets by default would be a wall of noise instead of a finding.
- **exit 2** — the register cannot be parsed. A refusal, never a guess.

It reads YAML where `pyyaml` exists and falls back to parsing the flow mappings where it does not, so the reader is
not hostage to one library. It says `SKIP` with its reason on a role with no register (Rule 25).

`bin/ward/verdr.sh` now carries it as the seventh check, and the report says so:

```
warden[7]{check,state}:
  …
  "the register of doors","$register"
```

## Verified, this machine

```
$ bin/ward/services-register.sh check
services-register: 34 rows (yaml) — 14 finding(s), 0 high
```

All fourteen are the same honest finding: older rows declare a host and no road. They are not errors in the reader;
they are the register being brought up to the law. The five rows for the four seats (plan 208) were written with
their road on purpose.

## Owed

- The fourteen unroaded rows, mended in the register (private, no PR).
- A `--measure` run **on the heart**, where those ports actually bind, is Vörðr's first report after this lands.

## CHANGE LOG

- **2026-11-06** — Written with the mend. The register of doors (`$YMIR_HOME/config/services.yaml`) was read by
  nothing in the tree, so Rule 24's first sentence stood as prose while a copied port took the mail desk down.
  `bin/ward/services-register.sh` is the reader; Vörðr carries it as the seventh check.
