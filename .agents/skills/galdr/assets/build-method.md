# Galdr Build Method — build, maintain, and forge

The repeatable procedure for building or maintaining any part of Ymir, and the
gates a new skill must pass to be "forged". Load this when building, porting, or
extending the runtime or a skill.

## Asset map (load the row that matches the task)

```
build_assets[6]{step,asset}:
  "runtime spec","assets/brokk-distro-runtime.md"
  "harness guide","assets/harness-integration/<harness>.md"
  "component interfaces","assets/runtime-components.md"
  "naming law","assets/norse-naming.md"
  "porting","assets/porting-upstream-to-norse.md"
  "acceptance gates","assets/runtime-compliance.md"
```

## The build method (repeatable, per harness)

1. **Read the runtime spec** — `assets/brokk-distro-runtime.md` (home layout, digest,
   lock, supervision, cron, worker model).
2. **Check the harness guide** — `assets/harness-integration/<harness>.md` for the
   exact hook surface, event names, and file paths.
3. **Reuse the runtime scripts** — the harness adapter never reimplements the digest,
   the lock, the watcher, or the guard; it invokes `bin/saga-session-start.sh`,
   `bin/saga-sessionstart-run.sh`, `bin/syn-watch-arm.sh`, `bin/syn-turnend-guard.sh`,
   `bin/rodd-operational-input.sh`, `bin/gleipnir-lock-lib.sh`.
4. **Wire the contract** — session-open injection (run or nudge tier), watch arm,
   turn-end guard, pretool seatbelts.
5. **Bind the lock to the live session** — pass `BROKK_SESSION_PID` so Gleipnir holds
   the harness process, not the short-lived digest helper.
6. **Fail closed** — never launch on an unverified harness; a missing dependency is a
   blocker, never a silent fallback.
7. **Verify** — `bash -n` every shell file, parse every JSON, smoke-test the chain,
   and run the checklist in `assets/runtime-compliance.md`.

## Harness matrix (authoritative names)

```
harnesses[6]{harness,surface,tier,figures}:
  "OpenCode","`.opencode/plugins/saga-sessionstart.js`, `syn-watch-arm.js`, `syn-turnend-guard.js`, `syn-pretool-check.js`, `syn-cd-check.js`","run","Sága+Sýn"
  "Pi","`.pi/extensions/syn-turnend-guard.ts`, `gna-pi-watch.ts` (+ Vörðr supervisor)","run","Sága+Sýn+Gná+Vörðr"
  "Claude Code","`.claude/settings.json` SessionStart + Stop","run","Sága+Sýn"
  "Cursor","`.cursor/hooks.json` sessionStart + stop + preToolUse","run","Sága+Sýn"
  "Codex","`.codex/hooks.json` SessionStart + PreToolUse + Stop (`[features].hooks=true`)","run","Sága+Sýn"
  "Grok","not yet implemented","—","—"
```

Details, gotchas, and verification per harness: `assets/harness-integration/`.

## Porting a validated upstream distro

Prefer **copy-then-edit** over rebuild; the upstream carries edge cases you would
otherwise re-derive. Follow `assets/porting-upstream-to-norse.md`: audit coupling,
strip presentation and non-ported branches, retarget names/env/paths, bind the lock,
defer the rest, then verify. Never rename our components after the upstream.

## Maintenance rule

When the runtime changes, update the owning asset in the same pass.

**Every platform layer moves with the core.** Ymir is Omarchy-first but the core
is portable (Linux, macOS, Windows/WSL2), and each platform may carry its own
installation layer — see `RULES/05-platforms.md`. A core change is not complete
until each layer has been checked against it and either updated in the same
change or explicitly recorded as unaffected. A layer still installing the old
shape is drift: a machine that boots expecting a runtime it no longer has.
 Galdr assets are
the system's memory: a runtime change that is not reflected in `assets/` is an
incomplete change. Tyr judges both the code and the asset for drift.

## Forge verification (six gates, gated by tyr-check)

Before a new Galdr skill is considered "forged", it must pass these six gates, with
asset references:

```
forge_gates[6]{id,gate,asset}:
  1,"TOON output test — stdout TOON, ~40% smaller than JSON across 3 samples","schemas/toon-schemas.md"
  2,"Principle compliance — all 10 principles assessed","assets/principles.md"
  3,"Norse name validity — follows the aett pattern","assets/norse-naming.md, assets/registry.md"
  4,"Frame integration — SKILL.md in `.agents/skills/<name>/`, referenced in the README; briefing notes it","assets/registry.md"
  5,"Mimirsbrunn observation — creation observed into the well before live","POST /observe"
  6,"PI primary compatibility — works under Hamr, emits rodd, Utgard-compliant, herdr-integrated","assets/pi-boot-guide.md"
```

Once all six gates pass, the skill is "forged" — it joins the library of the halls
and is available via `npx skills add <owner>/<repo> --skill <name>` or as a managed
plugin in `.config/opencode/plugins/`.

## Acceptance summary (master builder)

A Galdr-managed build is accepted only when all hold:

```
acceptance[7]{id,gate}:
  1,"Comprehensive & reusable — assets/README.md routes every task"
  2,"Norse methodology enforced — role-matched names; operator is the Allfather"
  3,"Every harness documented and wired under assets/harness-integration/"
  4,"Runtime contract honored — injection, lock binding, guard inert-until-armed"
  5,"Production, no mocks — no examples/placeholders in the shipped runtime"
  6,"Verified — bash -n clean, JSON parses, smoke evidence, compliance checklist"
  7,"No drift — plan, code, and assets agree (Tyr's drift judgment)"
```

Full gates and runnable checks: `assets/runtime-compliance.md`.

## Maintaining this

- **Owner:** Brokk. **Router:** `.agents/skills/galdr/SKILL.md`.
- **Mirror:** `.agents/skills/tyr-check/assets/build-method.md`.
- Update the asset map and harness matrix whenever a component or harness changes.
