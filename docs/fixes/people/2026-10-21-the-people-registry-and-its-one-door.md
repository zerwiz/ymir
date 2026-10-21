# A registry of the people we work with — and one door to write it

**Component:** people · **Seat:** heimdall · **Date:** 2026-10-21

## What was missing

There was no place for **clients and collaborators**. Names lived in `companies.yaml` (as company
contacts), in the NDA register (as authorised parties), in meeting records, and in the operator's
head. That is exactly the shape in which a person gets emailed twice, or once too often, or with the
wrong assumption about what they have agreed to.

## What was built

- **The registry**: `$YMIR_HOME/hodd/identity/collaborators.yaml`, private, one record per person —
  id, name, kind (client · collaborator · adviser · partner · prospect), status (prospect · active ·
  paused · former), org, addresses, project, `nda`, consent flags, notes.
- **The door**: `bin/people/collaborators.sh` — `list`, `show`, `add`, `set`, `check`, `email`.
- **The example**: `config/collaborators.yaml.example`, so a clone has the shape without a person.
- **The page and the row**: `docs/features/collaborators.md`, and a `FEATURES.md` row (Rule 14).

## Why `email` is part of the door, and not a convenience

The door is the safe path, so the unsafe path is harder to take by accident:

- a `former` contact is refused;
- a person whose `consent.email` is false is refused;
- a person with no address is refused;
- **the private/NDA guard (Rule 26) runs over the body before the mail door is called** — a finding
  stops the send, it does not warn and continue;
- `check` refuses an `nda: true` whose address is not in the NDA register: a claim of
  confidentiality that is not on file is worse than no claim.

## First record

**One collaborator** (an HVAC/OvK product builder, `status: prospect`), emailed an introduction to
Ymir and a collaboration proposal the same hour. **His address is unverified**: the Allfather gave it
three different ways in one message, so the record says
so in `notes` and the send went to the middle reading. A record that hides its own uncertainty is how
a person gets emailed at an address that belongs to a stranger.

## One bug found by using it

The door's first `email` refused every body: the Python read paths from `__file__`, which is `-` when
the script is fed on stdin, so the guard path resolved outside the checkout. It now resolves from the
checkout root the shell already computed — found because the door refused rather than because it
silently sent the wrong thing.
