# The watchtower counted the window it rendered, not what it had judged

**Component:** hlidskjalf · **Seat:** heimdall · **Date:** 2026-10-21

## What was wrong

`GET /api/ward` returned `"judged": 2000` over a record of **19,585** judgements. The handler read
the last 2,000 lines (a sane render window), summed the severities of that window, and then
reported the sum as the total.

A security surface that under-reports its own coverage is the most expensive kind of small lie: the
operator reads "2,000 judged", believes the hound has seen a fraction of what it has, and cannot
tell a quiet night from a broken one.

## The fix

`judged` is now the length of the whole record; `bySeverity` remains the recent window the panel
renders, and is documented as such in the handler. Verified live:

```
{"paused":false,"heartbeatAgeSeconds":1,"findings":15604,"judged":19585,
 "bySeverity":{"INFO":2000,"MEDIUM":0,"HIGH":0,"CRITICAL":0}}
```

## A second defect found in the same edit

The first attempt referenced `lines` outside the block that declares it and the endpoint answered
**500 `lines is not defined`** for a few seconds — caught because the follow-up call was made before
claiming success. The count is now carried in a variable scoped to the handler.

## What this does not fix

The hound's live record is still all `INFO`: every execution so far came from an expected directory
and every listener was on the known list. The HIGH and CRITICAL branches are proven by the unit
tests and by the rules' synthetic fixtures, **not yet by a live event** — which is the honest
coverage statement for this seat today.

## Appended — the ward caught the second guess, which is why the guard exists

The handler also resolved the hoard itself (`process.env.YMIR_HOME ?? join(HOME, 'Documents/ymirhome')`)
while the same file already resolves it once at the top (`HOME_DIR`: env → the recorded choice →
one default). `defaults-guard` refused the push with **"a home guessed"** at line 2606. It now uses
`HOME_DIR`; the push that carried the first version had already merged, so this repairs it.

Two guards caught two defects this hour — the fix-note gate first, then this one — and neither
defect was visible by reading the diff for sense.
