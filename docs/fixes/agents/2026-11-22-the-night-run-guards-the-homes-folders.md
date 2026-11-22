# The night run guards the home's tracked folders

**Date:** 2026-11-22 · **Component:** agents (`bin/agents/groa-agent/eir-night.sh`) · **Plan:** 350 part C

## What was wrong

At 05:41 on 2026-11-22 the home's `config/` folder was replaced by a link, `config -> .agents/config`, whose
target does not exist in the home. Every top-level home file was rewritten in place in the same second, with no
reflog entry. The house could not read its cron table or its agent settings until the arm holder restored the
folder from the home's git.

The measured times do not point at the night run on that machine, which ran from 05:19 to 05:29. Still, nothing in
the night guarded the home, so a renewal that did this would not have been seen.

## What was built

`eir-night.sh` reads the folders the home's git tracks at its top level (`git ls-tree -d HEAD`). It checks that each
is still a real folder at three points:

- after Gróa's leg;
- after every stage;
- at the end of the night.

A folder that became a link, or vanished, **fails the night**. The verdict names the folder, the stage and the
exact restore command. The ward repairs nothing itself, because the home is the operator's.

## Proof

`bash bin/agents/tests/test_renewal_night.sh` — 22 passed. These include: "a tracked home folder relinked during a
stage fails the night, named by the stage", "the verdict prints the restore, and repairs nothing itself" and "an
untouched home passes the ward".
