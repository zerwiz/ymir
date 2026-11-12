# The kill tracer names cgroup kills, OOM kills and the GPU at each death

**Date:** 2026-11-12 · **Component:** ward · **Door:** `bin/ward/browserkill.bt` · **Plan:** 271 (continues 152)

## What was wrong

Discord died by SIGKILL at 13:56:34 and the trace named no outside sender. Two roads send SIGKILL with no
`kill()` call: a write to `cgroup.kill` (a scope stopped) and the kernel's OOM killer. The old probe saw the
write but never the victim, and nothing recorded what the GPU was doing.

## What was forged

- `bin/ward/browserkill.bt` (the old probe plus two): `CGKILL` names the writer and the unit whose cgroup
  was killed; `OOMKILL` names the victim.
- `bin/ward/browserkill-note.sh` writes, at each kill, the GPU's compute and graphics processes and the user
  manager's recent scope endings.
- `bin/ward/browserkill-install.sh` seats the probe and a `browserkill-note.service`. It needs root, so the
  operator runs it with sudo; `--check` says whether the seated probe is stale.

## What was seen in the 13:56:34 trace

The line before the death reads `SEND sig=9 from=pipewire-main-l(212514)`: a thread of Discord's own
process sent the kill. That points at Discord ending itself when its audio device changed under it, which
fits the microphone breaking just before.

## Not verified

The probe needs root, so it was not loaded here. The two kernel symbols (`cgroup_kill_write`,
`oom_kill_process`) exist on this kernel and BTF is present. The note script is tested on planted lines
(`bin/ward/tests/test_browserkill_note.sh`).

## Appended — this is the ledger's faults C and D

The crash ledger (`hodd/machines/heimdall/plans/0003-the-crash-ledger-of-heimdall.md`) keeps four faults
apart. The 13:56:34 Discord death is its **fault C**: Discord's own process dies inside its PipeWire thread
(`SEND sig=9 from=pipewire-main-l`), with no outside hand. The cgroup and OOM probes added here cover the
roads that fault does not explain (the Firefox deaths at 13:29 and 13:33 with no kill syscall). The GPU note
helps **fault D** (sound or voice gone with no process dying): the card's processes are written at the same
second as the death. The guard's `inputs` count and Rödd's loss records give D the same kind of record.

## CHANGE LOG

- **2026-11-12** — written (Eindri `desk-stays-whole`); change-log section added at the gather so the append-only ward can judge the note.
