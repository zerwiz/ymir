# A field read returned "" and four doors carried on

**Date:** 2026-11-06 · **Component:** runtime (`bin/agents/project-git.sh`) · **Found by:** plan 210 P3

## The fault, measured

`project-git.sh` is the one door to a project's `git{}` block — `host · owner · repo · remote ·
default_branch · auth`. It read that block with a single `sed` over the `git:` line, which only
matches the **inline** shape:

```
git: {host: github.com, owner: zerwiz, repo: ymir}
```

The operator's registry writes it **nested**, and has for months:

```
  git:
    host: github.com
    owner: zerwiz
```

So every field of every row came back **empty**, and the script printed an empty line and exited 0 —
success, meaning nothing. Measured against the live registry:

```
$ bin/agents/project-git.sh ymir-platform --field owner
                        ← nothing
```

Four consumers read that door: `bin/forge/mjollnir.sh`, `bin/forge/yggdrasil.sh`,
`bin/forge/github-deploy.sh`, and the new `clone`. Each of them resolves a remote from this answer.
An empty answer is not a small wrong answer; it is the door saying "this project has no repository"
about a project that does.

## The fix

`val` now reads **both shapes**: an inline `git: {…}` line, or a nested block whose keys are indented
past the `git:` line. It stops at the first line that dedents out of the block, so a neighbouring key
(`posture:`, `kind:`) can never be mistaken for a git field.

And a field that is unresolvable is now a **refusal, not a blank line**: `--field path` and
`--field clone` exit 1 and name the remedy, because the failure mode above was a caller receiving
`""` and continuing.

## Proved

```
$ for f in owner repo host default_branch remote auth; do
    printf '%-14s %s\n' "$f" "$(bin/agents/project-git.sh ymir-platform --field $f)"; done
owner          zerwiz
repo           ymir
host           github.com
default_branch main
remote         origin
auth           gh
```

`bin/gates/tests/test_mjollnir_clone.sh` builds a fixture registry in the **nested** shape and drives
the door through it — twelve proofs, no network, including "a row with no tree refuses to name one".

## Files

- `bin/agents/project-git.sh` — `val` reads both shapes; `paths` verb; `--field path|clone`; VERSION 1.4.0

## CHANGE LOG

- **2026-11-06** — written with the fix, in the same change that found it (plan 210 P3).
