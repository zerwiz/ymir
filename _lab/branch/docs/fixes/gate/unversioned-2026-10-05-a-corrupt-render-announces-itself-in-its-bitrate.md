## gate · unversioned · 2026-10-05 — a corrupt render announces itself in its bitrate

### Why

MiniMax H3 produced **a valid MP4 of uniform RGB noise** — 124 frames, 5.17 s,
864×480, the full prompt in the metadata, `status: completed`. Every job-level check
passed and every gate in this repo stayed green.

`Comfy-Org/ComfyUI#15738` records the tell: corrupted output is **anomalously high
bitrate**, ~24–47 Mbps against ~8–10 Mbps for a correct clip of the same length and
resolution. **Ours measured 26.8 Mbps.**

**Every other gate here counts files, frames, durations or luminance. None of them can
see that the picture is garbage, because the container is perfect.** This one can, and
it costs one `ffprobe`.

### Fix

`bin/bitrate-gate.sh` — measures a rendered clip's bitrate and fails outside a band.

**Verified on both ends, before it was trusted:**

```
KNOWN CORRUPT  26.81 Mbps  864x480   → FAIL, exit 1
KNOWN GOOD      0.47 Mbps  832x448   → PASS, exit 0
```

### The thing the first draft got wrong

It shipped with the issue's `8–10` band. Then a known-good film measured **0.47**.

> **The bands are per-shape, not global.** 0.47 Mbps is correct for a finished
> 832×448 assembly; 8–10 is correct for a 1344×768 diffusion render. **Calibrate
> against a known-good render of the SAME shape before trusting a threshold.**

The gate's own help says so, and its default band is deliberately wide so it fails
loudly rather than silently when nobody has calibrated one. A threshold copied from
another machine's numbers would have failed every film on this shelf — which is the
twin of the fault it exists to catch.

### What this does not do

**It does not judge whether a picture is good.** It catches *silent corruption* — the
failure mode where the container is perfect and the content is noise. Whether a film
is beautiful remains a judge's question, and that is what the vision bench is for.
