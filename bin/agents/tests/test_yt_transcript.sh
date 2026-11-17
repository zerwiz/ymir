#!/usr/bin/env bash
# test_yt_transcript.sh — plan 316: the video door answers, or names every road
# that failed, and the media is gone when it is done.
#
# Everything here runs against a FAKE yt-dlp, a fake curl and a fake whisper-cli
# on PATH, so the ladder, the exit codes, the cache and the cleanup are asserted
# without the network and without a GPU.
#
#   1. captions on the first rung answer, and nothing is left in the scratch root
#   2. a second read of the same video is a cache hit and makes no network call
#   3. captions 429 → alternate client answers, and the road says which one
#   4. captions and audio-refused → the audio road answers, via whisper
#   5. every road refused → exit 3, each rung named, no transcript, no leftovers
#   6. a private video is refused by name with exit 3
#   7. no whisper-cli → a clean skip that names it, exit 3, never a zero
#   8. --keep-audio keeps the audio and prints it; the default leaves nothing
#   9. --meta reads no captions and downloads no audio
#  10. a stale scratch dir from a killed run is swept and counted
#
# Usage: test_yt_transcript.sh      Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
TOOL="$ROOT/bin/agents/yt-transcript.sh"

pass=0; fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }
has() { grep -qF -- "$2" <<<"$1"; }
lacks() { ! grep -qF -- "$2" <<<"$1"; }
# The sha256 in the front matter must verify the transcript text written below it.
verify_sha() {
  local f=$1 want got
  want=$(sed -n 's/^sha256: //p' "$f")
  got=$(awk 'BEGIN{n=0;s=0} n<2{if($0~/^---[[:space:]]*$/){n++};next} s==0&&$0==""{next} s==0&&$0~/^# /{s=1;next} s==1{s=2;next} {print}' "$f" | sha256sum | cut -d' ' -f1)
  [ -n "$want" ] && [ "$want" = "$got" ]
}

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/wbin" "$T/home" "$T/tmp" "$T/cache" "$T/out"

# ---------------------------------------------------------------- the fakes
cat >"$T/bin/yt-dlp" <<'FAKE'
#!/usr/bin/env bash
printf 'call\n' >>"${FAKE_YT_COUNT:?}"
mode="${FAKE_YT_MODE:-captions}"
print_fmt=""; out=""; want_audio=0; alt=""; dump_json=0
while [ $# -gt 0 ]; do
  case "$1" in
    --print) print_fmt="${2-}"; shift 2 ;;
    -o) out="${2-}"; shift 2 ;;
    -o*) out="${1#-o}"; shift ;;
    -x) want_audio=1; shift ;;
    --dump-single-json) dump_json=1; shift ;;
    --extractor-args) alt="${2-}"; shift 2 ;;
    --extractor-args=*) alt="${1#--extractor-args=}"; shift ;;
    *) shift ;;
  esac
done
dir="$(dirname "${out:-.}")"; mkdir -p "$dir" 2>/dev/null
if [ "$mode" = "private" ]; then
  printf 'ERROR: [youtube] PRIVATE01: Private video. Sign in if you have been granted access.\n' >&2
  exit 1
fi
if [ "$dump_json" = "1" ]; then
  printf '{"id":"FAKEID01","title":"A Fake Talk | With A Pipe","uploader":"Fake Uploader","duration":120,"upload_date":"20261116","description":"A fake description with chapters."}\n'
  exit 0
fi
if [ -n "$print_fmt" ]; then
  case "$print_fmt" in
    *description*) printf 'A fake description with chapters.\n'; exit 0 ;;
    *title*) printf 'A Fake Talk | With A Pipe|Fake Uploader|120|20261116|FAKEID01\n'; exit 0 ;;
  esac
fi
if [ "$want_audio" = "1" ]; then
  [ "$mode" = "audio-refused" ] && { printf 'ERROR: unable to download video data: HTTP Error 403\n' >&2; exit 1; }
  printf 'RIFFfake-wav' >"$dir/audio.wav"; exit 0
fi
# captions
if [ "$mode" = "captions" ] || { [ "$mode" = "captions-alt" ] && [[ "$alt" == *android* ]]; }; then
  { printf 'WEBVTT\nKind: captions\nLanguage: en\n\n'
    printf '00:00:00.000 --> 00:00:02.000\n<00:00:00.000><c>a line of speech</c>\n\n'
    printf '00:00:02.000 --> 00:00:04.000\na second line of speech\n'; } >"$dir/FAKEID01.en.vtt"
  exit 0
fi
if [ "$mode" = "notrack" ]; then
  printf 'ERROR: [youtube] FAKEID01: There are no subtitles for the requested languages\n' >&2; exit 1
fi
printf 'ERROR: unable to download video subtitles for %s: HTTP Error 429: Too Many Requests\n' "'en'" >&2
exit 1
FAKE

cat >"$T/wbin/whisper-cli" <<'FAKE'
#!/usr/bin/env bash
of=""
while [ $# -gt 0 ]; do case "$1" in -of) of="${2-}"; shift 2 ;; *) shift ;; esac; done
[ "${FAKE_WHISPER:-ok}" = "fail" ] && exit 1
printf 'hello from the fake ear\nsecond line of the transcript\n' >"${of}.txt"
FAKE

cat >"$T/bin/curl" <<'FAKE'
#!/usr/bin/env bash
# The timedtext endpoint refuses everything in this test.
while [ $# -gt 0 ]; do case "$1" in -o) : >"${2-}"; shift 2 ;; *) shift ;; esac; done
exit 22
FAKE

chmod +x "$T/bin/yt-dlp" "$T/bin/curl" "$T/wbin/whisper-cli"
touch "$T/ggml-fake.bin"

PATH="$T/bin:$PATH"; export PATH
HOME="$T/home"; export HOME
TMPDIR="$T/tmp"; export TMPDIR
YT_TRANSCRIPT_CACHE="$T/cache"; export YT_TRANSCRIPT_CACHE
YT_TRANSCRIPT_BACKOFF="0 0 0"; export YT_TRANSCRIPT_BACKOFF
YT_TRANSCRIPT_GPU=off; export YT_TRANSCRIPT_GPU
WHISPER_MODEL="$T/ggml-fake.bin"; export WHISPER_MODEL
WHISPER_CLI="$T/wbin/whisper-cli"; export WHISPER_CLI
FAKE_YT_COUNT="$T/ytdlp.count"; export FAKE_YT_COUNT
: >"$FAKE_YT_COUNT"

URL="https://youtu.be/FAKEID01"
run() { "$TOOL" "$URL" --out "$T/out" "$@"; }
no_leftovers() { [ -z "$(find "$TMPDIR" -maxdepth 1 -name 'yt-transcript.*' 2>/dev/null)" ] \
                 && [ -z "$(find "$T/out" -maxdepth 1 -name '*.part*' 2>/dev/null)" ]; }
reset() { rm -rf "$T/out" "$T/cache"; mkdir -p "$T/out" "$T/cache"; : >"$FAKE_YT_COUNT"; }

# 1 — captions answer on the first rung
reset; export FAKE_YT_MODE=captions
out="$(run)"; rc=$?
t "captions: exit 0" [ "$rc" -eq 0 ]
t "captions: the road is named" has "$out" '"captions-default","answered"'
t "captions: the transcript row says written" has "$out" '"written"'
t "captions: the recorded road is in the file" grep -q '^road: captions-default$' "$T/out"/*.md
t "captions: the front matter carries the sha256" grep -q '^sha256: [0-9a-f]\{64\}$' "$T/out"/*.md
t "captions: the sha256 verifies the text it recorded" verify_sha "$(ls "$T"/out/*.md | head -1)"
t "captions: nothing is left behind" no_leftovers

# 2 — the second read is free
before=$(wc -l <"$FAKE_YT_COUNT")
out="$(run)"; rc=$?
after=$(wc -l <"$FAKE_YT_COUNT")
t "cache: exit 0" [ "$rc" -eq 0 ]
t "cache: the row says hit" has "$out" '"cache","hit'
t "cache: no network call at all" [ "$before" = "$after" ]
t "cache: the path is the one on the shelf" grep -q "$T/out" <<<"$out"

# 3 — a 429 on the default client is retried on another client
reset; export FAKE_YT_MODE=captions-alt
out="$(run)"; rc=$?
t "alternate client: exit 0" [ "$rc" -eq 0 ]
t "alternate client: the first rung reports the 429" has "$out" '"captions-default","429'
t "alternate client: the answering client is named" has "$out" '"captions-alt","answered (web_safari'
t "alternate client: nothing is left behind" no_leftovers

# 4 — captions refused, the ear answers; the desk holds the GPU so the CPU road runs
reset; export FAKE_YT_MODE=429
out="$(run)"; rc=$?
t "whisper: exit 0" [ "$rc" -eq 0 ]
t "whisper: the GPU row says why it was skipped" has "$out" 'GPU held — forced to the CPU'
t "whisper: the answering rung is named" has "$out" '"whisper-cpu ggml-fake.bin","answered'
t "whisper: the recorded road is in the file" grep -q '^road: whisper-cpu ggml-fake.bin$' "$T/out"/*.md
t "whisper: nothing is left behind" no_leftovers

# 5 — every road refused: exit 3, each rung named, no fake transcript
reset; export FAKE_YT_MODE=audio-refused
out="$(run 2>"$T/err")"; rc=$?
t "all roads: exit 3" [ "$rc" -eq 3 ]
t "all roads: the captions rungs are named" has "$out" 'captions-alt'
t "all roads: the audio refusal is named" has "$out" '"audio","the audio could not be downloaded'
t "all roads: no transcript is claimed" has "$out" '"none",0,0,"none"'
t "all roads: no file was written" bash -c '[ -z "$(ls -A "$0"/out/*.md 2>/dev/null)" ]' "$T"
t "all roads: the stderr says nothing was written" has "$(cat "$T/err")" 'no transcript — every road was tried'
t "all roads: nothing is left behind" no_leftovers

# 6 — a private video is refused by name
reset; export FAKE_YT_MODE=private
out="$(run 2>/dev/null)"; rc=$?
t "private: exit 3" [ "$rc" -eq 3 ]
t "private: refused, with the reason" has "$out" '"refused","private video"'
t "private: no transcript" has "$out" '"none",0,0,"none"'
t "private: nothing is left behind" no_leftovers

# 7 — no whisper-cli anywhere: a clean skip that names it
reset; export FAKE_YT_MODE=429
out="$(WHISPER_CLI=/nonexistent/whisper-cli run 2>/dev/null)"; rc=$?
t "no whisper: exit 3" [ "$rc" -eq 3 ]
t "no whisper: the missing piece is named" has "$out" 'clean skip — no whisper-cli at WHISPER_CLI=/nonexistent/whisper-cli'
t "no whisper: no transcript is claimed" has "$out" '"none",0,0,"none"'
t "no whisper: nothing is left behind" no_leftovers

# 8 — --keep-audio is the debugging exception, and it says what it kept
reset; export FAKE_YT_MODE=429
out="$(run --keep-audio)"; rc=$?
t "keep-audio: exit 0" [ "$rc" -eq 0 ]
t "keep-audio: the kept file is printed with its size" has "$out" '{kept_media,bytes,path}'
t "keep-audio: the wav is in the output shelf" [ -n "$(find "$T/out" -maxdepth 1 -name 'audio*.wav' 2>/dev/null)" ]
t "keep-audio: the scratch dir is STILL removed" [ -z "$(find "$TMPDIR" -maxdepth 1 -name 'yt-transcript.*' 2>/dev/null)" ]
rm -f "$T/out"/audio*.wav

# 9 — --meta reads no captions and downloads no audio
reset; export FAKE_YT_MODE=429
out="$(run --meta)"; rc=$?
t "meta: exit 0" [ "$rc" -eq 0 ]
t "meta: the transcript is skipped, not failed" has "$out" '"none","skipped (--meta)"'
t "meta: the metadata row is there" has "$out" 'FAKEID01'
t "meta: a title carrying a pipe survives as a title" has "$out" 'A Fake Talk | With A Pipe'
t "meta: no transcript was written" bash -c '[ -z "$(ls -A "$0"/out/*.md 2>/dev/null)" ]' "$T"
t "meta: nothing is left behind" no_leftovers

# 10 — a scratch dir stranded by a SIGKILL is swept
reset; export FAKE_YT_MODE=captions
mkdir -p "$TMPDIR/yt-transcript.StAle"
touch -d '2 days ago' "$TMPDIR/yt-transcript.StAle" 2>/dev/null || true
out="$(run)"
t "sweep: the stale dir is counted" has "$out" '{swept,where}'
t "sweep: the stale dir is gone" [ ! -d "$TMPDIR/yt-transcript.StAle" ]

printf '\ntest_yt_transcript: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
