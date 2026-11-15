# forge · 2026-11-09 · The refusal wrote to a descriptor nobody opened

## What

`bin/forge/review-seat.sh` had a `refuse()` that printed to file descriptor 3:

```bash
refuse() { printf 'review-seat: REFUSED — %s\n' "$*" >&3; exit 3; }
```

Nothing in the script, and nothing in the systemd unit that runs it, ever opened fd 3. So every
refusal — the honest "herdr is not installed", "the server does not answer", "not inside herdr" —
died as a shell fault instead:

```
/home/zerwizserver/ymir-runtime/bin/forge/review-seat.sh: line 60: 3: Bad file descriptor
```

The exit status was still 3, so the *shape* of the refusal survived while its *reason* did not.
`review-seat.service` has been failing on that line every five minutes, and the log recorded the
fault instead of the cause.

## Why

fd 3 was presumably a convention from a caller that piped the refusal somewhere. No such caller
exists: `review-seat.sh` is run by a timer, by hand, and by `review-seat.sh ask`, and none of them
opens a third descriptor. A `>&3` in a script nobody pipes is an invisible dependency on a calling
convention that was never written down — the same class of fault as the stale `Host` block that
beat a correct one in `~/.ssh/config` the same night: a value inherited from a caller that is not
there.

## Proof

Old (the pinned runtime, herdr deliberately unreachable):

```
$ PATH=/usr/bin:/bin ~/ymir-runtime/bin/forge/review-seat.sh ensure
/home/zerwizserver/ymir-runtime/bin/forge/review-seat.sh: line 60: 3: Bad file descriptor
exit=3
```

New (this tree, same conditions):

```
$ PATH=/usr/bin:/bin bin/forge/review-seat.sh ensure
review-seat: REFUSED — herdr is not installed on this seat — the reviewer's seat lives in herdr
exit=3
```

`bash -n bin/forge/review-seat.sh` clean. The healthy path is unchanged: `review-seat.sh status`
still prints its seat row and exits 0, with fd 3 open or closed.

## Change log

- **2026-11-09** — written. One character: `>&3` → `>&2`.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: the fleet's always-on heart. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #758
