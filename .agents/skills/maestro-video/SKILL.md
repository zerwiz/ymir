---
name: maestro-video
description: >-
  Maestro — the local AI video forge. Drive a self-hosted Maestro v2.x server
  (text-to-video, image-to-video, music, voice, editing) over its REST API on
  http://127.0.0.1:7860/api/v1: check a model family, generate one shot per
  call, poll the job, collect the clip, assemble with ffmpeg, lay the VO. Also
  the provision road — Ymir stands Maestro up for a user: GPU-gated user unit
  on ymir.target, loopback-only, model families declared per seat. Use when the
  task is AI video generation, a brand film, a shot pack, a motion asset, or
  raising the video forge on a machine. Keywords — video, maestro, ai video,
  text-to-video, t2v, image-to-video, i2v, wan, hunyuan, ltx, minimax, longcat,
  kandinsky, flux, ffmpeg, brand film, shotlist, forge, setup.
argument-hint: "[generate | shotlist | assemble | setup | status]"
---

# maestro-video — the AI video forge

**Maestro** is a self-hosted generative-video server (the open Maestro / WanGP
lineage): one FastAPI process that serves a web UI **and** a full REST API, with
its own job queue, model downloader, LoRA manager, editor and audio studio. This
skill is the craft of **riding that door** — and of **standing it up** for a
user who has none (see `assets/setup-for-users.md`).

Nothing here is a mock. The verb table below was measured against a live
**Maestro v2.4.2** with `curl`, and the worked example at the bottom is a real
generation that completed.

## The door

One process, one port. Default `http://127.0.0.1:7860`; the root is the SPA, the
craft lives under **`/api/v1`**. The API is self-describing:

| what | how |
|---|---|
| OpenAPI spec | `GET /openapi.json` (this box: 190 paths) |
| interactive docs | `GET /docs` |
| health | any `GET /api/v1/models` that returns `200` |

```
maestro_door[10]{verb,path,use}:
  "models","GET  /api/v1/models","the families and every model_type; read models[].is_downloaded BEFORE you generate"
  "resolutions","GET  /api/v1/resolutions","the true geometry list (16:9 · 9:16 · 21:9 · 1:1 · 4:3) with label + value"
  "defaults","GET  /api/v1/defaults/{model_type}","that model's own default settings — START HERE, then override only what you mean to"
  "options","GET  /api/v1/model-options/{model_type}","capabilities: guidance_max_phases · sliding_window · returns_audio · supports_end_frame · steps min/max"
  "generate","POST /api/v1/generate","submit a job; returns {job_id,status} immediately"
  "status","GET  /api/v1/status/{job_id}","the job: status · progress · message · output_files; poll this, NOT /jobs/{id}"
  "jobs","GET  /api/v1/jobs","the job list (GET /api/v1/jobs/{job_id} is DELETE — dismiss, not read)"
  "download","POST /api/v1/models/{model_type}/download","fetch a family; watch GET /api/v1/models/downloads/status"
  "file","GET  /api/v1/file/{filename}","stream the finished media (video/mp4) — the collect verb"
  "music","POST /api/v1/director/generate-music","score, when the model set supports it"
```

Job control: `POST /api/v1/cancel/{job_id}` · `POST /api/v1/jobs/{job_id}/retry` ·
`DELETE /api/v1/jobs/{job_id}` (dismiss) · `POST /api/v1/jobs/queue/start` ·
`GET /api/v1/jobs/{job_id}/enhancement`.
Machine truth: `GET /api/v1/system-detect` (GPU · VRAM · capability · tier — the
detect verb) · `GET /api/v1/system-stats` · `GET /api/v1/system/preflight`
(`{"ok":true,"checks":[]}` when the seat is sound).
LoRAs: `GET /api/v1/loras/{model_type}` · `POST /api/v1/loras/generate-guide` ·
`POST /api/v1/checkpoints/{model_type}/generate-guide`.

Two traps this table exists to prevent, both measured:

- **A family id is not a `model_type`.** `/api/v1/models` returns
  `families[]` (`wan`, `wan2_2`, `hunyuan_1_5`, `ltxv`, `ltx25`, `ltx2`,
  `kandinsky5`, `minimax_h3`, `longcat`, `flux`, `flux2`, `qwen`, `z_image`,
  `hidream`, `tts`, `krea2`) **and** `models[]`, where each entry carries the
  `model_type` you must actually pass (`ltx2_22B_distilled_1_1`, `ti2v_2_2`,
  `i2v_2_2`, `hunyuan_1_5_t2v`, `minimax_h3`, `qwen_image_20B`, …). Passing a
  family id (`/api/v1/model-options/wan`) answers `404 Unknown model: wan`.
- **There is no `/api/v1/downloads/status`.** It is
  `GET /api/v1/models/downloads/status`; `GET /api/v1/downloads/active` is the
  live transfers.

Full measured reference, with a curl per verb: **`assets/maestro-api.md`**.

## The flow — check, generate, poll, collect

```
flow[4]{n,step,do}:
  1,"CHECK","GET /api/v1/models → find your model_type and confirm is_downloaded; if false, POST /api/v1/models/{model_type}/download and watch /api/v1/models/downloads/status"
  2,"GENERATE","GET /api/v1/defaults/{model_type} for the model's own geometry, override prompt/resolution/video_length/seed, POST /api/v1/generate → {job_id}"
  3,"POLL","GET /api/v1/status/{job_id} on a slow cadence; read .status (queued|running|completed|failed) and .message; on completed read .output_files[]"
  4,"COLLECT","GET /api/v1/file/<url-encoded output_files[0]> → the media; or read the app's own outputs shelf"
```

The poll cadence is **not** a tight loop: a first-pass load of a 22B video model
is minutes. Poll every 15–30 s and read `message` — it names the phase
(`Loading model …`, `Encoding Prompt`, `Denoising First Pass`, `Denoising Second
Pass`) and `eta_*` fields once the forge has samples.

**Do not assume the geometry you asked for is the geometry you get.** Video
models snap to their architecture's grid. A request for `832x480` on LTX-2 came
back **832x448**. Always read the finished file rather than trusting the ask:

```bash
ffprobe -v error -show_entries format=duration \
  -show_entries stream=codec_name,width,height,nb_frames \
  -of default=noprint_wrappers=1 clip.mp4
```

## Prompting

A prompt is a **shot**, not a synopsis. One camera, one action, one light. Write
in this order — subject · action · camera · light · palette · texture · sound:

```
prompt_template[7]{field,example}:
  "subject","a single figure, what they are and what they wear"
  "action","the ONE thing that moves in this shot"
  "camera","the move and the lens: slow push-in, locked-off wide, low dolly"
  "light","the source and its direction: ember glow from below, hard key from the left"
  "palette","two or three colours, named plainly"
  "texture","film grain, wet stone, hammered metal — the tactile read"
  "sound","the bed: low strings, distant hammers, wind"
```

Then two laws of the craft:

- **Say "no readable text"** unless you want generated glyphs — diffusion video
  invents plausible alphabets, and they fail on close inspection.
- **One idea per clip.** If a shot needs two beats, that is two clips and a cut.

**For Ymir's own brand, never improvise.** The Allfather's prompt pack — master
prompt, eight-shot pack, and VO script — is private and lives at
`$YMIR_HOME/.agents/skills/maestro-video/assets/ymir-brand.md`, beside the
private skill that owns his door, defaults and output shelf. Read it there and
use it as written; this public skill only points at it, and copies none of its
text (a public repo carries no private material). If that path is absent, the
operator has no brand pack — use the generic template above and ask.

## Assembly — the clips are raw material

The forge returns **clips**, each its own job. The film is made afterwards, with
`ffmpeg`, deterministically:

```bash
# 1. conform every clip to the film canvas (16:9 shown; keep the audio)
ffmpeg -i shot_01.mp4 -vf "scale=1920:1088:force_original_aspect_ratio=decrease,pad=1920:1088:(ow-iw)/2:(oh-ih)/2:color=black" \
       -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 -r 25 conf_01.mp4

# 2. join in shot order (the concat demuxer, not a re-encode chain)
printf "file 'conf_%02d.mp4'\n" 1 2 3 4 5 6 7 8 > shots.txt
ffmpeg -f concat -safe 0 -i shots.txt -c copy film.mp4

# 3. the finish: a light denoise, then subtle grain
ffmpeg -i film.mp4 -vf "hqdn3d=1.5:1.5:6:6,noise=alls=6:allf=t+u" -c:v libx264 -crf 18 -c:a copy film_final.mp4
```

Keep the palette and the grain **the same across every clip** — a film whose
shots were graded differently reads as stock footage, not a work. `-r 25` is a
safe conform rate; the forge's own music geometry is 25 fps
(`POST /api/v1/director/music-clip-limits` → `fps 25.0`, `frames_minimum 17`,
`frame_step 8`, `hard_max_frames 497` — so durations quantise to 17, 25, 33, …).

## The voiceover

Lay the VO **locally**, never through the forge unless you mean to:

1. **Prefer the seat's own TTS.** Where `piper` is present, read the script with
   the operator's own voice — `piper --model <voice.onnx> --output_file vo.wav`
   (a seat that keeps a voice switcher, e.g. `~/.local/bin/piper-voice` or a
   `voice` helper, uses that). Piper voice models are small and local.
2. **Else synthesise nothing and say so.** A seat with no TTS renders the film
   **silent** and ships the script beside it as `_vo.md` — a stranger's synthetic
   voice is worse than a clean silent cut. Do not reach for a hosted TTS API to
   fill the gap.
3. **One voice, deliberate pace.** Add a short lead-in before the first word and
   ~1 s of tail; duck the music bed under the voice with
   `ffmpeg -filter_complex "[1:a]volume=0.25[m];[0:a][m]amix=inputs=2:duration=first"`.

If the model supports audio (`returns_audio: true` in `/model-options`), the
forge may return a native track — keep it if it serves, else replace it with the
VO layer above. Music, when wanted, is its own verb:
`POST /api/v1/director/generate-music`.

## Output — the hoard, never the repo

The finished film goes to the operator's **private** shelf, never into a public
repo tree:

```
$YMIR_HOME/hodd/workspaces/marketing/video/<YYYY-MM-DD>-<slug>.mp4
$YMIR_HOME/hodd/workspaces/marketing/video/<YYYY-MM-DD>-<slug>_shotlist.md
```

Write the `_shotlist.md` beside it: one row per clip — the `model_type`, the
prompt, the seed, the job id, the fps and the measured geometry. The shotlist is
the film's provenance; a clip nobody can trace is a clip nobody can re-cut. The
forge's own shelf (`<app>/outputs/`) is scratch — collect from it, then file the
work in the hoard.

## Cost awareness

A local video job is **minutes to tens of minutes of GPU time**, and the models
are **tens of gigabytes**. Respect the box:

- **One family resident.** These are not co-resident models; a request evicts
  the last. Never fan out parallel generations — queue them, and let one finish.
- **Cap the frames.** `video_length` is in frames at the model's fps. 25 frames
  ≈ 1 s. A 5 s shot at 25 fps is ~121 frames. Ask for the seconds you need.
- **Batch the shots, then assemble.** Eight 4-second clips beat one 32-second
  request: you can re-cut one bad shot without paying for the other seven.
- **The first step is the expensive one.** Model load dominates a short clip: a
  25-frame 832×448 LTX-2 job measured **~94 s end-to-end**, most of it loading.
  A full-length default run (241 frames, two passes) measured **~25 minutes** on
  one 16 GiB card. Size the ask to the deadline.
- **Check disk before downloading a family.** `app/ckpts` on a single seat held
  **49 GB** with one video family plus its encoder. `GET /api/v1/system-detect`
  and `GET /api/v1/models/downloads/status` tell you before you commit the space.

## Standing the forge up for a user

Ymir provisions Maestro for a seat — GPU-gated, as a user unit on `ymir.target`,
**loopback-only**. The whole road (detect → install → declare families → verify →
the privacy rule), with the unit template and an ensure-script seam, is
**`assets/setup-for-users.md`**. Read it before running anything on a machine
that has no forge.

## Proof of the craft

A worked, measured generation (Maestro v2.4.2, RTX A5000 Laptop, 16 GiB):

```
proof[6]{step,command,result}:
  "check","GET /api/v1/models","206 models, 17 families; ltx2_22B_distilled_1_1 present (is_downloaded true)"
  "defaults","GET /api/v1/defaults/ltx2_22B_distilled_1_1","settings_version 2.58 · resolution 1280x720 · video_length 241 · num_inference_steps 8"
  "generate","POST /api/v1/generate (832x480 · 25 frames · 8 steps · seed 42)","200 → {job_id: 527bc6ec, status: queued}"
  "poll","GET /api/v1/status/527bc6ec","running → Loading model … → Encoding Prompt → Denoising First Pass → Denoising Second Pass → completed, 100, Done"
  "collect","GET /api/v1/file/<output_files[0]>","200 video/mp4 — 1,003,261 bytes"
  "verify","ffprobe","h264 + aac · 832x448 · 25 frames · 1.000 s  (asked 832x480; the model snapped to its grid)"
```

A finished film is the real proof: the `.mp4` plays, the `_shotlist.md` names
every clip's model, prompt and seed, and the VO is one deliberate voice — local,
or honestly silent with the script beside it.
