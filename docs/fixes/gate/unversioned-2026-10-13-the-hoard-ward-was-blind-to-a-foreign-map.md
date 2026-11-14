## gate · unversioned · 2026-10-13 — the hoard ward was blind to a foreign map

### What

Eir's `hoard` surface exists to catch private data in the wrong place. It reported **`ok` on a
home that was broken in four ways** — so it was not a ward, it was a comfort.

**The masking bug.** The surface retried a declared layout path that did not exist *under this
root* whenever the path began with the map's `git_repo`. Our map named `/home/heimdall/…` for
every path, so each foreign path was retried as `$YMIR_HOME/<rest>` — which exists — and the
surface passed. **The retry masked precisely the fault the surface was built to catch.** A map
describing another machine is now a **failure**, and every declared path must exist as written.

Two more checks were added, both measured on this home the same day:

- **state outside the home** — `~/Documents/Ymir/state` (a case-variant directory), and state
  *inside the public repo* at `.agents/state` and `bin/state`;
- **a company or project document in the operator's own shelf** — `hodd/life/work/`, and a
  company meeting under `hodd/life/meetings/`.

### Verified

- Before: `"hoard","ok"` on a home whose layout map pointed at another machine.
- After: `"hoard","broken"` — and `"hoard","ok"` only once the causes were actually fixed
  (the map regenerated for this machine; the stray state moved into the home; the company
  meeting routed to its company shelf). The surface now tells the truth in both directions.

### Files

- `bin/agents/eir-doctor.sh`

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine (this seat). The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
