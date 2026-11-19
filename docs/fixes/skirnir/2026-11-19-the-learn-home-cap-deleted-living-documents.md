# The learn-home cap deleted copies of living documents

**2026-11-19.** Found while unblocking the private home, which could not be committed because 74
tracked files had vanished from its working tree.

## What happened

`systems/skirnir/services/learn-home.sh` copies every document of the home into the assistant's
`approved/` shelf, one file per document. The copy loop read

```python
for path in sorted(docs)[:400]:
    doc_fact(path)
```

and the retire pass immediately below deletes every `home-*.md` copy whose document this pass did not
produce. So the 401st document — and every one after it, in sorted order — had its copy **deleted on
every run**, and the deletion was indistinguishable from a document that had genuinely gone away.

Measured: 74 copies of living documents (all sorting late, under `hodd/docs/audits`, `hodd/docs/collaboration`
and the shelves after them) were missing from the home's tree while every source document still existed.
A `git status` in the home therefore showed 74 deletions, and any commit was refused as a delete.

## What changed

1. **The cap is gone.** Every document is produced: `for path in sorted(docs):`.
2. **A copy dies only when its source does.** Each copy carries `source:` in its front matter, so the
   retire pass now skips any copy whose source document still exists in the home. A future cap, filter
   or partial run can no longer delete the record of a living document.

## What proves it

- `bash -n` clean.
- A dry run over a home whose document count exceeds 400 writes a copy for every one of them and removes
  none.
- With a document deliberately deleted, its copy is still retired — the pass keeps its purpose.

## What this cost

The private home stood unable to commit for a day: the deletion wall refused every push, and a plan the
Allfather had paid for could not be shipped until the copies were restored from git.
