# The due-date watch finds the home

## What went wrong

Every run of `trello-due.sh` printed `ymir_home_root: command not found`.

`snotra-trello.py` looked for `bin/vault/hoard-lib.sh` one directory too low, under `systems/`. The load failed
in silence and the module guessed the default home.

The module's guard against putting classified words on a card also called `ymir_home_root` without a result
variable. With `YMIR_HOME` unset, that call could not succeed.

With no Trello grant, the script printed an error line and then `the trello module refused: 1`.

## What changed

- `trello-due.sh` sources `hoard-lib.sh`, resolves the home and exports `YMIR_HOME`.
- `snotra-trello.py` looks four directories up, and its guard uses the same resolver as the rest of the module.
- A missing grant now prints one row that names the remedy, with exit code 1.

The grant itself is the operator's credential. Connect the Trello MCP server to give the watch one.

## How it was proved

`tests/test_snotra_trello_due.sh` runs in a temporary home with no grant. It reports 7 passed, 0 failed, and 6
of the 7 fail on the old code. It reaches no network.

## What is still owed

- In `snotra-trello.py`, `die` is defined after the board file is read. A bad `trello.yaml` therefore ends in a
  traceback.
- `systems/snotra/tests/smoke.sh` reports 10 failures both with and without this change.
