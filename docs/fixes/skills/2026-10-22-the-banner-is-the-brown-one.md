## skills · unversioned · 2026-10-22 — the README banner is the brown one

### What

`README.md`'s banner now points at `assets/ymir-banner-brown.jpg` (the Allfather's own picture, 1104×973,
560 KB) instead of `assets/ymir-banner-03.png`. The old file is **not removed** (Rule 11: a replaced asset is
retired by a note, not by a deletion) — it stays in `assets/` for the record.

### Verified

- the file is in `assets/`, 560,688 bytes, `JPEG 1104x973`, and `README.md` line 14 references it.
- the markdown renders as a single image reference; no other README image changed.

### Not done

- The picture is **not resized or compressed**: 560 KB for a near-square image is heavy for a README on a slow
  connection. If it matters, a web variant (max 1200 px, quality ~85) should replace it, keeping the original.
