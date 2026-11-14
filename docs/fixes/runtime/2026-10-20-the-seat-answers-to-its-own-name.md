## runtime · unversioned · 2026-10-20 — the seat answers to its own name

### What

Every seat loaded a contract whose first line said **"You are Brokk"**, so a seat on
omarchy, whynot or zerwizserver inherited the main hall's name. The agent cards already
carried four different names; the contract ignored them.

This adds one source and one door:

- `$YMIR_HOME/hodd/identity/seats.yaml` — host → primary, role, status, why. Proposed
  names are marked `proposed`; `sealed` is the Allfather's act.
- `bin/agents/seat-identity.sh` — `list · name · file · json · set · ensure · install ·
  check · render`. `set` renames and re-renders; `ensure` runs at install time and
  fails loudly when a host has no name rather than inheriting Brokk.
- `bin/seat/valknut-load.sh --pi` installs `.ymir-seat` next to `.ymir-root`, so a
  fresh seat gets an identity at deploy time.
- `AGENTS.md` now opens **"You are the primary agent of this seat"** and points at the
  seat file, instead of asserting Brokk everywhere.

### Why

The Allfather: *"Brokk should have different names on the different machines… the
agent must choose the names per machine on installs and be able to change the
names."* A name that is inherited is a name that lies; an identity that can be changed
must have one editable record.

### Verified

- `tests/test_seat_identity.sh` — **10 assertions**: list, resolve, unknown host
  refused, install only on the matching host, check, set without a name refused, set
  seals, roster updated, render header, render includes the shared contract.
- On heimdall: `--install` writes `.ymir-seat` with `primary=brokk`; `--check` passes;
  `set omarchy sindri` on heimdall reports `skipped — not this host` and does not
  overwrite the local artefact.

### Not verified

- No seat has been rebooted with the new contract; omarchy and whynot still load the
  old first line until `valknut-load.sh --pi` runs there.
- The proposed names (Sindri, Muninn, Mímir) are **not sealed**.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: the fleet's always-on heart. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #755
