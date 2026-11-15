# seat · unversioned · 2026-11-14 — the helm's charter came out as broken bytes

`test_rodd_arm` was red: 59 passed, 2 failed. Both failures were the same fault — the helm's
one row and its one-line digest printed the charter as

```text
planning�mail�the work in hand�dispatch on
```

instead of `planning · mail · the work in hand · dispatch on`. The arm door was right to
refuse it: a row a person reads is not a row with a replacement character in it.

## The cause, measured

`bin/seat/helm-identity.sh` joined the charter's parts with GNU `paste`:

```bash
printf '%s' "$1" | tr ',' '\n' | … | paste -sd'·' - | sed 's/·/ · /g'
```

`·` is U+00B7, **two bytes** in UTF-8. GNU `paste` reads a `-d` delimiter byte by byte and
**cycles** through the bytes, so with four parts it emitted `0xC2`, then the next part, then
`0xB7`, then `0xC2`:

```text
$ printf '%s' 'planning,mail,the-work-in-hand,dispatch-on' | tr ',' '\n' \
    | sed 's/-/ /g' | paste -sd'·' - | od -c | head -2
0000000   p l a n n i n g 302 m a i l 267 t h e   w o r k   i n …
```

The `sed` that was meant to space the middots could never match, because no complete `·`
existed in the stream. Nothing about this was locale-specific enough to see by eye — it
printed roughly right in a terminal and broke every exact assertion on the row.

## What changed

The join is done in `awk`, which works in characters:

```bash
printf '%s' "$1" | tr ',' '\n' | sed 's/-/ /g; s/^ *//; s/ *$//' | grep -v '^$' \
  | awk '{ out = (out == "" ? $0 : out " · " $0) } END { printf "%s", out }'
```

The two failing assertions were **not** loosened: they still demand the exact middot row and the
exact digest sentence. They now receive what the door always meant to print.

## Proof

```text
$ bash bin/voice/tests/test_rodd_arm.sh
test_rodd_arm: 61 passed, 0 failed
```

The two assertions that were red are in that run:

```text
ok   who carries planning · mail · the work in hand · dispatch on
ok   the digest line reads as one sentence
```

## Files

- `bin/seat/helm-identity.sh`

## CHANGE LOG

- 2026-11-14 — written with the mend, while making `whole-tree` green on `main`.
