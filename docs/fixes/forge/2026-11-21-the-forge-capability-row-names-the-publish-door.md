# The forge capability row names the publish door

**Component:** `forge` (`bin/forge/gjallarhorn-publish.sh`). **Date:** 2026-11-21.

## What was wrong

The woven capability index for the forge did not list the new publish door, so a search of the capabilities would
not find it.

## What was changed

The woven row for `bin/forge/gjallarhorn-publish.sh` was added by the weave step. No behaviour changed.

## How it was proved

The weave step ran from the pre-commit hook and staged the file; the test file for the door still passes.
