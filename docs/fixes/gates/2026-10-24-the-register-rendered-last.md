# The register rendered last, and the night's archive tags

**2026-10-24.** Component: `bin/gates/inventory.sh` (its rendering discipline), the pre-push `fixes-guard`.

Two small things happened repeatedly tonight and are worth one note, because both cost pushes:

1. **A generated register must be rendered immediately before the push, never earlier.** `bin/README.md` and
   `.agents/backend/README.md` are functions of the tracked tree; any commit made after the render (by me, by an
   errand, or by the assistant's snapshot cron) makes them stale again. Three pushes were refused by
   `inventory-guard` while the remedy — "run the generator" — had just been applied. The discipline is:
   *render → commit → push, in one breath.*
2. **`fixes-guard` refused the archive-tag push** because the range carried no new fix note. That is the ward
   working as designed, and this note is the answer: the push carries archive tags for every local branch and
   nothing else, so nothing in it changes the machine. It exists so a branch that only this box holds cannot be
   lost — 20 branches were unpushed at the start of this exercise, including every errand branch of the night.

**Why the tags:** `git bundle --all` already holds the whole history in one file, but a bundle lives on this
disk. A tag on `origin` survives the disk. Together they are the floor beneath every future cleanup.

**Owed:** the same as the smoke note — `fixes-guard` should say *which* commits in the range it judged, so the
answer is a note for those commits rather than a guess at the whole range.
