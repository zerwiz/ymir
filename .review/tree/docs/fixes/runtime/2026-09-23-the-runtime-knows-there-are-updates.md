## runtime · unversioned · 2026-09-23 — a bare `ymir` shows a menu, and the runtime knows there are updates

### Why
Two product faults, both found by the Allfather typing one word.

**1. A bare `ymir` ran the INSTALLER.** A user who typed `ymir` to see what it was
got a setup plan and a `Proceed with the install? [y/N]` prompt — with no way to
reach any other door unless they already knew its name. The doors ARE the
product; a bare command should show them, not commit the machine to a plan.

**2. The runtime had no sense of drift.** Only the CLI (`bin/ymir.js`) checked
npm, so its notice reached a USER at a terminal. A **session** could run for days
on an old tree and never learn a fix had shipped — Brokk could not offer to
update, and the Allfather had to remember to look. The question asked was exactly
right: *does Brokk get to know there are updates?* He did not.

### Fix
- **`bin/ymir.js`** — a bare `ymir` now prints a **MENU** in the installer's own
  design (mark, subtitle, indented rows, bronze names, faint prose), grouped by
  intent: `begin` · `keep it` · `lift it` · `the way in` · `your own`. It shows
  the chosen home, and closes with *"Nothing here changes this machine until you
  say so."* Setup is a door, entered on purpose.
- **`bin/ymir-update-check.sh`** (new) — the runtime's own sense of drift: is a
  newer `@zerwiz/ymir` on npm? Cached **one day** (`state/update-check`), never
  fatal (no network → silence at exit 0), and **exit 3** when a newer version
  stands, with the exact remedy (`npm i -g @zerwiz/ymir`, then `ymir groa`).
- **`bin/saga-session-start.sh`** — a new **`== UPDATE ==`** section runs the
  check, so **every session opens knowing** whether the tree is behind.

### Verification
- `node --check bin/ymir.js` and `bash -n` on both scripts: clean.
- A bare `ymir` prints the menu (no installer, no prompt).
- The runtime check answers:
  `"0.1.39","0.1.49","newer stands","npm i -g @zerwiz/ymir  (then: ymir groa)"`,
  exit **3** — and reads `current` (exit 0) once the versions agree.
- The day's cache is respected: a second call in the same day short-circuits.

### Files
- `bin/ymir.js`
- `bin/ymir-update-check.sh` (new)
- `bin/saga-session-start.sh`
