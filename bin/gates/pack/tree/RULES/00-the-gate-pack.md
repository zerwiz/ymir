# Rule 00 — nothing private here, and the gates judge every change

## What the rule says

This repository is public. It never carries a secret, a key, a person's name or mailbox, a client, a host name, a
private address or a path into someone's home. Not in a file, a comment, a fixture, a commit message or a commit's
author line.

## How it is kept

- Ymir's gate pack judges every commit (`.githooks/pre-commit`), every push (`.githooks/pre-push`) and every pull
  request (`.github/workflows/gates.yml`). All three call one door, `bin/gates/run-gates.sh`. Seat the hooks once
  in each clone with `bin/gates/install-hooks.sh`.
- The gates are Ymir's own wards, copied byte for byte, and `VENDORED` lists every copied file. A change to a gate
  is made in Ymir and seated here with Ymir's `bin/gates/pack.sh seat`, never edited in place.
  `bin/gates/vendor-sync.sh --check` proves the copies match; `--behind` says when Ymir has moved on.
- The operator's deny list (their own words, machine names and mail domains) is never in this tree and never sent to the
  hosting service. A seat's hooks read it from the operator's home. CI judges the shapes: keys, private addresses,
  personal mailboxes and a commit's identity.
- `tests/gates.test.sh` plants one fault per gate and proves each gate refuses it.

> [!IMPORTANT]
> A refused commit is fixed in the change, never by weakening a gate or passing `--no-verify`.
> A test fixture that looks like a key is declared in this repository's own `.gitleaks.toml`, with its reason.

## CHANGE LOG

- **2026-11-25** — seated with Ymir's gate pack (Ymir plan 372).
