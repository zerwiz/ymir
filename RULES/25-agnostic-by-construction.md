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

## 2026-10-18 (appended) — the instance that proves the rule, found the day after it was written

**A derived artifact broke "PATHS RESOLVE, NEVER HARDCODE" in the one place nobody
reads.** On 2026-10-18 a session added `bin/agents/skill-index.sh` — a generated
index of every skill a machine holds — and committed its output into the **home
repo, which syncs to every machine**. The index wrote each skill's `path`
**absolute**: **192** entries under `/home/<this-seat>/…`.

On the **second machine (heimdall)** it therefore did not work at all:

- the finder resolved **nothing** — every path named a home that is not there;
- `--check` read the index as **incomplete forever**;
- the **home went dirty on every session**, as the index regenerated against the
  local tree.

The law was already written. What it cost to break it in a *generated file* rather
than in code is the part worth appending: **code is reviewed, and a generated file
is read by nobody and synced to everybody.** A derived artifact is not exempt from
this rule — it is the likeliest place to break it.

**Mended in `zerwiz/ymir` #354 and the home `12981df`:**

- the index stores `path` **relative to the shelf root** named by its `shelf`
  (`ships · local · home · pi`), and the **reader anchors it to its own machine**;
- the index and its human twin are **untracked and gitignored in the home**, beside
  `.ymir-layout.yaml` — a per-machine map must not travel;
- `stat` is **probed** (`-c %Y` → `-f %m`), never assumed, so the freshness check
  travels to BSD/macOS;
- `.agents/tests/skill-index.test.sh` **fails the build if a machine path ever
  reappears in the index** — the ward the "A MOVE IS A MIGRATION" clause asks for,
  applied to a generated file.

**The sentence to carry forward:** *any file a machine generates for itself belongs
to that machine — keep it out of the shared tree, or keep it relative.*
