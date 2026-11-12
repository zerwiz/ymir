## agents · unversioned · 2026-11-12 — an update finishes the installs: Eir mends by risk class from one register, and Gróa's last line tells the truth

### Why

An update on a dev seat reported success while eight Eir surfaces were still broken. The operator's word was
*"it needs to finish the installs."* Reading the code showed four reasons (plan 278):

- Gróa ran Eir in `check` mode only. Broken surfaces were counted and printed, never mended.
- A step that hit its time limit printed "the update went on without it" and did not change the verdict.
- The closing line could not say that installs were owed. A call to `update-notes.sh` sat after the final
  `exit`, so it never ran.
- Eir had no notion of who may run a mend. `fix` mended everything it could, including installs that download
  packages, so Gróa could not safely call it unattended.

Two Eir rows also told the operator nothing. `voice` and `hnoss` printed an empty reason when broken. The
`a2abridge` row was green while the directory never started, because the door it asked (`status`) always
exits 0.

### What changed

- **One register of surfaces.** `config/surfaces.yaml` names every Eir surface, its fleet roles and its risk
  class: `safe` (an update may mend it unattended), `ask` (a download, root, or a change to what the user runs),
  or `never` (report only). `bin/agents/surfaces.py` reads it, and Eir and Gróa read the same rows. Without the
  register Eir falls back to its own list and treats every mend as `ask`.
- **Eir mends by class.** `eir-doctor.sh fix --safe` mends only `safe` surfaces and names every other broken one
  as `eir: owed <surface> (<risk>) — bin/agents/eir-doctor.sh fix <surface>`. `fix <surface>` mends one surface
  at the operator's word. A `never` surface is never mended. Each mend is a Runes entry.
- **Every broken row carries a reason.** `voice`, `hnoss`, `snotra`, `council`, `vault` and `ward` read their
  door's first complaint. A row that still has none says so and names the command. `check` ends with one
  `owed: <surface> <risk>` line per broken surface.
- **The register's roles are fleet roles.** A surface declared for other roles is a clean skip. The role is read
  from the fleet registry (`bin/skuld/role.sh`), not from the seat's own office.
- **`a2abridge` tells the truth.** No engine is still a clean pass. An engine whose unit boots with
  `WantedBy=multi-user.target` (a target a user manager never reaches) or whose directory is down is broken. The
  mend is `a2abridge-ensure.sh ensure` without `--install`: it repoints the boot target and starts the unit, and
  never downloads.
- **Gróa mends after the check.** When Eir finds a broken surface, Gróa runs `fix --safe`, then checks again.
- **The last line tells the truth.** `groa-update: whole — every surface answers`, or
  `groa-update: NOT whole — owed: …; steps stopped at their limit: …` followed by the exact commands. A stopped
  step now fails the verdict. A partial update exits **4** (1 still means the seat could not be seated). A
  surface the operator lists in `$YMIR_HOME/config/owed-accepted.txt` is still named but no longer fails it.
- **One fault report per new owed set.** Gróa writes `hodd/state/groa/faults/<stamp>-surfaces.md` in the home
  when the owed set changes, and nothing while it is unchanged. It is the brief for the one smith plan 275 allows
  per update run. Sending that smith is not built here.
- **The update notes run.** The `update-notes.sh` call moved above the verdict.

### What was not changed, on purpose

- Plain `eir-doctor.sh fix`, run by a person, still mends every broken surface it can, as before. Only Gróa's
  road is limited to `safe`.
- No surface became `safe` if its mend downloads, needs root, or changes something the user chose. Installing
  the hnoss MCP package is `hnoss-ensure.sh ensure --install`, and stays the operator's word.

### Proof

- `bin/agents/tests/test_eir_register.sh` (19 checks): the register parses and matches Eir's checks both ways; a
  broken `safe` surface is mended by `fix --safe`; an `ask` surface is left alone and named as owed with its
  command; a `never` surface is never mended, even by name; `check` gives every broken row a reason and prints
  the owed rows; a malformed register is refused; a unit on `multi-user.target` is a named a2abridge fault.
- `bin/agents/tests/test_groa_verdict.sh` (23 checks): whole and exit 0; owed surfaces named with risk and
  command and exit 4; a stopped step fails the verdict; an accepted surface is named but passes; one fault report
  per new owed set; the update-notes call is no longer after the final exit.
- Existing `test_eir_mends.sh`, `test_units.sh`, `test_groa_steps.sh`, `test_unit_settle.sh` and
  `test_runtime_deploy_stable.sh` still pass.

### Files

- `config/surfaces.yaml`
- `bin/agents/surfaces.py`
- `bin/agents/eir-doctor.sh`
- `bin/agents/groa-update.sh`
- `bin/agents/groa-verdict-lib.sh`
- `bin/agents/tests/test_eir_register.sh`
- `bin/agents/tests/test_groa_verdict.sh`
- `bin/gates/ci-verify.sh`

## CHANGE LOG

- **2026-11-12** — Opened.
