# 23 — No code in an application's folder (and no application's folder in `bin/`)

## 0 · What an application IS — the registry (the list this rule is about)

**`apps/` is the registry.** A directory there is an application; an application lives
there and nowhere else. The five, today:

```
apps[5]{path,name,what}:
  "apps/hlidskjalf","Hlidskjalf — the Allfather's high seat","the master control dashboard: the one plane that shows the whole house"
  "apps/odrerir","Óðrerir — the mead of poetry","the fleet's Live Hall: boards, tickets, plans made visible"
  "apps/sessrumnir","Sessrúmnir — Freyja's hall of seats","the desktop seat: a GUI front-end for the Pi and OMP coding agents (fork of pi-desktop)"
  "apps/smidja","Smíðja — the smithy","the agent factory: roster, phases, envelopes, the trace store, the Visualizer UI"
  "apps/smidja-factory","— (the same craft, upstream)","the factory clone that STAMPS smidja/ into a repo — not a UI the operator opens"
```

**An application is something the operator opens**, and it carries: a figure's name, a
`README.md`, its own build, and — if a layer must deploy it — exactly **one** shim in
that layer named `<app>-<function>.sh`. `apps/README.md` is the index and must name
every application (it is updated in the same change that adds one).

**Everything else in Ymir is a tool of the machine**, and lives under `bin/<layer>/`,
named for the layer and, inside it, for the **function** — never for an application.

**Appended 2026-10-18** at the Allfather's word, after a real mistake: an opening tool
(`display-lib.sh`, `open-on.sh`) was written into **`bin/seat/sessrumnir/` <!-- stale-ok: named as the retired shape this rule forbids; the door is bin/seat/ -->** — a directory
named after an *application* — because the file that inspired it (`editor-place.sh`) happened
to live there. His words: *"sessrumnir have nothing to do with the displays, sessrumnir are an
application. how could this fatal mistake happen?"* and then *"we can't have random code in
the application folders."*

*(Numbered 23: 20 is the well appends, 21 is company documents, 22 is the home layout — all merged on `main` before this rule.)*

```
app_folder_law[5]{rule}:
  "AN APPLICATION'S CODE LIVES WITH THE APPLICATION","its logic, build, dev tooling and tests belong under apps/<app>/ — the fork's own scripts included"
  "bin/ HOLDS THE MACHINE'S TOOLS","named for the LAYER (host · desktop · seat · fleet · engine · gates…), and inside a layer for the FUNCTION (app-build · desktop-place · editor-place · open-on)"
  "NO APP-NAMED DIRECTORY UNDER bin/","a directory called bin/seat/sessrumnir/ is not a seat tool — it is an application wearing a layer's coat, and everything inside it is misfiled by association"
  "A SHIM IS ALLOWED, WITH A FUNCTION IN ITS NAME","in the layer that owns the deployment: <app>-ensure.sh · <app>-status.sh · <app>-sync.sh · <app>-observe.sh. The layer materials and checks it; the app holds the logic"
  "NEVER THE OTHER WAY","a layer's tool inside apps/<app>/ is the same fault mirrored — an application's folder is not a toolbox"
```

**The test, when a file's home is not obvious:** *if it were deleted, what breaks?*

```
what_breaks[3]{answer,home}:
  "a capability of the MACHINE (windows placed, files opened, ports watched)","bin/<layer>/<function>.sh — function-named"
  "a feature of ONE APP","apps/<app>/ — with the app"
  "only that app's DEPLOYMENT (it must be installed, checked, synced)","bin/<layer>/<app>-<function>.sh — a shim, in the layer that deploys it"
```

**Enforced by** `bin/gates/guards/app-folder-guard.sh`, composed into `bin/gates/guards.sh`: it
fails when a directory under `bin/` is named after an application, or when an app appears in
`bin/` under a name that carries no function. The audit that motivated the rule (what is
misfiled today, and where each file goes) is plan **82**.

---

## Appended 2026-10-24 — `systems/`: a system is not an app, and ownership is the axis

Plan 129 (§12–§13, §18). This rule's opening — *"an application is something the operator opens"* — is right and
stands. It did not cover a headless thing that **owns records and runs whether or not anyone watches**, and because
it did not, Snotra's 75 files were filed on a *time* shelf (`bin/time/snotra/`) where no answer to "who keeps this?"  # allow-superseded-path: this sentence RECORDS the move, it does not make it
existed. Three sentences are appended, and one axis:

```
appended[4]{rule,what_it_means}:
  "A SYSTEM IS NOT AN APP","`systems/<system>/` holds headless, stateful systems — no UI of their own. Deleting one loses a record"
  "AN APP MAY READ A SYSTEM, NEVER CONTAIN IT","Hlidskjalf shows Snotra's record; it does not hold Snotra's code"
  "A SERVICE IS A PROCESS, NOT A PLACE","a service's folder sits INSIDE the system that owns it — `systems/snotra/services/ear/` — and is started by that system's door. A top-level `services/` is the same mistake in a different coat"
  "OWNERSHIP IS THE AXIS","a domain is the primary folder; a technical layer (time, records, agents, gates, mail, people, room) becomes a folder INSIDE a domain or part of the shared kit; `bin/` is a dispatcher that shrinks"
```

**The tests that decide which shelf a thing belongs on** (measured counts in plan 129 §12):

```
kinds[7]{kind,test,where_it_lives}:
  "APP","does the operator open it and see it?","apps/<app>/"
  "SYSTEM","does it own state or records, and run whether or not anyone watches?","systems/<system>/"
  "SERVICE","does something connect to it while it runs (it holds a socket)?","inside its system: systems/<system>/services/<service>/"
  "TOOL","do you run it and does it exit?","bin/<layer>/<function>.sh"
  "SKILL","does an agent LOAD it as procedure?","`.agents/skills/`"
  "KEEPER","is it a named identity with a profile, bounds and a memory?","`.agents/agents/<figure>/`"
  "DOMAIN","do a keeper, a system, a board and a memory agree on one name?","`hodd/identity/domains.yaml` binds them"
```

**A system declares itself** in `systems/<system>/domain.yaml` — folder · keeper · board · memory namespace ·
services and their doors · what it may ask · what it may never touch · its `policy:` block (data, not code). The
declaration is the authority for what lives in the folder; a folder that disagrees with its `domain.yaml` is drift.

**The first system to land under this append is Snotra** (`systems/snotra/`, 2026-10-24): a one-line redirect was
seated at the old path first, the callers were repointed in batches, `.agents/paths-ledger.yaml` records the move
and `.agents/migrations/0014-systems-shelf.sh` heals an existing home. `bin/time/` now holds only the clock and the
Nornir jobs, and its calendar door belongs to Snotra (plan 129 §18).

**Still owed by this append, named rather than papered over:** a placement guard that fails when a layer directory
outgrows its name (plan 129 §15/§18), and the same move for `bin/assistant` → `systems/skirnir/`, `bin/mail` →
`systems/gna/`. Until the guard exists, this rule is enforced by review, not by a gate.
