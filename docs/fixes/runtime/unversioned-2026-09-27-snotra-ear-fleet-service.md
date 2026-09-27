# 2026-09-27 — the door fronts the strong ear (snotra's engine becomes a fleet service)

## What

- Plan 51 Parts 9a/9c made snotra's split law: the heart fronts the DOOR
  (`:8321`) and a STRONG box carries the HEARING (zerwizserver's GPU cannot run
  whisper). The cutover left `snotra.service` unseated on the heart and
  `mill-worker` idle fleet-wide; nothing carried the ear.
- New `bin/snotra-ear.sh` — the ear on a strong box: discovers the seat's
  whisper engine + model, picks the device by free VRAM, and serves upstream
  whisper.cpp's own `whisper-server` HTTP face (`GET /health`, `POST
  /inference`) on `:8322`. No bespoke inference code; the upstream binary is the
  engine.
- New `tools/mill/systemd/snotra-ear.service` — the unit, `WantedBy=ymir.target`.
- `bin/autoboot-lib.sh` gained the CAPABILITY axis: a program owed by what a
  seat *can do*, not by its role. `snotra-ear` is owed iff the seat has a
  whisper engine **and** a model (`snotra-ear.sh status`), so the heart reports
  a clean skip and never loads whisper; a dev/forge box with a GPU owes it. The
  raise, the proof (`ymir-autoboot.sh verify`), and `purge_stale_units` all read
  the same table, so they cannot disagree.
- `bin/fleet-ensure.sh` materializes the ear script with the other snotra
  commands, knows its unit template, and raises it on that capability.
- `tools/snotra/server.mjs` (the door) now carries the hearing:
  `snotra_transcribe` (base64 clip → multipart POST to the live ear) and
  `snotra_ear` (where the hearing stands now). Resolution is LIVE: the candidate
  order is the fleet registry's `ear` row (private, runtime — no URL in the
  repo), first-heimdall then whynot then omarchy; a box that fails a POST is
  EJECTED for a spell and the next live box takes the request, so a dead or
  aborting engine is a reroute, never an outage. The JSON-RPC body cap rose from
  2 MB to 64 MB: the audio lane rides the door.
- `bin/snotra-transcribe.sh` — the VRAM probe no longer feeds `nvidia-smi`'s
  driver complaint into an integer comparison (a driverless seat's stdout text
  reached `[ -ge ]`); only digits survive the probe now.

## Why

A door that answers while the engine lives elsewhere must (a) resolve that
engine at request time, (b) never confuse a listening port with a working ear,
and (c) never make the heart carry inference it cannot run. Measured facts that
forced the shape:

- whynot's whisper **CUDA build aborts** on its Quadro P2000 (`CUDA error: no
  kernel image is available for execution on the device`; core-dumped, status
  6/ABRT) while `/health` still answers — hence the ejection-and-reroute on a
  failed POST, not merely on a dead port. Its CPU path transcribes correctly, so
  the seat carries a drop-in (`SNOTRA_EAR_GPU=off`) until the build is mended
  with `GGML_CUDA_ARCHS=61`.
- `fleet.json` gained an `ear` row (`["heimdall","whynot","omarchy"]`) — the
  live set, resolved from each host's own address.

## Verified

- `initialize` → `tools/list` on `http://zerwizserver.tailefab81.ts.net:8321/mcp`
  answers: server `snotra 0.2.0`, **6 tools** (`snotra_list`, `snotra_read`,
  `snotra_search`, `snotra_summary`, `snotra_ear`, `snotra_transcribe`).
- A piper-generated 2.6 s clip (`The raven flies at dawn over the cold sea.`)
  posted through the door came back verbatim with provenance `[ear=heimdall]`.
- Reroute proven by dropping heimdall's ear: `snotra_ear` resolved **whynot**,
  and the same clip came back `[ear=whynot]` (CPU) in ~2.8 s wall clock.
- The heart carries no whisper (`command -v whisper-cli` absent; `:8322` not
  listening) while `:8321` is up — the door answers without local inference.
- `.agents/skills/lifecycle/smoke_test.sh`: `"mcp:snotra","OK","connected — 6
  tools (http://zerwizserver.tailefab81.ts.net:8321/mcp)"`.

## Files

- `bin/snotra-ear.sh` — new: the ear engine served to the fleet
- `tools/mill/systemd/snotra-ear.service` — new: the unit
- `tools/mill/systemd/snotra.service` — description now names both faces
- `bin/autoboot-lib.sh` — the capability axis (`snotra-ear`)
- `bin/fleet-ensure.sh` — materialize + unit template for `snotra-ear`
- `tools/snotra/server.mjs` — live ear resolution, `snotra_transcribe`,
  `snotra_ear`, POST-failure ejection, 64 MB body cap
- `bin/snotra-transcribe.sh` — numeric-safe VRAM probe
- `.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md` — the asset law
- `.agents/skills/galdr-ymirsystem/assets/{registry,runtime-components,installation,README}.md` — inventories
