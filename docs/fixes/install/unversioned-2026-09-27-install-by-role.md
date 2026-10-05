## install · unversioned · 2026-09-27 — the install stops installing every role's parts

### Why

Plan 51 P1 built the **capture** half — `bin/skuld/role.sh` declares, reads, and
validates a machine's role — and shipped it with an honest note: *"Install-time
component selection (P1's install half) is documented, not yet wired into
`bin/engine/ymir-install.sh`."* The gap was real. Every host, whatever it was in the
fleet, ran the one shape: a heart would install the dev desktop layer, a dev body
would install heart offices, and a forge would install the desktop. The old
`step_role` also resolved the role **as step 16 of 27** — after the chain had
already touched the machine — and silently registered an absent host as `dev`.

That is the last thing plan 51 named as unmade: *"the only remaining item:
install-time COMPONENT SELECTION"*.

### What

- **`bin/skuld/role-lib.sh` (new, source-safe).** One owner for three things the
  installer must not re-decide: the resolution chain (`establish_roles`), the
  role→component table (`components_for`), and the machine-card writer
  (`machine_card_write`). Functions only; the tests source it directly.
- **`bin/skuld/role.sh` gains `resolve`.** The READ road: `$YMIR_ROLE` → the fleet
  registry (by hostname) → the host's own card row in
  `hodd/data/machines.md` → nothing. `--why` says which source answered. An
  unknown `$YMIR_ROLE` is refused (exit 2), and a word that merely *contains* a
  role name (`primary development`) is not read as a role.
- **`bin/engine/ymir-install.sh` resolves the role BEFORE its step chain** (right after
  consent) and gates every role-owned step through `role_gate`: a component this
  machine's roles do not own becomes a `SKIP` naming the owning role — never a
  substitution, never a silent default. A new `--role <r>` flag states the role
  for the run; an unknown name is refused before anything changes, and the
  resolved role is exported so `bin/skuld/role.sh`, `bin/fleet/topology.sh`, and the plan all
  read the same fact.
- **The component table** (one table, `bin/skuld/role-lib.sh`):
  `heart` → core·record·well·web·mesh (the record, and *no* dev desktop layer and
  *no* rail); `forge` → core·rail·harness·sandbox (the rail, and *no* desktop and
  *no* record); `dev` → core·harness·rail·desktop·web·mesh·well·sandbox (a full
  body, and no heart office); `hand` → core only. A machine may hold two roles;
  the parts union.
- **A new `record` step** (heart-only) asserts the heart's offices: the engram
  store, the `bin/records/journal-receive.sh` fold receiver, and the `@heart` record jobs
  in the cron config. It is the dev/forge body's clearest SKIP line, and it makes
  the record's single-writer law visible at install time.
- **The machine card is folded into the ONE registry.** `step_role` writes the
  card into `hodd/data/machines.md` (plan 39's fold — no parallel shelf). It is
  keyed by a deterministic heading (`## Machine card — <host> (role: <roles>)`),
  so a repeat install writes nothing and a **role change APPENDS** a new card:
  Rule 06 holds for the registry.
- **A missing role is asked, or narrowed and said.** A host declared nowhere is
  ASKED on a real interactive run (`h/f/d/n`), and the answer is recorded. A run
  that cannot ask (`--check`, `--yes`, no tty) takes the plan's documented safe
  body (`dev` — owns no record, runs no record job) and reports it as a WARN
  naming the remedy. It is never the union of every role's parts.
- **`bin/bridge/ymir-plan.sh`** gains a phase-0 `role` row (INFO, or CONSENT when
  nothing is declared) and accepts `--role`, so the consent plan names the role
  and where it came from instead of reading as one shape everywhere.
- **Rule 05 holds:** the role layer is host-neutral — it selects components,
  never platform behaviour — while the Omarchy/macOS/Windows layers stay gated on
  the host.
- **Assets updated in the same change:** `installation.md` (the `role` + `record`
  rows, the corrected count, and the rewritten *"The machine's role — the
  install's component set"* section) and `brokk-distro-runtime.md` (new §6.1 *The
  role gate — one fact, every surface*, plus the acceptance invariant).

### Proof (live, on the heimdall box — role `dev`)

```
bin/engine/ymir-install.sh --check            # this box, from the registry
  "role","OK","role: dev (source: registry) · link: attached · components: core,harness,rail,desktop,web,mesh,well,sandbox"
  "record","SKIP","not this machine's role (heart only) — the record (fold · store · record crons) lives on the heart"

bin/engine/ymir-install.sh --check --role heart
  "record","OK","would hold the record — engram store present · journal fold present · 7 record cron(s)"
  "sessrumnir","SKIP","not this machine's role (dev only) — the dev desktop layer"
  "omarchy","SKIP","not this machine's role (dev only) — the dev desktop layer"
  "local-model","SKIP","not this machine's role (forge,dev only) — the model rail"

bin/engine/ymir-install.sh --check --role forge
  "local-model","OK","engine would stand (adopt/build) CUDA llama-server"
  "omarchy","SKIP","not this machine's role (dev only) — the dev desktop layer"
  "record","SKIP","not this machine's role (heart only) — the record …"
  "memory","SKIP","not this machine's role (heart,dev only) — the well …"

bin/engine/ymir-install.sh --check --role wizard   # exit 2, before any change
  error: unknown role wizard
```

`--check` wrote nothing: `hodd/data/machines.md` and `hodd/data/fleet.json` were
byte-identical before and after (md5sum), and no machine card was made. `--check`
completes with **no route to any machine**: under `unshare -rn` `bin/fleet/topology.sh`
reports `link: offline` and the installer prints its full 33-row check with exit 0
(plan 51 Part 2.5 rule 7).

Tests (all PASS):

```
bash .agents/tests/role.test.sh              # + resolve: registry · card · word-boundary · nothing · env · refusal
bash .agents/tests/role-lib.test.sh          # the table · the chain · the ASK (pty) · the safe body · card write/idempotence/append
bash .agents/tests/install-role-gate.test.sh # behavioural: dev/heart/forge/hand · unknown-role refusal · no writes · no-network
```

### Honest — what a fresh seat must still prove

- **The real install path on a SEAT.** `--check` proves the selection; the
  component set a *real* run installs was not exercised here, because a real
  install on this box would raise/heal the live runtime and write the operator's
  home. The gates are the same code either way, but the first fresh-seat install
  (and the first `heart` install on zerwizserver) is the lasting proof.
- **`bin/skuld/role.sh set` on a real run** writes the fleet registry; on this box only
  the reader was exercised (the row for `heimdall` already said `dev`).
- **The machine card has never been written to the live registry from a real
  install** — only to a temp registry in the tests. Its first real write lands on
  the next real install (or a seat's).

### Files

- `bin/skuld/role-lib.sh` (new)
- `bin/skuld/role.sh`, `bin/engine/ymir-install.sh`, `bin/bridge/ymir-plan.sh`
- `.agents/tests/role.test.sh`, `.agents/tests/role-lib.test.sh`,
  `.agents/tests/install-role-gate.test.sh` (new)
- `.agents/skills/galdr-ymirsystem/assets/installation.md`,
  `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`
