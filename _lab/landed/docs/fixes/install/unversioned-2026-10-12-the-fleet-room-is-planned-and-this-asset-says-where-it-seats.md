## install · unversioned · 2026-10-12 — the fleet room is planned, and this asset says where it seats

### What

The room's engine is **proven** but **not shipped**: a continuwuity homeserver was raised by
hand on one seat and a message posted and read back — yet **no step installs it**, so a user
who installs Ymir today gets no room. This appends that truth to the installation asset,
where a reader of the install would look for it, together with the **shape it will take**
when it lands: a `step_room`, a migration `0008-room`, a repo-owned unit + `fleet-ensure`
role, and an Eir surface.

It also records the two facts the live proof taught, so the eventual step does not repeat
them: **role-awareness** (the engine runs once, on the heart; a seat is a client and must
never raise a second homeserver) and **pinned provisioning** (the bootstrap token is written
to the hoard *before* first boot — the proof showed the token changes across restarts, so
scraping it from a log races the server).

### Verified

- The note is plainly marked **planned, not shipped**; it claims no capability the installer
  does not yet have.
- It points at the plans that own the design (plan 75 Parts 9/10/11) and the tickets
  (ymir/55, ymir/57), so the asset and the ledger agree.

### Files

- `.agents/skills/galdr-ymirsystem/assets/installation.md`

### The requirement stated plainly (the Allfather, 2026-10-12)

> *"ymir updates and installations must have fleet and single machine logics"*

So the asset now names **both shapes** and the split plainly: a **single machine** seats
engine + client on itself; a **fleet** seats the **engine role once, on the heart**, and
every other seat seats the **client role only**. The install/update **detects** the shape
(the fleet already declares its role) and never assumes — a seat that runs it must not
raise a second homeserver, and a machine the change does not apply to must **skip cleanly**,
not fail.
