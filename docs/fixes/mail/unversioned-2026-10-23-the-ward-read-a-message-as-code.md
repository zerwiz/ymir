## mail · unversioned · 2026-10-23 — the defaults ward read a printf as code

### Why

`bin/gates/guards/defaults-guard.sh` refuses a file that uses `$YMIR_HOME` without resolving it through
`bin/vault/hoard-lib.sh` (Rule 07: never restate where things live). It strips `#` comments before
reading, but **not string literals**, so this line — a sentence printed for the operator — failed the
ward:

```bash
printf '  token in $YMIR_HOME/hodd/state/gna-desk.token · a reboot raises it again\n'
```

Measured 2026-10-23, on `main` as merged by PR #409 (Gná's mail desk): `bin/mail/install.sh` was the
single finding, and it blocked every push from the seat that runs the ward locally — a *message* was
treated as a *path*.

**The mend here is the message** (say "inside the home" in words), because a ward is not silently
overridden. The ward's own over-breadth is named rather than exploited: reading a quoted string as code
is a false positive, and the correct long-term fix is in the ward (strip single/double-quoted spans
before matching), not in the message.

### Files
- `bin/mail/install.sh` (one printed line)
- `docs/fixes/mail/unversioned-2026-10-23-the-ward-read-a-message-as-code.md`

### Verified
```
bin/gates/guards/defaults-guard.sh check   → "none" (0 defaults, 0 unresolved)
bin/gates/guards.sh                        → 16/16 PASS
```
