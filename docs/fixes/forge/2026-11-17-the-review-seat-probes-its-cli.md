# Fix — the review seat probes its CLI instead of assuming one shape

**What was wrong.** `review-seat.sh` started the judge with

```
herdr agent start reviewer --kind pi --pane "$pane_out" -- --model …
```

`--kind` and `--pane` are herdr 0.9 flags. This box runs 0.7.4, which has neither — so the keeper died every five
minutes with *"herdr agent start failed for pane w17:p31"*, and the heart had **no judge seat at all**. Every open PR
sat unjudged while `review-watch` asked a pane nobody sat in. Measured on the hand the same day, and again here.

**What was done.** The shape is **probed, never assumed**: if `herdr agent start --help` mentions `--kind`, the old shape
is used; otherwise the 0.7.x shape (`--cwd <clone> --no-focus -- <argv>`) is used, and the pane herdr creates is adopted
from `herdr agent list` so every later check reads the seat that really exists.

**Why this note exists at all.** This fix was installed **by hand into the pinned runtime** on the night of the 16th, to
get a judge seated — and it was never committed. The pin stood 424 commits behind main with this as an uncommitted edit,
so the next refresh refused to fast-forward over it, and the fix existed in exactly one place on one machine. It is a
branch and a PR now, because a repair that lives in a runtime tree is a repair one `git checkout` from being lost.

**Proof.** `bash -n` clean; the seat keeper reports `seat[3]{clone,pane,state}` with a live pane and finishes instead of
dying; and the probe is visible in the file as `start_shape`.
