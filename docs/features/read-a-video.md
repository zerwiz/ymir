# Read a video — the door that always answers

## What it is

A YouTube video is a source, and most of what matters in it is spoken, not written. `bin/agents/yt-transcript.sh`
reads one without a key, an account or a signed-in browser: it fetches the metadata and the description, then
walks a ladder of roads until one of them yields the transcript.

The ladder exists because YouTube refuses the cheap road often. Captions are throttled (HTTP 429), and a tool
that only knew captions answered nothing at all. So the tool tries, in order: captions on the default client,
captions on alternate player clients with a pause between them, the caption endpoint directly, and finally the
**audio through whisper.cpp** — which needs only `yt-dlp`, `ffmpeg` and a whisper model this box already carries.

Each rung says whether it answered and why it did not. There is no such thing here as an empty transcript or a
zero dressed as a success.

## The second law: the media dies

The audio is downloaded to make a transcript, and then it is **deleted** — the transcript is the only thing that
survives. One scratch directory per run, removed on every exit path (a clean finish, a refusal, Ctrl-C, a killed
pane). A run killed with `SIGKILL` cannot clean up after itself, so the next run sweeps scratch directories older
than a day and prints how many it swept.

`--keep-audio` is the debugging exception, and it is off by default: it copies the audio to the output shelf and
prints its path and size.

## What you need

- `yt-dlp` and `ffmpeg` on `PATH`.
- For the last two rungs: `whisper-cli` (this box builds it in `~/whisper.cpp.src/build/bin/`) and a model under
  `~/whisper.cpp/models/` (`ggml-small.en.bin` by default).
- No key, no account, no browser.

## Do it

```
bin/agents/yt-transcript.sh https://youtu.be/<id>          # metadata + description + transcript
bin/agents/yt-transcript.sh <url> --meta                   # metadata + description only
bin/agents/yt-transcript.sh <url> --out DIR                # write the transcript somewhere else
bin/agents/yt-transcript.sh <url> --keep-audio             # keep the audio too, for debugging
bin/agents/yt-transcript.sh <url> --refresh                # ignore the cached transcript, read it again
```

You should see one TOON block per fact, including one row per rung tried:

```
yt-transcript[1]{id,title,uploader,duration_s,date,description}:
  "hYIymEMB9x4","…","IndyDevDan",1613,"20261116","…description.txt"
yt-transcript[5]{road,state,cost_s}:
  "captions-default","429 — rate limited","3"
  "captions-alt","web_safari no caption track, android 429 — rate limited, … (backoff 23s)","36"
  "timedtext","no captions for this id on the endpoint","0"
  "audio","downloaded 16 kHz mono wav","18"
  "whisper-gpu ggml-small.en.bin","answered","34"
yt-transcript[4]{transcript,chars,lines,path}:
  "written","29022",54,"…/transcripts/20261116-hYIymEMB9x4-….md"
```

The transcript is Markdown with front matter recording the source, the uploader, the duration, **which road
answered**, what it cost in seconds, the whisper model, and a `sha256` of the text so a reader can prove the file
was not truncated.

## Where transcripts live

`$YMIR_HOME/hodd/docs/research/transcripts/<upload-date>-<id>-<slug>.md`, with the description beside it as
`….description.txt`. Working material belongs in the home, not in `/tmp`.

## A second read costs nothing

The transcript on the shelf is also the cache: the tool keeps one small record per video id beside it
(`$YMIR_HOME/state/yt-transcript/<id>.meta`) and, on a repeat read, prints the same rows from that record with
`"cache","hit"` — no network call at all. The cached text is verified against its `sha256` before it is served,
so a damaged or truncated file is never passed off as a transcript. `--refresh` ignores the cache.

## The GPU is shared

The whisper road asks the desk and the rail first. While the operator is in a call
(`bin/desk/in-call.sh holder`), or a local model is resident on the rail, it takes the **CPU** road and says so in
the row. It never stops, raises or re-points a service to make room.

## Notes & limits

- Exit codes: `0` the video was read · `3` no transcript, with every road named and the reason for each · `1` a
  hard error (no `yt-dlp`, cannot write) · `2` usage.
- A private, age-gated or geo-blocked video is a **refusal**, named as one, with exit 3 — not a 429 and not a
  silence.
- Captions are exact; the ear is a transcription and may mis-hear a name. The `road` field tells you which you got.
- The GPU road runs roughly 1.3× faster than real time on the A5000 for `small.en`; the CPU road is several times
  slower, which is the price of not disturbing a call.
- `--meta` reads no captions and downloads no audio.

## If it does not work

- **`clean skip — whisper-cli not found`** — build it (`~/whisper.cpp.src`) or point `WHISPER_CLI` at the binary.
- **`clean skip — no model at …`** — download a model into `~/whisper.cpp/models/`, or set `WHISPER_MODEL`.
- **Every caption rung says 429** — that is YouTube throttling this address, and the audio road is the answer;
  if that also fails, the audio download could not reach the video at all and the row says so.
- **Exit 3 with `"refused","private video"`** — the video needs an account; this tool has none, by design.

## CHANGE LOG

- **2026-11-17** — the page was written with the door that always answers (plan 316).
