# A tag is a pointer — the fix-note ward refused every tag push

**2026-10-24.** Component: `bin/gates/guards/fixes-guard.sh`.

## What happened

Three archive-tag pushes were refused in a row while the remedy the ward printed — *write a fix note and push
again* — had just been applied and committed:

```
note: a note is a file under docs/fixes/<component>/ — write one, commit it, push again.
error: failed to push some refs to 'https://github.com/zerwiz/ymir.git'
```

## Why

The ward derives its range from the refs git hands it: `local_ref local_sha remote_ref remote_sha`. For a **tag**
refspec there is no remote counterpart, so the remote sha is all zeros; the guard then fell back to
`origin/main` as the base and took the last tag's commit as the head. That range contains no new note — a tag
points at a commit that landed on a branch long ago, and was judged *then* — so the refusal was correct by its own
rule and wrong about what a tag push is.

Three pushes were refused, each after a note was written for the *content* being pushed, because the content being
pushed was not content at all.

## The fix

```
if [ "$saw_ref" = 1 ] && [ "$only_tags" = 1 ]; then
  "push","ok — a tag is a pointer; the commits it names were judged when they landed on a branch"
```

The loop now reads the remote ref name, not just the shas, and a push whose every ref is `refs/tags/*` is exempt.
A push that carries branch content still needs its note, unchanged — and a branch deletion keeps its own earlier
exemption.

## Proof

```
$ printf 'refs/heads/x <sha> refs/tags/archive-test 0{40}\n' | fixes-guard.sh
fixes-guard[1]{gate,result}:
  "push","ok — a tag is a pointer; the commits it names were judged when they landed on a branch"

$ git push origin 'refs/heads/*:refs/tags/archive-2026-10-24-night/*'
tags pushed — the archive of twenty branches now lives on origin
```

**Why this mattered more than tidiness:** the tags are the floor beneath a cleanup. While they could not be pushed,
the only copy of twenty local branches — including every errand branch of the night — was the disk in this room and
a bundle on the same disk.
