# Adding a gate to CI — add a file, never edit the driver

> **Status: live.** Since 2026-11-14 the gate list is a directory: every gate is one file under
> `bin/gates/checks.d/`, and `bin/gates/ci-verify.sh` only reads the directory and runs what it finds.

## What it is

`bin/gates/ci-verify.sh` is the one command CI runs on every pull request and on `main`. It does not
hold the gates any more. Each gate is a small file named `<NNNN>-<name>.sh` under
`bin/gates/checks.d/`, and the driver sources them in order, prints one row per gate, and exits
non-zero if any of them failed.

The reason is a queue that never drained. Before this, every branch that added a gate appended one
line to `ci-verify.sh`, so **every open pull request conflicted with every other in that one file** —
fourteen sound PRs could not merge on that alone. Two branches that each add a gate now add two
different files, and git merges them without a word.

## What you need

- The gate itself: a script that exits `0` when it holds and non-zero when it refuses, and prints
  its own finding on the way out.
- A free number under `bin/gates/checks.d/`.

## The commands

Add the gate as its own file. The number is zero-padded so that file order is number order.

```
bin/gates/checks.d/0325-gate-directory.sh
```

The file calls `gate` exactly once, with the description CI will print:

```bash
# my-gate — what it proves, in one line.
gate my-gate "a sentence saying what is proved, printed in the CI row" \
     bash "$ROOT/bin/gates/tests/test_my_gate.sh"
```

Then run it the way CI does:

```bash
bash bin/gates/ci-verify.sh          # every gate, the same suite CI runs
bash bin/gates/tests/test_gate_directory.sh   # the shape itself: merge, order, FAIL, empty list
```

A gate that can only answer in some checkouts prints its own `SKIP` row and says why — see
`bin/gates/checks.d/0170-no-delete.sh`. A gate that needs a helper puts it in a callable file the
driver already sources (see `bin/gates/checks.d/0000-lib.sh`).

## Limits

- **Never edit `ci-verify.sh` to add a gate.** A test refuses that shape: `test_gate_directory.sh`
  fails if the driver carries a gate line again, because that is the conflict coming back.
- **An empty gate directory is refused, not passed.** A driver that ran nothing would print a bare
  header and exit 0 — a false green. A missing or empty directory exits `2` and says so.
- **A gate file that cannot load is a FAIL**, never a skip: a gate that does not run must never look
  like a gate that passed.
- **Gate files are not doors.** The bin registers exclude `bin/gates/checks.d/`, so adding a gate
  rewrites no register. Do not add rows for them by hand.
- The `--fast` flag and the severity of a gate are properties of the gate file, not of the driver.

## If it does not work

- **The row order looks odd.** The driver reads the directory in C order. A file named `100-x.sh`
  sorts before `20-y.sh`: zero-pad every number to four digits.
- **`ci-verify.sh` says the gate list is unreadable.** The directory is missing or empty. Check
  `bin/gates/checks.d/` exists and holds `*.sh` files.
- **Your gate passed locally but CI is red.** Run `bash bin/gates/ci-verify.sh` in a clean checkout:
  CI judges the whole tree, and your gate may read a path only your machine has.
- **The gate never ran.** Look for a `"<file>","FAIL"` row: the driver reports a file it could not
  load by the file's own name rather than skipping it.
