# forge · 2026-11-11 · Nobody read the issues

## What

The house watches pull requests. It watched **nothing** else. So `#657` — *"main is red"*, filed by CI itself at
03:30 — sat open for fifteen hours while the same three gates were being fixed by hand in another window.

The Allfather, at six in the morning: *"are nobody reading the issues and solving them?"* The answer was no.

## Why

`review-watch` asks about PRs, `pr-watch` announces PRs, `queue-warden` settles PR conflicts. Every watcher in
the house speaks the word *pull request*. An issue is a different door: it is how the machine complains when no
PR exists yet, and nothing had ever opened that door.

## The fix

`bin/forge/issue-watch.sh` — every five minutes:

- a **new issue** → one line to the operator: number · title · labels · age;
- the **red-main issue** → run `bin/gates/ci-verify.sh`; if it is green, comment and **close** it (the issue's own
  text says a green run closes it, so this is not a guess); if it is still red, comment the first failing gate so
  the issue stays alive and names its fault;
- anything else → announced once, then left to a human, because a machine does not guess an intent;
- nothing changed → silence.

`--install-timer` seats a user timer every 5 minutes, so the issues are read without anyone remembering.

## Proof

```
$ bin/forge/issue-watch.sh --dry-run
issue #657 main is red: compliance (+2 more) — the 15 governance gates — main-red, open 15h
```

Then the timer, and one real run: the line arrived, and the green check closed the issue.

## Change log

- **2026-11-11** — written with the door, after an issue outlived its own fix.
