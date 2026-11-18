# forge · 2026-11-16 — a tilde is a shape, not a value

## The refusal that cost the day

`bin/forge/pr-patterns.sh` refused any line carrying `~`, `/home/` or `/Users/`. The matcher judged
a pull-request body and every note written through the door, so a body that SAID

```
The scheduler ran the pinned runtime, ~75 commits behind.
```

was refused as if it had published a home directory. Two pull requests (PR #770 and PR #771) were
stopped by that, and the hands that owned them spent the morning rewriting the record of a fix to
satisfy a rule about code.

## What the rule actually says

RULES/04, in its own words: *"shape, never by value — a literal `/home/<name>/`"*. The leak is a
**value**: somebody's real account, at a place that can be reached. `~` is the shape the rule asks
for; it names nobody.

## The mend

`pr_pattern_check_line` now asks a different question. It looks for a concrete account:

- refused — `/home/<an account>/…`, `/Users/<an account>/…`;
- allowed — `~`, `~/…`, `/home/<name>/…`, `/home/example/…`, `$HOME/…`, `${HOME}/…`.

The finding names the path it found, so the hand can see which token tripped the ward:

```
refused: homepath (/home/someone): the file lives at /home/someone/x
```

## What still refuses

Every class that publishes something reachable or personal — a live address, an IPv6 address, a
tailnet host, a personal mailbox, a pane id, a credential shape — in a body, in a note, in prose and
in code alike. Also new in the same file: `pr_line_is_code`, the classifier that tells a document's
sentence from its command, so a ward can ask the question the other way round when it needs to.

## The proof

`bin/gates/tests/test_pr_identity.sh` (run by CI, `bin/gates/checks.d/0492-pr-identity.sh`) holds one
case per side of the line: a tilde in prose passes, `~/Documents/…` passes, `/home/<name>/` passes,
`$HOME/state` passes, and `/home/notaplace/x` is still refused. The door refuses five leak classes
through `pr-open.sh` in the same test.

Run it: `bash bin/gates/tests/test_pr_identity.sh`.
