# The push-road probe has an identity

**Component:** gates · **Date:** 2026-11-20

## What was wrong

`bin/gates/checks/push-road.test.sh` makes several throwaway repositories: a clone of the tree, a scratch bare
remote, and two working copies for the catch-up check. A CI runner has no git identity. The first mend gave
one to the clone only, so the catch-up check's scratch commits still failed, and `gather.sh`'s `catch_up` was
judged against a remote that never moved.

## What changed

The test exports `GIT_AUTHOR_*` and `GIT_COMMITTER_*` once, as a fixture identity with a noreply address, so
every repository it makes can commit. Measured: 10 of 10 checks pass with an empty `HOME` and no system git
config, which is what a runner looks like.
