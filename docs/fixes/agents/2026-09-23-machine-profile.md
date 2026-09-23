## agents · unversioned · 2026-09-23 — the persona loader

### Why
Every computer should know its own setup (the Allfather's law) — the knows:
files now live in the hoard; the loader makes them readable by name and by
host before a body acts.

### What
`bin/machine-profile.sh` — `--seats` lists the cards; `--seat <name>` prints
one; bare runs print THIS machine's card by hostname. Cards at
`hodd/data/knows/<seat>.md` in the home.

### Files
- `bin/machine-profile.sh`
