# The public tree named a person, and every ward passed

**Component:** gate · **Seat:** heimdall · **Date:** 2026-10-21

## What was in the open

`FEATURES.md`, `docs/features/the-inbox-watcher.md` and two fix notes carried **a collaborator's full
name and two of his email addresses**. They were merged to a **public** repository in #383 and #384.

## Why no guard stopped it

- **`private-guard`** refuses absolute paths, vault references and *secret shapes*. A person's name is
  none of those.
- **Rule 26** says explicitly: *"It does not refuse a participant's name or email: those are the
  meeting's own actors."* True of a meeting record — and a public repository is **not** a meeting
  record. The rule was written for an external *artifact*, not for the store of artifacts.
- **Nothing anywhere said "a person is private data."** That is the missing sentence, and a missing
  sentence is how a gate passes.

## What now exists

**`bin/gates/guards/people-guard.sh`** — in `guards.sh`. It builds its list **from the operator's own
registries** (`collaborators.yaml`, the NDA register): every full name and every address. Any of them
appearing in the tree fails the push. A public figure quoted in research (an author, a maintainer) is
not on that list and is not flagged — the guard is not a dictionary of names, it is a comparison
against the people the house actually knows.

**Proved to fail:** a probe file containing a registered name and address is caught, with file and
line; removed, the ward is clean.

## The part that cannot be undone by a commit

**The name is still in the git history** of the public repository. Removing it there means rewriting
published history and force-pushing — which the delivery gate forbids and which would break every
clone. The honest position: the exposure is already public, the current tree is clean, and history is
his decision to make explicitly, not a tidiness edit.

## The rule this earns

Appended to Rule 04 and Rule 26: **a person named in the operator's registries is private data, and
the public tree is the widest external surface there is.** A name there may be indexed, mirrored and
copied where no correction can follow it.
