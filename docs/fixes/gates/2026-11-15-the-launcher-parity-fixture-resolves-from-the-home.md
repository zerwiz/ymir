# Fix — the launcher parity fixture wrote its brief where the spawner no longer looks

**What was wrong.** `bin/gates/tests/test_opencode_launcher.sh` went red on the tree that made the house resolve from
one base. Two rows failed, both of them door 2 (`einherjar-spawn.sh --dry-run`):

```
FAIL einherjar-spawn --dry-run prints the launcher's line (… , YMIR_HOME set)
       want: opencode run --model opencode-go/deepseek-v4.1-flash --auto "$(cat .../brief.md)"
       got:
```

The fixture wrote its brief to `$BROKK_HOME/data/parity/brief.md`, which is where the spawner looked **before** it
resolved `DATA` through the one resolver. The spawner now asks `bin/vault/hoard-lib.sh`, so `DATA` is
`<home>/hodd/data`, and the dry run refused before printing anything: `no brief at <home>/hodd/data/parity/brief.md`.

**What was done.** The fixture now stands up its own home inside the temporary tree (`$TMP/Documents/ymirhome`), writes
the brief to that home's `hodd/data/parity/`, and runs both dry runs with `HOME="$TMP"` — so the home the resolver names
is the fixture's own, with `YMIR_HOME` set and unset alike. The expectation line is built from the same path.

**Proof.**

```
$ bash bin/gates/tests/test_opencode_launcher.sh
ok   einherjar-spawn --dry-run prints the launcher's line (… YMIR_HOME set)
ok   einherjar-spawn --dry-run prints the same line with YMIR_HOME unset (a seat is not a split)
19 ok, 0 failed, rc=0
```

The test still needs no opencode binary and no model turn; the stub on `PATH` is unchanged.
