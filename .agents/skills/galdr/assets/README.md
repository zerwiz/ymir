# Galdr Assets — master index

```
galdr[1]{role}:
  "master builder & maintainer of the Ymir runtime + agent-CLI ergonomics; load only the row that matches the task"
```

## Routing

```
assets[23]{path,load_when}:
  "principles.md","the 10 CLI design principles (full doctrine)"
  "build-method.md","building/maintaining the runtime; forging a new skill"
  "registry.md","skills, tools, commands, Eindri profiles, aett, schemas"
  "norse-naming.md","naming any component; the naming law + component map"
  "brokk-distro-runtime.md","the runtime spec (home, digest, lock, supervision, cron)"
  "runtime-components.md","every runtime component, interface, and env var"
  "runtime-compliance.md","the runtime acceptance gates + runnable checklist"
  "harness-integration/README.md","choosing a harness; adding a new harness"
  "harness-integration/opencode.md","building/using the OpenCode adapter"
  "harness-integration/pi.md","building/using the Pi adapter"
  "harness-integration/claude-code.md","building/using the Claude Code adapter"
  "harness-integration/cursor.md","building/using the Cursor adapter"
  "harness-integration/codex.md","building/using the Codex adapter"
  "smidja.md","the smithy: install, roster/pi models, run, trace, visualizer ports, observer"
  "porting-upstream-to-norse.md","porting a validated upstream into Norse form"
  "eindri-orchestration.md","spawning/briefing/supervising Eindri workers"
  "nornir-jobs.md","the scheduler, the jobs, and the Runes ledger"
  "hlidskjalf-ui.md","any change under apps/hlidskjalf"
  "pi-boot-guide.md","the PI primary boot path"
  "eindri-profiles.md","Einherjar fleet profiles (8 specialists)"
  "build-tool-categories.md","build tool categories for synthesis"
  "reference-adoption.md","reusing assets/data, reference skills/state/docs, state conventions"
```

## Supporting assets

```
support[5]{path,load_when}:
  "pi-boot/pi-profile.yml","PI harness profile (model, context, tools)"
  "pi-boot/herdr-profile.toml","pane layout / Þjazi protocol"
  "pi-boot/einherjar-spawn.schema.json","dispatch payload validation"
  "pi-boot/supervision-tree.yml","Valhalla supervision branch"
  "README.md","this index"
```

Also available beside Galdr: `.agents/skills/galdr/schemas/toon-schemas.md` (TOON output
schemas per tool type), the scripts under `.agents/skills/galdr/scripts/` (TOON +
compliance checks), and the same assets mirrored under
`.agents/skills/tyr-check/assets/` for the judge.

## Lore reference

```
lore[1]{path,load_when}:
  "docs/lore.md","The Complete Frame — 30 sections (I-XXX), all Norse-named components"
```

## Related manuals

```
related[1]{path,load_when}:
  ".agents/assets/agents/*.md","the AGENTS.md manual: naming, registry, runtime, toon-tasks"
```

## Maintaining this

- **Owner:** Brokk. **Router:** `.agents/skills/galdr/SKILL.md`.
- Add a row here the moment an asset is created; remove one only when superseded.
- Keep the mirror under `tyr-check/assets/` in sync (`diff -rq` must be clean).
