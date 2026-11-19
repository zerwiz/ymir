# The apps README tells the truth first

**2026-11-19**, plan 325 step 5. `apps/README.md` opened with *"This directory IS the registry: a directory here is
an application, and an application lives here."* The split made that false: six apps left for their own repositories
with their history, and each runs from its own home under `~/.local/share/ymir-apps/`. Only Hliðskjálf stays here,
by the Allfather's word.

The correction already existed, but in a section appended at the foot of the file. A reader met the false sentence
first.

## What changed

- A box now opens the file. It names the seven apps, the repository of each and where each runs from. It names
  `config/app-repos.yaml` as the registry and `bin/apps/app-path.sh` as the door that finds an app.
- The old text is kept below the box as the record (RULES/06). A dated section at the foot says why the box was
  added.

## Proof

`bin/apps/app-path.sh <app>` on heimdall agrees with every row of the box. Hliðskjálf answers `legacy` (in this tree).
Smíðja, Óðrerir, Sessrúmnir, Bilskirnir, Rödd and Hvergelmir each answer `~/.local/share/ymir-apps/<app>/current`.

Smíðja's own README, a 323-byte stub on the `split/from-ymir` line it installs from, is written in its own
repository, not here. That change is committed on a local branch of `zerwiz/smidja` and is not pushed.
