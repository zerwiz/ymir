## forge · unversioned · 2026-11-07 — a conflicting PR seats a smith, in the code

The Allfather, watching four PRs sit CONFLICTING for a day: *"then we need to send out an editor to
fix the conflicts … this must be in the code to happen automatically."*

He is right, and the gap was structural: plan 203 §4 forbids the reviewer from editing, so a
conflicting head is a **dead end** for the loop — it can only refuse, every ten minutes, forever. A
human noticing was the only path. That is not a loop; it is a status page.

### What changed

| file | what it does |
|---|---|
| `bin/forge/conflict-errand.md` (new) | the brief a smith is handed: fetch the branch, worktree it, **merge main in (never rebase, never force-push)**, resolve by rule — generated registers regenerated, append-only records kept on both sides, `.review-rules.yaml` restored if the branch deleted it — run the wards, commit, plain-push to the branch, and stop. The smith never opens or merges a PR |
| `bin/forge/review-watch.sh` | when a PR is `CONFLICTING` and the seat may act, it **seats the smith itself** (`herdr-run.sh eindri conflict-smith-<n>`), writes a runes entry, and marks the head so it does not re-seat every tick. The next tick finds the branch mergeable and the judge is asked as usual |

Gated exactly like the self-answer: `YMIR_REVIEW_SELF=auto` acts only on a machine whose role
contains `heart`; a dev body still only reports. One marker per head (`smithed-pr-<n>.<head>`), so a
seat that keeps failing cannot become a spawn storm.

### Proven by hand first, then wired

Three of the four branches were cleared this way before the code existed:

```
cleared[3]{branch,before,after}:
  "fix/the-door-names-its-road-and-its-register","3bb0953c CONFLICTING","8c3ab374 pushed · 28/28 wards"
  "fix/liveness-does-not-bury-the-truth","6f278ad7 CONFLICTING","c799f81b pushed · 28/28 wards"
  "yggdrasil/far-halls","9b34917e CONFLICTING","BLOCKED — features-guard: its new page needs a catalogue row (its author's choice, not a mechanic's)"
```

`#552` is on another user's **fork** (`Sebanionen:`), so no push is possible from here at all — that
is a fact about the PR, not a fault in the loop, and the brief's push step is what would fail.

### Not done

The smith dispatch uses the herdr road (`herdr-run.sh eindri`), which needs an interactive shell pane;
where herdr has none, the dispatch reports the failure rather than silently doing nothing. A one-shot
`pi -p` fallback is the obvious next step and is named, not built.

## CHANGE LOG

- 2026-11-07 · conflict errand brief + automatic dispatch from the watch, gated and marked; three
  branches cleared by hand first to prove the errand, one blocked on its author, one on a fork.
