# 25 — Agnostic by construction: one core, every device

**Appended 2026-10-18** at the Allfather's word: *"this must be a rule in ymir — we can't develop
with one device in mind. we are multi-device and hardware and operating system… we need to be
agnostic."*

**Why it exists, from this day's own wounds.** A reorganisation moved the scheduled jobs from
`bin/nornir-job-*.sh` to `bin/time/`  # allow-superseded-path: this sentence RECORDS the move and the operator's own cron kept the old spellings for
**three weeks**, because a home is not a checkout and nothing carried the change to it. On the same
day the warden was written reading `/etc/ufw` and `systemd`, the editor door was written against
Hyprland 0.56, and a rule was written that named `apps/` as if every machine had one. Rule **05**
says a core change updates every platform layer. This rule says the harder thing: **we may not
write, name, or move anything with one machine in mind in the first place.**

```
agnostic_law[8]{rule,what it means}:
  "THREE AXES, ALWAYS","device (laptop · phone · server · heart) · hardware (GPU · CPU · RAM · disk) · operating system (Omarchy/Arch · Debian · macOS · Windows/WSL · Android/Termux). A design that names none of them has assumed one."
  "PROBE, NEVER ASSUME","capability is discovered at run time (a GPU, a window manager, a package manager, a cron, a vault, python's zoneinfo) and the answer decides the path — never a hardcoded `/etc/…`, `systemctl`, `pacman`, `apt`, `hyprctl`, or `docker` on a machine that may have none."
  "A CLEAN SKIP IS A PASS","a layer that does not apply reports SKIP with the reason and exits 0. A capability that fails on another platform is a bug; a capability that PRETENDS is a lie."
  "ONE CORE, THIN LAYERS","the portable core (POSIX shell · python3 · git) does the work; each OS gets its own layer for what is genuinely theirs. A core change ships the layer change in the same commit (Rule 05), or the layer is drift."
  "A MOVE IS A MIGRATION","renaming or moving anything a machine may reference — a script, a unit, a config key, a shelf — ships, in the same change: the new path, a MIGRATION that heals existing homes and seats (.agents/migrations/), and a WARD that would have caught it. A move without those is a promise to break somebody's morning."
  "PATHS RESOLVE, NEVER HARDCODE","configuration comes from env → the recorded choice → one documented default (Rule 07). A machine's home, ports, hosts and seats are resolved, never assumed; a path that exists on this box is not a path."
  "THE LEDGER REMEMBERS WHAT MOVED",".agents/paths-ledger.yaml holds every path that has moved, with old → new and the date. The shipped tree may not reference a superseded path; the ledger is how the tree knows."
  "THE TEST IS A MACHINE THAT IS NOT THIS ONE","can a fresh clone + install reach a working seat on a device we do not own? If the answer is 'as long as it is this laptop', the work is not done."
```

**Enforced by** `bin/gates/guards/path-ledger-guard.sh` (no shipped file may reference a superseded
path from the ledger) · the platform layer probes (`bin/fleet/ymir-platform.sh`, `bin/host/*-sense.sh`)
· the clean-skip convention every `*-ensure.sh` follows · and `bin/engine/ymir-migrate.sh`, which
runs the migrations that heal an existing home.
