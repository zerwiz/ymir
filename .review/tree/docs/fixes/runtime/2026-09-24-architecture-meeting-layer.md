## runtime · 2026-09-24 — the meeting layer in the master architecture

### Why
`docs/Architecture.md` is the master map of Ymir's subsystems. The meeting
capabilities landed in code (Snotra, plan 52) and the asset tree, but the
architecture document still described a platform with no meeting layer. A master
map that omits a live subsystem is drift.

### What landed
- **§3.13 The Meeting Layer — Snotra (the ear) & Þing (the room)** — the role
  split by seat (ear / brain / record), the capture and transcription roads, the
  read-only MCP face (`:8321`), the per-seat engine matrix, and the First Law
  (audio and transcripts live in the hoard, never the repo).
- **§2 topology note** — the meeting layer named beside the core.
- **§6 Tech Stack** — PipeWire + ffmpeg (capture), whisper.cpp (transcription),
  MiroTalk P2P (the room) rows.
- **§7 Build Order** — P12, the meeting layer (depends on P2, P4).

### Files
- `docs/Architecture.md`
