## runtime · unversioned · 2026-10-20 — the machine is probed, and names collide by rule

### What

Two gaps closed in the same change:

1. **`bin/agents/profile.sh`** — `probe|show|check` writes
   `hodd/identity/profile.yaml`: os, distro, arch, cores, RAM, GPU, free disk, the
   presence of git/docker/node/pi/tailscale/ffmpeg/whisper-cli, and capability flags
   (`containers`, `gpu_cuda`, `tailnet`, `meeting_ear`). Install runs `step_profile`
   before the seat name. A missing capability is recorded **absent**, never assumed.
2. **`bin/agents/name-registry.sh`** — scans the naming law, agents, skills,
   extensions, hosts, seat personas and `hodd/identity/reserved-names.txt` into one
   `names.yaml`, and refuses a seat persona that takes an infrastructure name
   (`mimir`, `muninn`, `snotra`, …). `seat-identity.sh set` consults it; install and
   Gróa scan it; Gróa reports a drifted seat.

### Why

The Allfather: *"Every user's fleet and hardware are always different"* and *"Mímir is
a feature — how can a computer be called that?"*. Install must probe before it
installs, and a name must be checked against every other use of that name.

### Verified

- `profile.sh probe` on heimdall: `linux x86_64, 16 cores, 125 GB RAM, RTX A5000
  16 GB, 60 GB free`, docker/pi/tailscale/ffmpeg/whisper-cli present.
- `name-registry.sh scan`: 100 names; `mimir` refused as a persona, `sindri`
  accepted, `heimdall` refused as a host.
- `tests/test_name_registry.sh` — 6 assertions; `tests/test_seat_identity.sh` — 13.
- Install now has `step_profile` and `step_identity` in the step chain.

### Not verified

- No fresh install was run end to end on a bare machine.
- Permissions, decisions and goals are plan 89 P1–P3, not built.
