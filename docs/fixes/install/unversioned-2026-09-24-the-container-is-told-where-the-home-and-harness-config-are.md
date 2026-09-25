## install · unversioned · 2026-09-24 — the substrate container is told where the home and the harness config are

### Why
The container bind-mounted the checkout and the hoard, but two things were still
missing, and between them they broke five of the smoke test's checks:

- **The container was never told where its home is.** `YMIR_HOME` was unset inside
  it, so every runtime path fell back to `$HOME/Documents/ymirhome`, which is not
  mounted. The well found no engram (`Mimir bridge: not up (needs engram)`), the
  visualizer found no smithy DB
  (`smidja.db not found at /home/bun/Documents/ymirhome/smidja/smidja.db` while the
  mounted hoard sits at `/home/bun/Documents/Ymir`), the cron status read the wrong
  state directory, and migrations reported pending.
- **The harness config (`~/.pi`) was not mounted at all**, so `models-registry`
  reported FAIL on a healthy install: the model registry and the MCP server list the
  smoke test probes live there.

### What
- The quadlet mounts `%h/.pi`.
- The operator's home is given to the container through its own env file
  (`YMIR_HOME=/home/bun/Documents/Ymir`), and recorded on the host at
  `~/.config/ymir/home` so every host script resolves it too.

**A note on the two names.** The package's one default is
`$HOME/Documents/ymirhome`; this seat's home is `$HOME/Documents/Ymir`. That is not a
fault in either, it is why the recorded choice exists: the resolver is
env → the recorded choice → the default, and this machine's choice is now written
down rather than resting on a name that was never true here.

**Local choices, not the package's.** This seat's installed unit also publishes the
tailnet addresses and runs `scripts/start.sh --foreground`. Those stay local; only
the two mounts above are the package's business.

### Files
- `deploy/quadlet/ymir.container`
