# 22 — No code in an application's folder (and no application's folder in `bin/`)

## 0 · What an application IS — the registry (the list this rule is about)

**`apps/` is the registry.** A directory there is an application; an application lives
there and nowhere else. The five, today:

```
apps[5]{path,name,what}:
  "apps/hlidskjalf","Hlidskjalf — Odin's high seat","the master control dashboard: the one plane that shows the whole house"
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
(`display-lib.sh`, `open-on.sh`) was written into **`bin/seat/sessrumnir/`** — a directory
named after an *application* — because the file that inspired it (`editor-place.sh`) happened
to live there. His words: *"sessrumnir have nothing to do with the displays, sessrumnir are an
application. how could this fatal mistake happen?"* and then *"we can't have random code in
the application folders."*

*(Number 21 is spoken for by the state-lives-in-the-home rule, which code already cites.)*

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
