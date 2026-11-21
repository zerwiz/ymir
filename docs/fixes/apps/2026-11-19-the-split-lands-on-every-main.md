## apps · 2026-11-19 — the split lands on every app's main

### Why

The Allfather, 2026-11-19: *"everything in their own repos. we also need to push the new apps to their repos"*, then
*"all code get up to github mains for all repos"*.

After the split (PR #823), three of the six app repositories still had the old September head on `main`, and the
history cut from Ymir sat on `split/from-ymir`. GitHub refused a pull request between the two branches:
`The split/from-ymir branch has no history in common with main`. The registry therefore pointed those three at
`split/from-ymir`.

### What changed

- In each of the three repositories (Smíðja, Óðrerir, Sessrúmnir), a branch `split/join-main` holds one merge commit.
  Its parents are the old `main` (tagged `pre-split-2026-09`) and `split/from-ymir`. Its tree is the split's tree.
  Nothing is rewritten and nothing is force-pushed, and both histories stay reachable from `main`. That includes
  Sessrúmnir's history from the project it was forked from.
- One pull request per repository carries that commit into `main`.
- `config/app-repos.yaml` now names `main` as the default branch for all three, so all six apps read the same way.

### Order

> [!IMPORTANT]
> The registry change is correct only once the three join pull requests are merged. Until then, `main` in those
> repositories does not carry the split. Gather this change after the merges, never before.

### Proof

- Each join commit's tree equals the tree of `split/from-ymir`. Both the old `main` and `split/from-ymir` are
  ancestors of it (`git merge-base --is-ancestor`).
- None of the six repositories carries Ymir's whole tree. None has `bin/engine/`, `RULES/` or Ymir's root layout.
- Hvergelmir, Bilskirnir and Rödd already had the split on `main`, at the hashes their `moved:` rows name.

### Files

- `config/app-repos.yaml` (the default branch for three rows, and their comment)
- this note

## CHANGE LOG

- 2026-11-19 — first entry.
- 2026-11-21 — correction: the registry this change edits is `.agents/config/app-repos.yaml`, not
  `config/app-repos.yaml`. That wrong path appears twice above, under **What changed** and **Files**. Those lines
  stay as the record. The file this range touches is `.agents/config/app-repos.yaml` (the default branch for three
  rows, and their comment). The three join pull requests (Smíðja #8, Óðrerir #4, Sessrúmnir #6) are merged, so each
  `main` now carries the split, as the **Order** callout requires.
