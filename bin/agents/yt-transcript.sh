#!/usr/bin/env bash
# yt-transcript.sh — read a video: metadata, description, and transcript.
#
# The keyless road to a YouTube source, and the door that answers every time
# (plan 316). The Pi harness's own YouTube mode needs GEMINI_API_KEY or a
# signed-in Chromium and fails closed on a bare box; yt-dlp needs neither.
# Bragi (marketing), Huginn (research) and the desk reach for this first.
#
# THE LADDER — each rung reports whether it answered, in order:
#   1  captions, default client
#   2  captions, alternate player clients (web_safari, android, ios, tv) with backoff
#   3  the timedtext endpoint directly
#   4  the audio, then whisper.cpp on the GPU
#   5  the audio, then whisper.cpp on the CPU (when the desk or the rail holds the GPU)
#
# THE SECOND LAW (the Allfather's own word): the media is DELETED when the job is
# done — only the transcript survives. One temp dir per run, removed on every exit
# path (EXIT INT TERM HUP). A SIGKILL cannot be trapped, so the next run sweeps
# work dirs older than a day and says how many it swept.
#
# Usage:
#   bin/agents/yt-transcript.sh <url>                 metadata + description + transcript
#   bin/agents/yt-transcript.sh <url> --meta           metadata + description only (no captions, no audio)
#   bin/agents/yt-transcript.sh <url> --out DIR        where the transcript lands
#   bin/agents/yt-transcript.sh <url> --keep-audio[=DIR]
#                                                      keep the downloaded audio in DIR (default: the
#                                                      output shelf) for debugging, and print its path and
#                                                      size. OFF by default: only the transcript survives.
#   bin/agents/yt-transcript.sh <url> --refresh        ignore the cached transcript, read the video again
#
# Where it writes, by default (plan 316 §5):
#   $YMIR_HOME/hodd/docs/research/transcripts/<upload-date>-<id>-<slug>.md
# A transcript already on that shelf is a cache hit: a second read of the same
# video costs nothing and touches the network not at all.
#
# Output is Galdr TOON on stdout — metadata, one row per rung tried, and the
# transcript row (its path, its character count, its line count). Exit: 0 read,
# 3 no transcript (the reason and every road tried are named), 1 error, 2 usage.
#
# Env: YT_TRANSCRIPT_CACHE (cache dir) · YT_TRANSCRIPT_BACKOFF ("2 6 15")
#      YT_TRANSCRIPT_THREADS (8) · YT_TRANSCRIPT_GPU (auto | on | off)
#      WHISPER_MODEL (ggml-small.en.bin) · WHISPER_CLI
set -u

VERSION="2.0.0"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

usage() {  # the doc block at the top of this file, and nothing else
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
}

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) usage; exit 0 ;;
  "") usage >&2; exit 2 ;;
esac

URL="${1:-}"; shift || true
[ -n "$URL" ] || { printf 'error: usage: bin/agents/yt-transcript.sh <url> [--meta] [--out DIR] [--keep-audio[=DIR]] [--refresh]\n' >&2; exit 2; }

META_ONLY=0; OUT=""; KEEP_AUDIO=0; KEEP_DIR=""; REFRESH=0
while [ $# -gt 0 ]; do
  case "$1" in
    --meta) META_ONLY=1; shift ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --out=*) OUT="${1#--out=}"; shift ;;
    --keep-audio) KEEP_AUDIO=1; shift ;;
    --keep-audio=*) KEEP_AUDIO=1; KEEP_DIR="${1#--keep-audio=}"; shift ;;
    --refresh) REFRESH=1; shift ;;
    *) shift ;;
  esac
done

# ---------------------------------------------------------------- the roots
# The transcript is working material and belongs in the home the operator chose
# (Rule 04/07), never in the code tree and never in /tmp.
HOARD=""; STATE_ROOT=""
if [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  # shellcheck source=/dev/null
  . "$ROOT/bin/vault/hoard-lib.sh"
  hoard_root HOARD
  hoard_state_dir STATE_ROOT
fi
: "${HOARD:=${YMIR_HOARD:-${YMIR_HOME:-$HOME/Documents/ymirhome}/hodd}}"
: "${STATE_ROOT:=${YMIR_STATE_DIR:-${YMIR_HOME:-$HOME/Documents/ymirhome}/state}}"

[ -n "$OUT" ] || OUT="$HOARD/docs/research/transcripts"
KEEP_DIR="${KEEP_DIR:-$OUT}"
CACHE_DIR="${YT_TRANSCRIPT_CACHE:-$STATE_ROOT/yt-transcript}"
BACKOFF="${YT_TRANSCRIPT_BACKOFF:-2 6 15}"
THREADS="${YT_TRANSCRIPT_THREADS:-8}"

# A missing prerequisite is named, never disguised (Rule 25).
command -v yt-dlp >/dev/null 2>&1 || {
  printf 'error: yt-dlp not on PATH\nhelp: install yt-dlp (no key, no account needed)\n' >&2
  exit 1
}

mkdir -p "$OUT" 2>/dev/null || { printf 'error: cannot create the output shelf: %s\n' "$OUT" >&2; exit 1; }
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# ------------------------------------------------------------- the scratch
# One run, one directory. The trap is installed BEFORE anything is downloaded,
# so success, refusal, Ctrl-C and a killed pane all end the same way: the media
# is gone and the transcript is all that is left.
WORK=""
cleanup() {
  local rc=$?
  trap - EXIT INT TERM HUP
  keep_media
  [ -n "$WORK" ] && [ -d "$WORK" ] && rm -rf "$WORK"
  exit "$rc"
}
on_signal() {
  trap - EXIT INT TERM HUP
  keep_media
  [ -n "$WORK" ] && [ -d "$WORK" ] && rm -rf "$WORK"
  printf 'yt-transcript: interrupted — the media was removed, nothing was kept\n' >&2
  exit 130
}
# --keep-audio is the debugging exception, and it says what it left behind.
keep_media() {
  [ "$KEEP_AUDIO" = "1" ] || return 0
  [ -n "$WORK" ] && [ -d "$WORK" ] || return 0
  local f fname dest
  for f in "$WORK"/audio*.wav "$WORK"/audio*; do
    [ -f "$f" ] || continue
    fname="$(basename "$f")"
    dest="$KEEP_DIR/$fname"
    mkdir -p "$KEEP_DIR" 2>/dev/null || return 0
    cp -f "$f" "$dest" 2>/dev/null || return 0
    printf 'yt-transcript[1]{kept_media,bytes,path}:\n  "audio","%s","%s"\n' \
      "$(stat -c%s "$dest" 2>/dev/null || echo 0)" "$dest"
    return 0
  done
  return 0
}

# A trap cannot catch SIGKILL. This is what is left: the next run sweeps the
# work dirs a kill stranded.
swept=0
scan_root="${TMPDIR:-/tmp}"
while IFS= read -r stale; do
  [ -n "$stale" ] || continue
  rm -rf "$stale" 2>/dev/null && swept=$((swept + 1))
done < <(find "$scan_root" -maxdepth 1 -type d -name 'yt-transcript.*' -mmin +1440 2>/dev/null)

WORK="$(mktemp -d "${TMPDIR:-/tmp}/yt-transcript.XXXXXX")" || { printf 'error: cannot make a scratch dir\n' >&2; exit 1; }
trap cleanup EXIT
trap on_signal INT TERM HUP
[ "$swept" -gt 0 ] && printf 'yt-transcript[1]{swept,where}:\n  %s,"%s"\n' "$swept" "$scan_root"

# ---------------------------------------------------------------- helpers
now_s() { date +%s; }
toon() { printf '%s' "${1-}" | tr '\n\r\t' '   ' | sed 's/"/'"'"'/g'; }
sha_of() { sha256sum "$1" | cut -d' ' -f1; }
chars_of() { tr -d '\n' <"$1" | wc -m | tr -d ' '; }
lines_of() { wc -l <"$1" 2>/dev/null | tr -d ' '; }
slug_of() {
  printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-//' -e 's/-$//' | cut -c1-48
}
# The body of a transcript file: everything after the front matter and the title
# heading — i.e. exactly the transcript text whose sha256 the front matter records.
body_of() {
  awk 'BEGIN{n=0; s=0}
       n<2 { if ($0 ~ /^---[[:space:]]*$/) n++; next }
       s==0 && $0=="" {next}
       s==0 && $0 ~ /^# / {s=1; next}
       s==1 {s=2; next}
       {print}' "$1"
}

ROAD_ROWS=()
road_row() { ROAD_ROWS+=("${1}|${2}|${3}"); }

video_id_from_url() {
  local u="${1-}"
  case "$u" in
    *youtu.be/*) u="${u#*youtu.be/}"; printf '%s' "${u%%[?&#/]*}" ;;
    *v=*)        u="${u#*v=}";       printf '%s' "${u%%[?&#]*}" ;;
    *shorts/*)   u="${u#*shorts/}";  printf '%s' "${u%%[?&#/]*}" ;;
    *embed/*)    u="${u#*embed/}";   printf '%s' "${u%%[?&#/]*}" ;;
    *live/*)     u="${u#*live/}";    printf '%s' "${u%%[?&#/]*}" ;;
    *)           printf '' ;;
  esac
}

# ------------------------------------------------ cache: the second read is free
# The transcript on the shelf IS the cache, and one small record beside it is the
# index. A hit makes no network call at all — that is what "costs nothing" means.
read_cache() {  # <id> — echoes the path of a verified cached transcript, or nothing
  local id="${1-}" path="" sha="" body="$WORK/.cache.body" rec=""
  rec="$CACHE_DIR/$id.meta"
  [ -n "$id" ] && [ -r "$rec" ] || return 0
  # shellcheck disable=SC1090
  path="$(sed -n 's/^path=//p' "$rec" | head -1)"
  sha="$(sed -n 's/^sha256=//p' "$rec" | head -1)"
  [ -n "$path" ] && [ -s "$path" ] || return 0
  body_of "$path" >"$body" 2>/dev/null
  if [ -n "$sha" ] && [ "$(sha_of "$body")" != "$sha" ]; then
    rm -f "$body"; return 0   # a damaged or truncated shelf file is never served
  fi
  rm -f "$body"
  printf '%s' "$path"
}
write_cache() {  # <id> <path> <sha> <road> <chars> <title> <uploader> <duration> <date> <desc>
  local rec="$CACHE_DIR/$1.meta.part.$$"
  {
    printf 'id=%s\n' "$1"
    printf 'path=%s\n' "$2"
    printf 'sha256=%s\n' "$3"
    printf 'road=%s\n' "$4"
    printf 'chars=%s\n' "$5"
    printf 'title=%s\n' "$(toon "${6-}")"
    printf 'uploader=%s\n' "$(toon "${7-}")"
    printf 'duration_s=%s\n' "${8:-0}"
    printf 'date=%s\n' "${9:-}"
    printf 'description=%s\n' "${10:-}"
    printf 'cached=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } >"$rec" 2>/dev/null && mv -f "$rec" "$CACHE_DIR/$1.meta" 2>/dev/null
  rm -f "$rec" 2>/dev/null
}
cache_field() { sed -n "s/^$2=//p" "$CACHE_DIR/$1.meta" 2>/dev/null | head -1; }

# --------------------------------------------------------- the roads
pick_vtt() {  # <dir> — the first caption file with real cues in it
  local f
  for f in "$1"/*.en.vtt "$1"/*.en-*.vtt "$1"/*.vtt; do
    [ -f "$f" ] && [ -s "$f" ] || continue
    grep -q -- '-->' "$f" 2>/dev/null && { printf '%s\n' "$f"; return 0; }
  done
  return 1
}

vtt_to_text() {  # <vtt> <txt>
  sed -e '/^WEBVTT/d' -e '/^Kind:/d' -e '/^Language:/d' -e '/^NOTE /d' \
      -e '/^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9][0-9][0-9] -->/d' \
      -e '/^[0-9][0-9]:[0-9][0-9]\.[0-9][0-9][0-9] -->/d' -e '/^$/d' "$1" \
    | sed -e 's/<[^>]*>//g' \
          -e 's/&#39;/'"'"'/g' -e 's/&quot;/"/g' -e 's/&amp;/\&/g' -e 's/&gt;/>/g' -e 's/&lt;/</g' \
          -e 's/[[:space:]]*$//' \
    | uniq >"$2"
  [ -s "$2" ] && grep -q '[A-Za-z0-9]' "$2"
}

caption_reason() {  # <log> — what the log says went wrong, in plain words
  local log="${1-}"
  if grep -qi '429' "$log" 2>/dev/null; then printf '429 — rate limited'
  elif grep -qi 'private video\|This video is private' "$log" 2>/dev/null; then printf 'private video'
  elif grep -qi 'age.restricted\|confirm your age' "$log" 2>/dev/null; then printf 'age-gated'
  elif grep -qi 'not available in your country\|geo' "$log" 2>/dev/null; then printf 'geo-blocked'
  elif grep -qi 'no subtitles\|There are no subtitles' "$log" 2>/dev/null; then printf 'no caption track'
  elif grep -qi 'HTTP Error 403' "$log" 2>/dev/null; then printf '403 — refused'
  elif grep -qi 'HTTP Error 5' "$log" 2>/dev/null; then printf 'server error'
  else printf 'no caption track'; fi
}

try_captions() {  # <label> <yt-dlp extra args...> — echoes the vtt on success
  local label="$1"; shift
  local dir="$WORK/cap.$label" log="$WORK/yt-dlp.$label.log" vtt=""
  rm -rf "$dir"; mkdir -p "$dir"
  yt-dlp --skip-download --write-subs --write-auto-subs \
         --sub-langs 'en,en-orig,en-en' --sub-format vtt --no-progress \
         -o "$dir/%(id)s.%(ext)s" "$@" "$URL" >"$log" 2>&1
  # A file with cues is the ONLY success: yt-dlp exits non-zero when one of the
  # requested languages is refused, and still writes the one that answered.
  vtt="$(pick_vtt "$dir")" && [ -n "$vtt" ] || return 1
  printf '%s' "$vtt"
  return 0
}

audio_ready() {  # download the 16 kHz mono WAV into the scratch dir
  local log="$WORK/yt-dlp.audio.log"
  yt-dlp -x --audio-format wav --postprocessor-args "ExtractAudio:-ar 16000 -ac 1" \
         --no-progress -o "$WORK/audio.%(ext)s" "$URL" >"$log" 2>&1
  local f
  for f in "$WORK"/audio*.wav; do
    [ -s "$f" ] && { printf '%s' "$f"; return 0; }
  done
  return 1
}

whisper_bin() {
  # An explicit WHISPER_CLI is the answer, even when it is wrong: a broken one is
  # named rather than silently swapped for another binary (Rule 25).
  if [ -n "${WHISPER_CLI:-}" ]; then
    [ -x "${WHISPER_CLI}" ] && { printf '%s' "$WHISPER_CLI"; return 0; }
    return 1
  fi
  if command -v whisper-cli >/dev/null 2>&1; then command -v whisper-cli; return 0; fi
  if [ -x "$HOME/whisper.cpp.src/build/bin/whisper-cli" ]; then printf '%s' "$HOME/whisper.cpp.src/build/bin/whisper-cli"; return 0; fi
  return 1
}

whisper_missing_reason() {
  if [ -n "${WHISPER_CLI:-}" ]; then
    printf 'clean skip — no whisper-cli at WHISPER_CLI=%s' "$WHISPER_CLI"
  else
    printf 'clean skip — whisper-cli not found (build ~/whisper.cpp.src, or set WHISPER_CLI)'
  fi
}

whisper_model_path() {
  local m="${WHISPER_MODEL:-ggml-small.en.bin}"
  case "$m" in /*) printf '%s' "$m"; return 0 ;; esac
  printf '%s' "$HOME/whisper.cpp/models/$m"
}

# The GPU is shared with the desk (a live call) and the rail (a resident local
# model). A transcript is worth 40 seconds of a quiet GPU, never a dropped call.
gpu_why_held() {
  local holder=""
  case "${YT_TRANSCRIPT_GPU:-auto}" in
    on) return 1 ;;                      # the caller knows the GPU is free
    off) printf 'forced to the CPU by YT_TRANSCRIPT_GPU=off'; return 0 ;;
  esac
  if [ -x "$ROOT/bin/desk/in-call.sh" ]; then
    holder="$("$ROOT/bin/desk/in-call.sh" holder 2>/dev/null)"
    [ -n "$holder" ] && { printf 'the desk is in a call (%s)' "$holder"; return 0; }
  fi
  if [ -x "$ROOT/bin/model/local-model-lock.sh" ]; then
    if ! "$ROOT/bin/model/local-model-lock.sh" check >/dev/null 2>&1; then
      printf 'a local model is resident on the rail'
      return 0
    fi
  fi
  return 1
}

whisper_fail_reason() {  # <log> — the one line that says WHY the ear failed
  awk 'tolower($0) ~ /error|failed|cuda|out of memory|invalid|no such file/ {last=$0} END {if (last != "") print last}' "$1" 2>/dev/null \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | cut -c1-160
}

run_whisper() {  # <wav> <no-gpu:0|1> — echoes the produced txt on success
  local wav="$1" nogpu="$2" bin model out="$WORK/tx.$2" err="$WORK/whisper.$2.log"
  bin="$(whisper_bin)" || return 2
  model="$(whisper_model_path)"
  [ -r "$model" ] || return 2
  local -a extra=(-t "$THREADS" -l en -nt -otxt -np -of "$out")
  [ "$nogpu" = "1" ] && extra+=(-ng)
  "$bin" -m "$model" -f "$wav" "${extra[@]}" >"$err" 2>&1 || true
  [ -s "$out.txt" ] || return 1
  grep -q '[A-Za-z0-9]' "$out.txt" || return 1
  printf '%s' "$out.txt"
}

# ================================================================ the run
T_START=$(now_s)

# 1. the metadata — one network read, and the cache means a second read of the
#    same video makes none at all.
id_hint="$(video_id_from_url "$URL")"
cached_path=""
if [ "$REFRESH" = "0" ] && [ -n "$id_hint" ]; then
  cached_path="$(read_cache "$id_hint")"
fi

if [ -n "$cached_path" ]; then
  id="$id_hint"
  title="$(cache_field "$id" title)"
  uploader="$(cache_field "$id" uploader)"
  duration="$(cache_field "$id" duration_s)"
  date="$(cache_field "$id" date)"
  desc_file="$(cache_field "$id" description)"
  chars="$(cache_field "$id" chars)"
  lines="$(body_of "$cached_path" | wc -l | tr -d ' ')"
  [ -n "$chars" ] || chars="$(chars_of "$cached_path")"
  printf 'yt-transcript[1]{id,title,uploader,duration_s,date,description}:\n  "%s","%s","%s",%s,"%s","%s"\n' \
    "$id" "$(toon "$title")" "$(toon "$uploader")" "${duration:-0}" "$date" "${desc_file:-none}"
  printf 'yt-transcript[1]{road,state,cost_s}:\n  "cache","hit — the transcript was already on the shelf, no network","0"\n'
  printf 'yt-transcript[4]{transcript,chars,lines,path}:\n  "cached","%s",%s,"%s"\n' \
    "${chars:-0}" "${lines:-0}" "$cached_path"
  exit 0
fi

# 1. the metadata AND the description — ONE read of the video. The fields are
#    NUL-separated because a title may carry a '|' or a newline, and a delimiter
#    that can appear in the data is how "But what is a neural network? | Deep
#    learning chapter 1" once became a video id.
meta_json="$WORK/meta.json"
desc=""
if yt-dlp --skip-download --dump-single-json --no-warnings "$URL" >"$meta_json" 2>"$WORK/meta.log" && [ -s "$meta_json" ]; then
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$meta_json" "$WORK/meta.fields" "$WORK/desc.txt" <<'PY' || true
import json, sys
src, fields, descf = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src, encoding="utf-8", errors="replace") as fh:
    d = json.load(fh)
def g(k):
    v = d.get(k)
    return "" if v is None else str(v)
with open(fields, "w", encoding="utf-8") as fh:
    for v in (g("id"), g("title"), g("uploader"), g("duration"), g("upload_date")):
        fh.write(v.replace("\0", " ") + "\0")
with open(descf, "w", encoding="utf-8") as fh:
    fh.write(g("description"))
PY
    { IFS= read -r -d '' id; IFS= read -r -d '' title; IFS= read -r -d '' uploader
      IFS= read -r -d '' duration; IFS= read -r -d '' date; } <"$WORK/meta.fields"
    [ -r "$WORK/desc.txt" ] && desc="$(cat "$WORK/desc.txt")"
  else
    # No python3 on this box: tab-separated prints, read field by field.
    meta="$(yt-dlp --skip-download --print '%(id)s	%(title)s	%(uploader)s	%(duration)s	%(upload_date)s' "$URL" 2>/dev/null)"
    id="$(printf '%s' "$meta" | cut -f1)"
    title="$(printf '%s' "$meta" | cut -f2)"
    uploader="$(printf '%s' "$meta" | cut -f3)"
    duration="$(printf '%s' "$meta" | cut -f4)"
    date="$(printf '%s' "$meta" | cut -f5)"
    desc="$(yt-dlp --skip-download --print '%(description)s' "$URL" 2>/dev/null)"
  fi
else
  id="${id_hint:-unknown}"
  reason="$(caption_reason "$WORK/meta.log")"
  grep -qi 'unsupported url\|is not a valid URL' "$WORK/meta.log" 2>/dev/null && reason='not a video url'
  printf 'yt-transcript[1]{id,state,reason}:\n  "%s","refused","%s"\n' "$id" "$(toon "$reason")"
  printf 'yt-transcript[1]{transcript,chars,lines,path}:\n  "none",0,0,"none"\n'
  printf 'yt-transcript: no transcript — the video could not be read: %s\n' "$reason" >&2
  exit 3
fi

[ -n "$id" ] || id="${id_hint:-unknown}"
[ "$id" = "NA" ] && id="${id_hint:-unknown}"

# 2. the description lands beside the transcript — often the real payload
#    (chapters, links, the thesis).
slug="$(slug_of "$title")"; [ -n "$slug" ] || slug="$id"
base="$date-$id-$slug"
{ [ -z "$date" ] || [ "$date" = "NA" ]; } && base="$id-$slug"
desc_file=""
if [ -n "$desc" ]; then
  desc_file="$OUT/$base.description.txt"
  printf '%s\n' "$desc" >"$desc_file.part.$$" && mv -f "$desc_file.part.$$" "$desc_file" || desc_file=""
fi

printf 'yt-transcript[1]{id,title,uploader,duration_s,date,description}:\n  "%s","%s","%s",%s,"%s","%s"\n' \
  "$id" "$(toon "$title")" "$(toon "$uploader")" "${duration:-0}" "$date" "${desc_file:-none}"

finish_with_transcript() {  # <text-file> <road> <model>
  local text="$1" road="$2" model="$3" cost=$(( $(now_s) - T_START ))
  local sha chars lines dest bodyf
  bodyf="$WORK/final.body"
  cat "$text" >"$bodyf" || return 1
  # Exactly one trailing newline, so the sha256 the front matter records and the
  # bytes written below it agree — a verifier must never find a false mismatch.
  [ -n "$(tail -c1 "$bodyf" 2>/dev/null)" ] && printf '\n' >>"$bodyf"
  [ -s "$bodyf" ] || return 1
  # The sha256 and the character count describe EXACTLY the text that is written,
  # so a later reader can verify the shelf file was not truncated.
  sha="$(sha_of "$bodyf")"
  chars="$(chars_of "$bodyf")"
  lines="$(lines_of "$bodyf")"
  dest="$OUT/$base.md"
  {
    printf -- '---\n'
    printf 'kind: transcript\n'
    printf 'status: verified\n'
    printf 'source: %s\n' "$URL"
    printf 'id: %s\n' "$id"
    printf 'title: %s\n' "$(toon "$title")"
    printf 'uploader: %s\n' "$(toon "$uploader")"
    printf 'duration_s: %s\n' "${duration:-0}"
    printf 'upload_date: %s\n' "$date"
    printf 'road: %s\n' "$road"
    printf 'cost_s: %s\n' "$cost"
    [ -n "$model" ] && printf 'model: %s\n' "$model"
    printf 'chars: %s\n' "$chars"
    printf 'sha256: %s\n' "$sha"
    printf 'transcribed: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '---\n\n'
    printf '# %s\n\n' "$(toon "$title")"
    cat "$bodyf"
  } >"$dest.part.$$" 2>/dev/null || { rm -f "$dest.part.$$"; return 1; }
  mv -f "$dest.part.$$" "$dest" || { rm -f "$dest.part.$$"; return 1; }

  write_cache "$id" "$dest" "$sha" "$road" "$chars" "$title" "$uploader" "$duration" "$date" "$desc_file"

  printf 'yt-transcript[%s]{road,state,cost_s}:\n' "${#ROAD_ROWS[@]}"
  local r a b c
  for r in "${ROAD_ROWS[@]}"; do
    IFS='|' read -r a b c <<<"$r"
    printf '  "%s","%s","%s"\n' "$(toon "$a")" "$(toon "$b")" "$c"
  done
  printf 'yt-transcript[4]{transcript,chars,lines,path}:\n  "%s","%s",%s,"%s"\n' \
    "written" "$chars" "$lines" "$dest"
  exit 0
}

if [ "$META_ONLY" = "1" ]; then
  printf 'yt-transcript[1]{transcript,state}:\n  "none","skipped (--meta)"\n'
  exit 0
fi

# ---------------------------------------------------------------- rung 1 & 2
t0=$(now_s)
if vtt="$(try_captions default)"; then
  road_row "captions-default" "answered" "$(( $(now_s) - t0 ))"
  vtt_to_text "$vtt" "$WORK/text.txt" || { rm -f "$WORK/text.txt"; }
  [ -s "$WORK/text.txt" ] && finish_with_transcript "$WORK/text.txt" "captions-default" ""
  road_row "captions-default" "fetched, but the cue file had no speech in it" "$(( $(now_s) - t0 ))"
else
  reason="$(caption_reason "$WORK/yt-dlp.default.log")"
  road_row "captions-default" "$reason" "$(( $(now_s) - t0 ))"
fi

t0=$(now_s)
alt_state=""; alt_ok=""; slept=0; alt_i=0
read -r -a BACKOFF_ARR <<<"$BACKOFF"
for client in web_safari android ios tv; do
  # backoff between rotations — a rate limit clears with time, not with speed
  if [ -n "$alt_state" ]; then
    wait_for="${BACKOFF_ARR[$alt_i]:-${BACKOFF_ARR[${#BACKOFF_ARR[@]}-1]:-0}}"
    alt_i=$((alt_i + 1))
    [ "$wait_for" -gt 0 ] 2>/dev/null && sleep "$wait_for" && slept=$((slept + wait_for))
  fi
  if vtt="$(try_captions "alt.$client" --extractor-args "youtube:player_client=$client")"; then
    alt_state="${alt_state:+$alt_state, }$client answered"
    alt_ok="$vtt"; break
  fi
  alt_state="${alt_state:+$alt_state, }$client $(caption_reason "$WORK/yt-dlp.alt.$client.log")"
done
t_alt=$(( $(now_s) - t0 ))
if [ -n "$alt_ok" ]; then
  road_row "captions-alt" "answered ($alt_state; backoff ${slept}s)" "$t_alt"
  vtt_to_text "$alt_ok" "$WORK/text.txt" && [ -s "$WORK/text.txt" ] \
    && finish_with_transcript "$WORK/text.txt" "captions-alt" ""
  road_row "captions-alt" "$alt_state — fetched, but no speech in the cue file" "$t_alt"
else
  road_row "captions-alt" "${alt_state:-no alternate client answered} (backoff ${slept}s)" "$t_alt"
fi

# ------------------------------------------------------------------- rung 3
# The timedtext endpoint directly: when yt-dlp's extractor is the thing refused.
t0=$(now_s)
tt_ok=""
if command -v curl >/dev/null 2>&1; then
  mkdir -p "$WORK/tt"
  for q in "lang=en" "lang=en&kind=asr"; do
    out="$WORK/tt/$(printf '%s' "$q" | tr '&=' '__').vtt"
    curl -fsS --max-time 20 "https://www.youtube.com/api/timedtext?v=$id&fmt=vtt&$q" -o "$out" 2>/dev/null || true
    if [ -s "$out" ] && grep -q -- '-->' "$out" 2>/dev/null; then tt_ok="$out"; break; fi
  done
fi
t_tt=$(( $(now_s) - t0 ))
if [ -n "$tt_ok" ]; then
  road_row "timedtext" "answered" "$t_tt"
  vtt_to_text "$tt_ok" "$WORK/text.txt" && [ -s "$WORK/text.txt" ] \
    && finish_with_transcript "$WORK/text.txt" "timedtext" ""
  road_row "timedtext" "fetched, but the cue file had no speech in it" "$t_tt"
else
  road_row "timedtext" "no captions for this id on the endpoint" "$t_tt"
fi

# --------------------------------------------------------------- rung 4 & 5
t0=$(now_s)
if ! audio="$(audio_ready)"; then
  road_row "audio" "the audio could not be downloaded ($(caption_reason "$WORK/yt-dlp.audio.log"))" "$(( $(now_s) - t0 ))"
else
  road_row "audio" "downloaded 16 kHz mono wav" "$(( $(now_s) - t0 ))"

  wbin="$(whisper_bin)" || wbin=""
  wmodel="$(whisper_model_path)"
  if [ -z "$wbin" ]; then
    road_row "whisper" "$(whisper_missing_reason)" 0
  elif [ ! -r "$wmodel" ]; then
    road_row "whisper" "clean skip — no model at $wmodel" 0
  else
    model_name="$(basename "$wmodel")"
    held="$(gpu_why_held)" || held=""

    if [ -n "$held" ]; then
      road_row "whisper-gpu $model_name" "GPU held — $held" 0
    else
      t1=$(now_s)
      if tx="$(run_whisper "$audio" 0)"; then
        road_row "whisper-gpu $model_name" "answered" "$(( $(now_s) - t1 ))"
        finish_with_transcript "$tx" "whisper-gpu $model_name" "$model_name"
      fi
      why="$(whisper_fail_reason "$WORK/whisper.0.log")"
      road_row "whisper-gpu $model_name" "ran, but produced no speech${why:+ — $why}" "$(( $(now_s) - t1 ))"
    fi

    t1=$(now_s)
    if tx="$(run_whisper "$audio" 1)"; then
      road_row "whisper-cpu $model_name" "answered${held:+ — $held}" "$(( $(now_s) - t1 ))"
      finish_with_transcript "$tx" "whisper-cpu $model_name" "$model_name"
    fi
    why="$(whisper_fail_reason "$WORK/whisper.1.log")"
    road_row "whisper-cpu $model_name" "ran, but produced no speech${why:+ — $why}" "$(( $(now_s) - t1 ))"
  fi
fi

# ------------------------------------------------------------- nothing answered
printf 'yt-transcript[%s]{road,state,cost_s}:\n' "${#ROAD_ROWS[@]}"
for r in "${ROAD_ROWS[@]}"; do
  IFS='|' read -r a b c <<<"$r"
  printf '  "%s","%s","%s"\n' "$(toon "$a")" "$(toon "$b")" "$c"
done
printf 'yt-transcript[4]{transcript,chars,lines,path}:\n  "none",0,0,"none"\n'
printf 'yt-transcript: no transcript — every road was tried and named above. Nothing was written; the media was removed.\n' >&2
exit 3
