## gate · 2026-11-14 — the CI gate list holds both halves after merging main

### Why

PR #752 (`eindri/safe-send`, plan 293 parts 5, 6 and 8) adds four gates to `bin/gates/ci-verify.sh` for the doors it
brings — `safe-send`, `herdr-editor`, `seat-find`, `private-guard-variable`. While the branch was open, main added a
fifth for plan 293 part 7 (`gather-orders-by-base`). Both edits landed in the same place in the list, so the merge
of main reported one conflict.

### The resolution — the rule the Allfather gave on 2026-11-14

Almost every conflict in this house is `bin/gates/ci-verify.sh`, because every branch edits that one file to add its
gate. So it is resolved **deterministically**, never by taste:

1. take `origin/main`'s `ci-verify.sh` **whole** (`git checkout origin/main -- bin/gates/ci-verify.sh`);
2. re-add **only this branch's own gate lines**, copied from the branch side of the conflict;
3. keep main's for everything else.

That is what this file now is: main's version untouched, with the branch's four gates appended as one block that
names itself as the branch's own. Nothing was removed, no test was dropped, and the next branch to add a gate lands
in its own block instead of fighting over the same line.

Every gate in the merged list names a file that exists in the merged tree:

```
bin/agents/tests/test_eindri_send.sh        present
bin/seat/tests/test_herdr_editor.sh          present
bin/seat/tests/test_seat_find.sh             present
.agents/tests/private-guard-variable.test.sh present
bin/gates/tests/test_gather_orders_by_base.sh present
```

### How it was proved

`bash -n bin/gates/ci-verify.sh` is clean and no conflict marker survives. The suite itself was not run: this
machine has 11 GB and the suite runs one gate at a time, so the test proof belongs to CI on the PR (the gate list
is what is being fixed here, not the tests).
