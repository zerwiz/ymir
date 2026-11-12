# A direct-PR smith opens its own PR, an empty URL is a failure, and a batch is never squashed

Three faults found on 2026-11-12 in the roads a worker's work travels out by.

## The smith could not open its PR

The smith `gh` shim refused `gh pr create` in every mode, so each errand ended with the helm opening its PR by hand.

- `bin/forge/smith-gh` (and its copy `bin/forge/smith-bin/gh`) now allows `pr create` when `YMIR_SMITH_PR=direct` is set.
- `bin/agents/einherjar-spawn.sh` sets that variable only for a `direct-PR` ship errand. Merge, close, reopen, repo delete and releases stay refused in every mode.

## A blank URL was recorded as "shipped"

`bin/forge/pr-open.sh` ignored the exit of `gh pr create` and printed whatever came back, so `bin/forge/gather.sh` wrote `done: shipped in PR ` with nothing after it.

- `pr-open.sh` now fails, with a message, when `gh` fails or prints no pull-request URL.
- `gather.sh` refuses to mark any errand shipped unless it received a real `/pull/<n>` URL.

## PR #688 was a batch, and was squashed by the button

- The gather PR title already starts `gather:`. Its body now opens with `MERGE WITH A MERGE COMMIT`, and `pr-open.sh` keeps that line first, above the signature.
- `bin/forge/merge-method.sh` also recognises a batch by that title or banner, and gains `refuse_squash_of_gather`.
- `bin/forge/ship.sh`, `bin/forge/queue-warden.sh` and `bin/agents/pr-seal.sh` call it on the flag they are about to pass, so a squash of a gathered batch is refused by name.

Tests: `bin/gates/tests/test_smith_pr_open.sh` and `bin/gates/tests/test_merge_method.sh`.

> [!NOTE]
> GitHub's own merge button cannot be refused from here. The banner and the title are what the person pressing it sees.
