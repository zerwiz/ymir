# PI Primary Boot — how Ymir boots as Brokk

Load this when building or changing the PI primary boot path. Ymir's system
primary boots as **PI** into the Brokk distro runtime; Galdr governs its CLI
surface.

## Boot stack

```
pi_boot[6]{figure,mechanism,file}:
  "Hamr","harness resolution (Pi default profile)","bin/hamr-harness.sh"
  "Einherjar","dispatch Eindri workers from an Erindi brief","bin/einherjar-spawn.sh"
  "Runtime backend","herdr/tmux pane supervision (Þjazi protocol 14+)","bin/backend/*"
  "Supervision","Sýn/Gná watcher + Pi supervision branch under Valhalla","bin/syn-watch-arm.sh, .pi/extensions/gna-pi-watch.ts"
  "Worktrees","Yggdrasil (`.yggdrasil/<id>/`) zero-collision isolation","bin/einherjar-spawn.sh"
  "Huginn observer","read-only (W0012) until Ratatoskr two-way","bin/nornir-job-observer.sh"
```

## PI CLI requirements (Galdr-governed)

Every PI-facing CLI must:

```
pi_cli[5]{id,requirement}:
  1,"Support Hamr profile resolution (`--profile pi` default)"
  2,"Emit TOON with the rodd operational schema (status, role, worktree, utgard, sandboxed, session_id)"
  3,"Declare Utgard sandbox compliance (the five gates in registry.md)"
  4,"Integrate with herdr for pane lifecycle (spawn/monitor/kill)"
  5,"Observe into Mimirsbrunn on every dispatch (`POST /observe`)"
```

## Boot asset directory

`.agents/skills/galdr/assets/pi-boot/`

```
pi_boot_assets[4]{file,purpose}:
  "pi-profile.yml","default PI harness profile (model, context, tools, workspaceRAG)"
  "herdr-profile.toml","pane layout, Þjazi protocol config"
  "einherjar-spawn.schema.json","dispatch payload validation"
  "supervision-tree.yml","Valhalla supervision branch definition"
```

## Verification

```
bash -n bin/hamr-harness.sh bin/einherjar-spawn.sh
python3 -m json.tool .agents/skills/galdr/assets/pi-boot/einherjar-spawn.schema.json
bash bin/hamr-harness.sh            # prints the current harness
bash bin/hamr-harness.sh eindri     # prints the effective Eindri harness
```

## Maintaining this

- **Owner:** Brokk. **Router:** `.agents/skills/galdr/SKILL.md`.
- **Mirror:** `.agents/skills/tyr-check/assets/pi-boot-guide.md`.
- The runtime itself is specified in `assets/brokk-distro-runtime.md`; this asset is
  the PI boot view only.
