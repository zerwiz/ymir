## agents · unversioned · 2026-11-17 — the video door answers every time, and the media dies when the job does

### Why
yt-transcript.sh read the captions and nothing else, so a 429 from YouTube produced no transcript at all — the common case, not the rare one (plan 316). It now walks a ladder: captions on the default client, captions on alternate player clients with 2/6/15 s backoff, the timedtext endpoint directly, then the audio through whisper.cpp — GPU first, CPU when the desk is in a call or a local model holds the rail. Each rung reports whether it answered and why it did not; a job with no transcript exits 3 and names every road. The media is deleted: one mktemp -d per run, traps on EXIT/INT/TERM/HUP, the audio copied out only when --keep-audio asks, and the next run sweeps work dirs a SIGKILL stranded. A transcript already on the shelf is a cache hit verified by sha256, so a second read makes no network call, and nothing partial is ever left behind: files are written to .part and renamed. Two defects found while proving it: a title carrying a pipe ('But what is a neural network? | Deep learning chapter 1') broke the pipe-delimited metadata read and became the video id — metadata now comes from one --dump-single-json read parsed with NUL separators — and the front matter's sha256 did not verify its own body when the text had no trailing newline.

### Files
- `bin/agents/yt-transcript.sh`
- `bin/agents/tests/test_yt_transcript.sh`
- `bin/gates/ci-verify.sh`
- `.agents/skills/bragi-marketing/SKILL.md`
- `docs/features/read-a-video.md`