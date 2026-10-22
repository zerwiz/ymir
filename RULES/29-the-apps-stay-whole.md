# 29 — An update that leaves an app unreadable is not an update

**Appended 2026-10-22** at the Allfather's word: *"we need to append to the rule to always make sure
all apps are functional on updates on ymir… maybe we should have a guard for this."*

## The law

**Every change that ships leaves every app able to start and every panel able to speak to it.** An
update is not judged by whether it compiles somewhere, or whether the unit is green, or whether one
endpoint answers — it is judged by whether a person opening the app sees their data.

Three duties, one gate (`bin/gates/guards/app-functional-guard.sh`, wired into
`bin/gates/guards.sh`):

1. **It parses.** Every app's server entry is transpiled before it ships. A syntax error is a dead
   app, and it costs nine seconds to know.
2. **Every door the UI knocks on is answered.** A route the interface calls and the server never
   implements is a promise the product does not keep.
3. **With the app raised, nothing answers 5xx.** `--live` probes the running gate. A 5xx is a dead
   app wearing a green unit.

## Why it exists — this day's own wound, measured

Commit `068f0872` (2026-10-21) inserted a row into the watchtower and **ate the `return {`** that
opened `wardState()`'s object in `apps/hlidskjalf/server/index.ts`. The file stopped parsing — not at
request time, at load time. What that looked like from the operator's chair, on 2026-10-22:

```
the gate API        :3889  not listening — the process died at load, every restart died the same
every /api/*        500, zero bytes              → the SPA: "SyntaxError: Unexpected end of JSON input"
worktrees           "no worktrees"               → it was one panel of eight failing the same way
the well            "Bridge DOWN :4602, COLD"    → the bridge was healthy and answering all night
stats               empty                        → no data face to ask
```

**One missing brace took the whole control plane's data face down for a day, and no gate noticed** —
because `tsc --noEmit` in that app's own script does not transpile a file the bundler never reaches,
and because nothing was required to prove an app could be read. The second fault of the same day was
its sibling: Þráðr called `/api/terminal/status`, which was never implemented, so the panel printed
`terminal status 404` where a capability belongs.

## What the law requires of a change

- **Touch an app's server, and the guard runs.** It is in the pre-push list; a failing ward stops the
  push with the file and the reason named.
- **A dead button is a defect of the same weight as a dead service.** A menu entry, a key, or a panel
  that cannot reach its door is not cosmetic — see the halls, repaired the same day, and the launcher
  fix note beside them.
- **A capability you cannot raise is not a capability.** If the app needs a backend the tree does not
  hold, the app must say so in words — never an HTTP error string, and never a green unit standing in
  front of a closed door.
- **No silent skip.** No bun, no server, no network: the ward prints a clean SKIP and exits 0
  (Rule 25). It never reports a pass it did not measure.

## What it is not

Not a substitute for the app's own tests, and not a promise of correctness — the ward proves the app
can be **read, routed and answered**, which is the floor beneath every other claim. The panels'
contents are still the operator's to judge.
