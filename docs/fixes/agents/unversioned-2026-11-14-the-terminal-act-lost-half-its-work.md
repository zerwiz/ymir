# agents · unversioned · 2026-11-14 — the terminal act lost half its work to a stale branch

The whole-tree gate went red on `main` on the `everything-up` row, three checks at once, all of them in
`bin/agents/eindri-acclaim.sh`. The blame is one merge: **#718** (`d20dbbe8`, "the report speaks into the
pane") brought its branch's copy of the file in whole, and that copy predated **#695**, **#698** and
**#700**. The pane-notify tail was the only thing added; everything the earlier hands had built into the
same block was overwritten.

## What the merge dropped

| Behaviour | Why it was there |
|---|---|
| the PR-required refusal (`exit 3`) for a `direct-PR` errand's `done` line | the review spine reads the PR url out of that line; a done line without one seats no judge, silently |
| the maker ward (`maker-guard.sh`, `exit 3`) on the line | RULES/53 — the line travels into the review record, so it may not name a model or a maker |
| the Sol stamp on the status line and the shelf | a person reading a line must see WHEN; a repeated act is recognised by the stamp |
| `did not land` (`exit 1`) when the shelf is missing or empty | a report that did not land must say so, never be claimed |
| the wake-landed check (`exit 1`) | the queue line IS the wake; a wake that did not land must not be marked delivered |
| the well episode (`well_remember_finish`) | a finished errand remembers what it did, loudly if it left no episode |
| the record-as-wake cursor (`state/<id>.woke`, plan 257 H3) | the two wake roads must not fire twice for one status line |
| the absolute `$STATE/…` paths in every detail string | a message naming `state/…` (relative) does not say WHICH state dir |
| `eindri_helm_state` for `STATE` instead of the bare override | a worker's own seat override must never redirect the helm's records (plan 272, fault 1) |

## What was done

`bin/agents/eindri-acclaim.sh` is the pre-#718 body, restored from `d20dbbe8^`, with #718's own
contribution kept — the pane-notify tail and the four-column TOOL line
(`eindri-acclaim[4]{agent,kind,detail,pane}`). Nothing was removed from #718; the dropped half came back.

## Proof

`bin/seat/tests/test_everything_up.sh` — **30 passed, 0 failed** (it was 22/6 before). The three checks
that were red are the two acclaim shelf checks and the direct-PR refusal.

```text
ok   acclaim names the absolute shelf, not a relative one
ok   a report that did not land fails loudly (rc 1)
ok   and says why
ok   a direct-PR done line with no PR is refused (rc 3)
```

## Files

- `bin/agents/eindri-acclaim.sh`

## CHANGE LOG

- 2026-11-14 — written with the mend; #718's merge is the cause, the pre-#718 body is the cure.
