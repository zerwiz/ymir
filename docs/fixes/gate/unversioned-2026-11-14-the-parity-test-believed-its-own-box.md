# gate · unversioned · 2026-11-14 — the parity test believed the box it ran on

`whole-tree` was red on `main`, and it was red in one row only: the OpenCode launcher parity
test. Thirty of thirty-one assertions passed, and the one that failed was door 2 — the shell
spawner's dry run — which printed **nothing** where the launcher's line was expected.

The gate was honest. The test was lying about its own contract.

## What the test promised, and what it actually did

`bin/gates/tests/test_opencode_launcher.sh` opens by saying it *"needs no model turn and no
opencode binary"* and that *"a machine without python3 is a clean skip"*. Door 2 then ran the
spawner like this:

```bash
dry="$(PATH="$TMP/door2bin:$PATH" BROKK_HOME="$TMP" timeout 90 \
        bin/agents/einherjar-spawn.sh parity "$ROOT" --scout --harness opencode \
        --model "$ALLOWED" --dry-run 2>/dev/null | sed -n 's/^  launch: …//p')"
```

It set `BROKK_HOME` and trusted that the rest of the environment was clean. On a developer box
it was. On a seat it was not.

## The cause, measured

This seat exports its own environment, because a seat's state and the home's config are
deliberately different places:

```text
BROKK_STATE_OVERRIDE=/home/<user>/.local/state/ymir/seats/<seat>
BROKK_CONFIG_OVERRIDE=/home/<user>/Documents/ymirhome/config
YMIR_HOME=/home/<user>/Documents/ymirhome
```

With `BROKK_HOME=$TMP` the spawner resolved **data** from the seat's state base and **config**
from the home — one house split in two — and refused, correctly and loudly, before printing
anything:

```text
error: the house is split — data and config resolve to different bases.
```

So the test's failure was not the loader, not the launcher, and not the spawner. It was an
assertion that depended on the machine it happened to run on. Unsetting `YMIR_HOME` alone is
not enough: the two `BROKK_*_OVERRIDE` names do the splitting, and the brief's first guess
named the wrong variable.

## What changed

- Door 2 now runs the spawner in a **closed environment** (`env -i` with `PATH`, `HOME`,
  `TMPDIR` and `BROKK_HOME` only), so a seat's exports cannot decide the assertion.
- It is proved **twice**: once with `YMIR_HOME` set (the case that used to fail) and once with
  it unset (the case the refusal was also blamed for). The same launcher line must come out of
  both.

## Proof

```text
$ bash bin/gates/tests/test_opencode_launcher.sh
all ok
```

Both new assertions are in that run:

```text
ok   einherjar-spawn --dry-run prints the launcher's line (opencode run --model M --auto <brief>, YMIR_HOME set)
ok   einherjar-spawn --dry-run prints the same line with YMIR_HOME unset (a seat is not a split)
```

The same command reproduces the failure on the unpatched test, which is how the missed
contract was measured rather than guessed.

## Files

- `bin/gates/tests/test_opencode_launcher.sh`

## CHANGE LOG

- 2026-11-14 — written with the mend, while making `whole-tree` green on `main`.
