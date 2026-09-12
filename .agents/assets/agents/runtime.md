# Runtime — PI primary boot (loaded from AGENTS.md)

AGENTS.md loads this when a task touches how Ymir boots or supervises the primary.
The full runtime spec is `.agents/skills/galdr-cli/assets/brokk-distro-runtime.md`.

## Boot stack

```
pi_boot[6]{figure,mechanism,file}:
  "Hamr","harness resolution (Pi default profile)","bin/hamr-harness.sh"
  "Einherjar","dispatch Eindri workers from an Erindi brief","bin/einherjar-spawn.sh"
  "Runtime backend","herdr/tmux pane supervision (Þjazi protocol 14+)","runtime backend"
  "Supervision","Sýn/Gná watcher + Pi supervision branch under Valhalla","bin/syn-watch-arm.sh, .pi/extensions/gna-pi-watch.ts"
  "Worktrees","Yggdrasil (`.yggdrasil/<id>/`) isolation","bin/einherjar-spawn.sh"
  "Huginn observer","read-only (W0012) until Ratatoskr two-way","bin/nornir-job-observer.sh"
```

## PI CLI requirements

```
pi_cli[5]{id,requirement}:
  1,"Support the Hamr profile (`--profile pi` default)"
  2,"Emit TOON with the `rodd` operational schema"
  3,"Declare Utgard compliance (5 gates)"
  4,"Integrate with herdr for pane lifecycle (spawn/monitor/kill)"
  5,"Observe into Mimirsbrunn on dispatch (`POST /observe`)"
```

PI boot assets: `.agents/skills/galdr-cli/assets/pi-boot/` (pi-profile.yml,
herdr-profile.toml, einherjar-spawn.schema.json, supervision-tree.yml).

## Seating

Run `bin/saga-session-start.sh` exactly once at session start; if the harness
injected the Sága digest, do not run it again. Start the Nornir jobs if the digest
reports them stopped.
