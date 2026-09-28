## skills · unversioned · 2026-09-28 — maestro-video — the public video forge and the setup-for-users road

### Why
The operator has a working local video forge (Maestro v2.4.2) and a PRIVATE skill
for his own door, defaults, brand pack and output shelf — but no PUBLIC skill. So
no other seat or user could ride the forge, and nothing in the repo could stand
one up: the provision road (GPU gate, user unit on ymir.target, the
MAESTRO_LLAMA_BIN trap, loopback-only) existed only as one box's notes. The
public craft and the provision seam were unmade.

### What
- **The craft** (`.agents/skills/maestro-video/SKILL.md`): how an agent calls the
  door — the verb table, the check→generate→poll→collect flow, prompting as one
  shot, ffmpeg assembly (conform/pad → concat → denoise+grain), the VO (the seat's
  own piper where present, else honestly silent with the script beside it), output
  to the HOARD's video shelf, and cost awareness (one family resident, frame caps,
  measured timings). The brand pack is **pointed at, never copied**: the
  Allfather's pack lives in the private skill under `$YMIR_HOME`; the public skill
  ships only a generic prompt template.
- **The measured API reference** (`assets/maestro-api.md`): every verb probed
  live with `curl` against Maestro v2.4.2 (190 OpenAPI paths), with the response
  bodies quoted as returned, plus a **Traps** table of the wrong-but-plausible
  paths (`/downloads/status` → 404; `/jobs/{job_id}` is DELETE, not a read; a
  family id is not a `model_type`).
- **The provision road** (`assets/setup-for-users.md` + `assets/maestro.service`):
  the strong-box doctrine (plan 51 Part 9a — a weak seat never runs inference),
  the hard GPU gate, the hand-reproduced Pinokio install, the systemd user unit
  (`WantedBy=ymir.target`, `Restart=always`, `TimeoutStartSec=900`,
  `MAESTRO_LLAMA_BIN`/`MAESTRO_LLM_CACHE`), the declare-families hook
  (`model-visibility`), the verify curl, and the privacy rule (loopback-only,
  never a tunnel).
- **The seam** (`bin/maestro-ensure.sh`): `status | detect | ensure | verify` —
  gates the box, renders the unit, seats it, proves `/api/v1/models`, and
  **refuses loudly** (writing nothing) on a GPU-less box or a llama dir with no
  CUDA server. Verified: `bash -n` clean, `detect` gated live, `status` reported
  `17` families / `206` model_types / `1` downloaded, `verify` returned 0 at the
  live door, and a sandboxed `ensure` rendered the unit correctly for a tree
  under `$HOME` (identity `%h/...`) and outside it (absolute) — a
  `%h//tmp/app` render fault was found in test and fixed.

### Proof (live)
A real generation completed end-to-end on the seat's RTX A5000 Laptop:

```
POST /api/v1/generate  → {"job_id":"527bc6ec","status":"queued"}
GET  /api/v1/status/527bc6ec → running → Loading model → Encoding Prompt →
                              Denoising First Pass → Denoising Second Pass →
                              completed, 100, Done      (~94 s)
GET  /api/v1/file/<output_files[0]> → 200 video/mp4, 1,003,261 bytes
ffprobe → h264 + aac · 832x448 · 25 frames · 1.000 s
          (asked 832x480 — the model snapped to its architecture grid)
```

### Files
- `.agents/skills/maestro-video/SKILL.md`
- `.agents/skills/maestro-video/assets/maestro-api.md`
- `.agents/skills/maestro-video/assets/setup-for-users.md`
- `.agents/skills/maestro-video/assets/maestro.service`
- `bin/maestro-ensure.sh`
- `.agents/skills/README.md`
- `.agents/skills/galdr-ymirsystem/assets/installation.md`
