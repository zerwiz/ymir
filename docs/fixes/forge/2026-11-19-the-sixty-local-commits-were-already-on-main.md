# The sixty local commits were already on main

**Component:** `forge` (the delivery road: every change leaves by pull request).
**Date:** 2026-11-19. At the Allfather's word: *"make so all ymir's code are pulled and merged thru pr."*

## What was found

A dev machine's local `main` stood 60 commits ahead of `origin/main` and 688 behind. That is work merged
straight onto `main`, which the delivery law forbids. The local `main` was reset to `origin/main`, and the 60
commits were kept intact on the unpushed branch `wip/heimdall-main-2026-11-19`. The errand was to land them
through the gate as one pull request.

## What the measurement showed

Nothing is left to land. All 60 commits already reached `main`, squashed into four merges:

| Merge on `main` | Commits of the branch it carries |
|---|---|
| `e1574bcb2` (#721) | 39 |
| `edf1efb84` (#730) | 15 |
| `4f5f6b13a` (#731) | 5 |
| `98425f27c` (the Snotra thread commit) | 1 |

Each branch commit's subject appears in the body of one of those merges. The content check is stronger than
the subjects. The branch touches 170 files:

- **152** are byte-identical to `main` at `98425f27c`.
- **3** (`apps/hlidskjalf/package.json`, `bin/engine/units.py`, `package-lock.json`) match `main` at `e1574bcb2`,
  and later work on `main` moved them on.
- **15** are fix notes and feature pages. `main`'s copy holds every line of the branch's copy, plus later
  appended corrections (a CHANGE LOG, and the 2026-11-14 note that names are read as roles).

A trial merge (`git merge-tree`) of the branch onto `origin/main` gives 49 text conflicts, and about 60
modify/delete conflicts in apps that have since left for their own repositories (Bilskirnir, Rödd,
Sessrúmnir, Óðrerir). Resolving them "by intent" means taking `main`'s side every time: `main` already holds
the branch's work, plus the corrections and the app split made since. A merge would add no content. It would
only risk bringing back stale text, or the files of apps that left. So no merge was made and no commit is
owed.

## How to re-check it

```bash
W=wip/heimdall-main-2026-11-19
git cherry origin/main "$W" | wc -l               # 60 rows; the squashes change the patch ids, so this alone proves nothing
MB=$(git merge-base origin/main "$W")
for f in $(git diff --name-only "$MB" "$W"); do
  [ "$(git rev-parse -q --verify "$W:$f")" = "$(git rev-parse -q --verify 98425f27c:$f)" ] || echo "differs: $f"
done                                              # prints the 18 files named above, and no others
```

## What is left

The branch `wip/heimdall-main-2026-11-19` exists only on one disk. It is now safe to delete, because every
change in it is on `main`. Git will ask for `-D`, because squashes do not make the branch an ancestor. Deleting
it is the Allfather's call, so it has not been done.
