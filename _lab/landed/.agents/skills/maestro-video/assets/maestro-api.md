# Maestro REST API — the measured reference

**Source of truth:** a live **Maestro v2.4.2** (`Maestro API 1.0.0`), probed with
`curl` on 2026-09-28. Every verb, path and response body below was executed; the
shapes are quoted from what came back, not from a doc. Where a plausible-looking
path is **wrong**, it is listed in *Traps* so nobody repeats it.

Set the base once:

```bash
B=${MAESTRO_URL:-http://127.0.0.1:8761}     # the door (auth proxy → forge on 7860)
```

The service is FastAPI: `GET /openapi.json` is the complete, machine-readable
contract (**190 paths** on v2.4.2), and `GET /docs` is the interactive page. When
this asset and the running server disagree, **the server is right** — re-probe.

---

## 1. Discovery

### `GET /api/v1/models` — families and every model_type

```bash
curl -s "$B/api/v1/models" | python3 -c '
import json,sys
d=json.load(sys.stdin)
print("families:", len(d["families"]), "models:", len(d["models"]))
print("downloaded:", [m["model_type"] for m in d["models"] if m.get("is_downloaded")])'
```

Measured: `17` families, `206` models. Two different id spaces live in this one
payload — do not conflate them:

- `families[]` → `{id,label,order}`: `wan` (Wan2.1), `wan2_2` (Wan2.2),
  `hunyuan`, `hunyuan_1_5`, `ltxv` (LTX Video), `ltx25` (LTX-2.5), `ltx2`
  (LTX-2), `kandinsky5`, `minimax_h3`, `longcat`, `flux`, `flux2`, `qwen`,
  `z_image`, `hidream`, `tts`, `krea2`.
- `models[]` → the **`model_type`** you pass to every other verb, plus its
  capabilities: `model_type`, `name`, `description`, `family`, `architecture`,
  `is_i2v`, `is_t2v`, `fps`, `supports_end_frame`, `supports_audio`,
  `requires_image_reference`, `is_downloaded`, `loras_disabled`, and a nested
  `director{}` block describing which director workflows the model can carry.

Examples of real `model_type` values: `ltx2_22B_distilled_1_1`, `ltx2_25`,
`ti2v_2_2`, `i2v_2_2`, `hunyuan_1_5_t2v`, `hunyuan_1_5_i2v`, `minimax_h3`,
`minimax_h3_ref2va`, `qwen_image_20B`, `flux2_klein_9b`, `z_image`, `vace_14B`,
`ace_step_v1_5`.

### `GET /api/v1/resolutions` — true geometry

```bash
curl -s "$B/api/v1/resolutions"
```

Returns `{"resolutions":[{"label":"1920x1088 (16:9)","value":"1920x1088"}, …]}`.
Measured set (abridged): `1920x1088` · `1280x720` · `960x544` · `832x480` (16:9);
`1088x1920` · `720x1280` · `544x960` · `480x832` (9:16); `1920x832` · `1280x544`
· `832x1920` (**21:9 is 832 high, not 816**); `1024x1024` · `960x960` · `720x720`
· `512x512` (1:1); `1104x832` (4:3) · `832x1104` (3:4); `832x624` · `624x832`.
The list ends with one `{"label":"","value":""}` entry — skip empties.

**Not every model accepts every resolution.** The model snaps to its own grid:
`832x480` on LTX-2 produced **832x448**. Verify the file with `ffprobe`.

### `GET /api/v1/system-detect` — the machine (the detect verb)

```bash
curl -s "$B/api/v1/system-detect" | python3 -m json.tool
```

Measured on an RTX A5000 Laptop:

```json
{"hardware":{"cuda_available":true,"gpu_name":"NVIDIA RTX A5000 Laptop GPU",
 "gpu_vram_gb":15.6,"gpu_capability":"sm86","ram_gb":125.0,"cpu_count":16,
 "ram_tier":"high","vram_tier":"low","supports_fp8":false,"supports_nvfp4":false,
 "supports_sage":true,"supports_sage2":false,"supports_flash":true,
 "supports_triton":true},
 "recommended":{"video_profile":2,"image_profile":2,"audio_profile":3,
 "transformer_quantization":"int8","vae_config":0,"vram_safety_coefficient":0.8,
 "attention_mode":"auto","compile":"","_recommendation_label":"Profile 2 — Balanced …"},
 "auto_enabled":true}
```

This is the honest answer to *"can this seat run the forge?"* — `cuda_available`,
the capability class (`sm86`, `sm89`, …), `vram_tier`, and the profile it
recommends. Companion verbs: `GET /api/v1/system-stats` (live cpu/ram/vram
percent) and `GET /api/v1/system/preflight` → `{"ok":true,"checks":[]}`.

---

## 2. Model preparation

### `GET /api/v1/defaults/{model_type}` — start from the model's own defaults

```bash
curl -s "$B/api/v1/defaults/ltx2_22B_distilled_1_1" | python3 -m json.tool | head -20
```

Measured: `settings_version 2.58` · `prompt` · `resolution 1280x720` ·
`video_length 241` · `num_inference_steps 8` · `guidance_phases 1` ·
`flow_shift 5.0` · `sliding_window_size 481` · `sliding_window_overlap 17` ·
`denoising_strength 1.0` · `audio_scale 1.0`. Take these as the base and override
only what you mean to change.

### `GET /api/v1/model-options/{model_type}` — capabilities

```bash
curl -s "$B/api/v1/model-options/ltx2_22B_distilled_1_1"
```

Measured: `guidance_max_phases 2` · `lock_guidance_phases true` ·
`sliding_window true` · `returns_audio true` · `any_audio_prompt true` ·
`supports_end_frame true` · `inference_steps_min 1` / `max 50` ·
`lock_inference_steps true` · `i2v_class false` · `t2v_class false` ·
`no_negative_prompt false`.

Read this **before** building a request: `lock_*` fields are the forge telling
you which knobs it will ignore for this architecture.

### `GET /api/v1/models/{model_type}/debug` — resolved weights

```bash
curl -s "$B/api/v1/models/ltx2_22B_distilled_1_1/debug"
```

Measured: `{"model_type":"…","keys":{"text_encoder_folder":"gemma-3-12b-it-qat-q4_0-unquantized","text_encoder_URLs":"…", …}}`
— the resolved folder and URL per dependency. This is how you tell *what a
generation will actually load*, and therefore what it will download.

### Downloads

```bash
curl -s -X POST "$B/api/v1/models/ltx2_25/download"     # fetch one family
curl -s "$B/api/v1/models/downloads/status"             # {"downloads":{}}
curl -s "$B/api/v1/downloads/active"                    # {"downloads":[]}
```

`models/downloads/status` is the per-model map; `downloads/active` is the live
transfer list. Downloads are **bursty** — a stalled-looking transfer can resume
seconds later; judge progress over ≥60 s, never over one sample.

---

## 3. Generate

### `POST /api/v1/generate` — submit a job

Takes a JSON body; **returns immediately** with the job id. Minimal working
request (this exact body produced job `527bc6ec`):

```bash
curl -s -X POST "$B/api/v1/generate" -H 'Content-Type: application/json' -d '{
  "model_type": "ltx2_22B_distilled_1_1",
  "prompt": "Rune-carved obsidian and hammered steel: a dwarf works the bellows at the root of a colossal ash-tree, sparks hardening into glowing gold runes. Slow mythic camera push, ember-orange and deep obsidian-blue, subtle film grain, no readable text.",
  "negative_prompt": "",
  "resolution": "832x480",
  "video_length": 25,
  "num_inference_steps": 8,
  "guidance_phases": 1,
  "flow_shift": 5.0,
  "sliding_window_size": 25,
  "sliding_window_overlap": 5,
  "seed": 42,
  "settings_version": 2.58,
  "generation_mode": "video"
}'
```

```json
{"job_id":"527bc6ec","status":"queued","client_submission_id":null}
```

Request keys, measured across the shipped default profiles:

```
generate_body[9]{key,meaning}:
  "model_type","which model (from models[].model_type) — REQUIRED in practice"
  "prompt","the shot, written as one shot"
  "negative_prompt","what to keep out; omit when model-options says no_negative_prompt"
  "resolution","a value from GET /api/v1/resolutions — the model may still snap it"
  "video_length","frames at the model's fps (25 frames ≈ 1 s at fps 25)"
  "num_inference_steps","denoise steps; honour inference_steps_min/max from model-options"
  "guidance_phases","how many guidance phases; max is guidance_max_phases"
  "flow_shift","architecture-dependent shift (LTX-2 default 5.0; Hunyuan 1.5 t2v 9.0)"
  "seed","integer; the same seed and body reproduces the clip — record it"
```

Model-specific keys seen in the shipped profiles: `sliding_window_size`,
`sliding_window_overlap`, `sliding_window_discard_last_frames` (long-video
models), `image_prompt_type` / `video_prompt_type` (i2v and control models),
`denoising_strength`, `masking_strength` (editing models), `audio_scale`,
`perturbation_layers`, `alt_prompt`. `settings_version` is stamped by the server
when absent; send the model's own value (from `/defaults`) so saved presets are
not mistaken for an older contract.

The endpoint also accepts a **serial auto-planner** path — when the request asks
the forge to plan its own shots, submission is deferred and a
`client_submission_id` makes it idempotent. Ordinary single-shot calls take the
immediate path above.

### `GET /api/v1/status/{job_id}` — poll

```bash
curl -s "$B/api/v1/status/527bc6ec" | python3 -m json.tool
```

Measured field set: `job_id` · `kind` · `status` (`queued|running|completed|
failed`) · `progress` (0–100) · `message` · `phase` · `output_files[]` ·
`current_clip` / `total_clips` · `current_window` / `total_windows` ·
`clip_estimates[]` (`{"clip":1,"status":"completed","seconds":94}`) ·
`eta_confidence` · `eta_basis` · `eta_history_samples` · `eta_seconds` family ·
`error` · `oom_info` · `enhancement` · `reconstruction_report`.

The live progression measured, in order: `Loading model LTX-2.3 Distilled 1.1
22B…` → `Encoding Prompt` → `Denoising First Pass` → `Denoising Second Pass` →
`completed` / `Done`. A bogus id answers `404 {"detail":"Job not found"}`.

### Job control

```bash
curl -s "$B/api/v1/jobs"                          # {"jobs":[…]}
curl -s -X POST "$B/api/v1/cancel/nonexistent"    # 404 {"detail":"Job not found"}
curl -s -X POST "$B/api/v1/jobs/nonexistent/retry" # 404 {"detail":"Enhanced job not found"}
curl -s -X DELETE "$B/api/v1/jobs/nonexistent"    # {"dismissed":true}
curl -s -X POST "$B/api/v1/jobs/queue/start"      # {"status":"idle","job_ids":[],"released":0}
curl -s "$B/api/v1/jobs/527bc6ec/enhancement"     # 404 when no enhanced job exists
```

`DELETE /api/v1/jobs/{job_id}` **dismisses**; it is not a read. The 404 bodies
above are the real answers — quote them, do not invent "not found" prose.

### `GET /api/v1/file/{filename}` — collect

```bash
NAME='2026-09-29-00h02m09s_seed42_Rune-carved obsidian….mp4'   # from output_files[0]
curl -s "$B/api/v1/file/$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$NAME")" \
     -o clip.mp4 -w '%{http_code} %{content_type} %{size_download}\n'
```

Measured: `200 video/mp4` — **1,003,261 bytes** for a 25-frame 832×448 clip.
URL-encode the filename (it carries spaces, colons and the prompt's leading
words). The same media is also on the app's own shelf,
`<app>/outputs/<name>`.

Gallery and metadata:
`GET /api/v1/outputs` (array of `{name,workspace,path,size,url,type,mode,…}`) ·
`GET /api/v1/outputs/group/{group_id}` → `{"group_id":"default","clips":[]}` —
measured empty for a group with no members.

---

## 4. Audio, direction, LoRAs

```bash
curl -s -X POST "$B/api/v1/director/music-clip-limits" -H 'Content-Type: application/json' -d '{}'
# {"fps":25.0,"frames_minimum":17,"frame_step":8,"hard_max_frames":497,
#  "recommended_frames":241,"max_frames":241,"max_seconds":9.64,…}
curl -s -X POST "$B/api/v1/director/generate-music" -H 'Content-Type: application/json' -d '{…}'
curl -s "$B/api/v1/music-styles"        # {"styles":[]} when none are defined
curl -s "$B/api/v1/loras/ltx2_22B_distilled_1_1"   # {"loras":[],"guidance_max_phases":2}
curl -s -X POST "$B/api/v1/loras/generate-guide" -H 'Content-Type: application/json' -d '{…}'
```

`music-clip-limits` is the **frame arithmetic of the whole craft**: 25 fps,
minimum 17 frames, step 8 (so 17, 25, 33, 41, …), a 497-frame hard maximum and a
241-frame recommendation (9.64 s). Size every video ask against it.

The director family (`/api/v1/director/*`, ~30 paths) plans multi-shot films:
`plan-prompts`, `plan-short-film-prompts`, `plan-short-film-script`,
`pipeline/start` and its `{pid}` lifecycle, `queue/*`. Use it when the forge
should plan the shot list; use `/generate` per shot when **you** hold the pack.

## 5. Settings worth reading

```bash
curl -s "$B/api/v1/primary-settings"      # prompt, alt_prompt, image_mode, image_prompt_type, model_mode, …
curl -s "$B/api/v1/model-visibility"      # which model_types this seat shows — the "declare families" hook
curl -s "$B/api/v1/studio-preferences"    # selected_model_per_mode: {"video":"…","image":"…"}
curl -s "$B/api/v1/system-config"         # paths, profiles, quantization
```

`model-visibility` (GET/PUT) and `studio-preferences` (GET/PUT) are how a seat's
**intent** is declared, and both are also written straight into the app's
`app/wgp_config.json` (`maestro_model_visibility.enabled_models`,
`maestro_studio_preferences.selected_model_per_mode`). Prefer the API; it keeps
the running server and the file in agreement.

---

## Traps (each one measured)

```
traps[6]{wrong,right,why}:
  "GET /api/v1/downloads/status","GET /api/v1/models/downloads/status","the downloads namespace is nested under models; the flat path is 404"
  "GET /api/v1/jobs/{job_id}","GET /api/v1/status/{job_id}","/jobs/{job_id} is DELETE (dismiss); reading a job is /status"
  "GET /api/v1/model-options/wan","GET /api/v1/model-options/{model_type}","wan is a FAMILY id; 404 Unknown model: wan — use a models[].model_type"
  "GET /api/v1/loras/generate-guide","POST /api/v1/loras/generate-guide","it is a POST (it builds a guide); GET is 404 Unknown model: generate-guide"
  "trusting the requested resolution","ffprobe the finished file","models snap to their architecture grid (832x480 → 832x448)"
  "a tight poll loop","poll every 15-30s and read .message","model load is minutes; a hot loop learns nothing and costs the forge"
```

Two runtime faults worth knowing before you blame your own request:

- **`RuntimeError: Linux CUDA llama-server compilation failed`** in the job's
  `message`/log means the forge tried to **build** its LLM planner because it
  found no CUDA `llama-server` where it looks. It is not a video-model fault. The
  cure is environmental — point `MAESTRO_LLAMA_BIN` at an existing CUDA build
  (`assets/setup-for-users.md`).
- **`GET /api/v1/system/preflight` returning `{"ok":false,…}`** names the actual
  blocker; read `checks[]` before re-submitting anything.
