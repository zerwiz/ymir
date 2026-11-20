#!/usr/bin/env bash
# yt-transcript.sh — read a video: metadata, description, and transcript.
#
# The keyless road to a YouTube source. The Pi harness's own YouTube mode needs
# GEMINI_API_KEY or a signed-in Chromium and fails closed on a bare box; yt-dlp
# needs neither. Bragi (marketing) and Huginn (research) reach for this first.
#
#   bin/yt-transcript.sh <url>              # metadata + description + transcript
#   bin/yt-transcript.sh <url> --meta       # metadata + description only (no captions)
#   bin/yt-transcript.sh <url> --out DIR    # where the transcript lands (default /tmp)
#
# Output is Galdr TOON on stdout; the transcript text goes to <out>/<id>.txt.
# Exit: 0 all three read, 3 partial (metadata yes, transcript no), 1 error, 2 usage.
set -u

VERSION="1.0.0"
URL=""; META_ONLY=0; OUT="/tmp"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

URL="${1:-}"; shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --meta) META_ONLY=1; shift ;;
    --out) OUT="${2:-/tmp}"; shift 2 ;;
    --out=*) OUT="${1#--out=}"; shift ;;
    *) shift ;;
  esac
done
[ -n "$URL" ] || { printf 'error: usage: bin/yt-transcript.sh <url> [--meta] [--out DIR]\n' >&2; exit 2; }

command -v yt-dlp >/dev/null 2>&1 || { printf 'error: yt-dlp not on PATH\nhelp: install yt-dlp (no key, no account needed)\n' >&2; exit 1; }
mkdir -p "$OUT" 2>/dev/null || true

# 1. metadata — title | uploader | duration (s) | upload date
meta="$(yt-dlp --skip-download --print '%(title)s|%(uploader)s|%(duration)s|%(upload_date)s|%(id)s' "$URL" 2>/dev/null)"
[ -n "$meta" ] || { printf 'error: could not read the video (bad url, or YouTube refused)\n' >&2; exit 1; }

id="$(printf '%s' "$meta" | cut -d'|' -f5)"
title="$(printf '%s' "$meta" | cut -d'|' -f1)"
uploader="$(printf '%s' "$meta" | cut -d'|' -f2)"
duration="$(printf '%s' "$meta" | cut -d'|' -f3)"
date="$(printf '%s' "$meta" | cut -d'|' -f4)"

# 2. the description — often the real payload (chapters, links, the thesis)
desc="$(yt-dlp --skip-download --print '%(description)s' "$URL" 2>/dev/null)"
desc_file="$OUT/$id.description.txt"
[ -n "$desc" ] && printf '%s\n' "$desc" >"$desc_file" 2>/dev/null || desc_file=""

printf 'yt-transcript[1]{id,title,uploader,duration_s,date,description}:\n  "%s","%s","%s",%s,"%s","%s"\n' \
  "$id" "$title" "$uploader" "${duration:-0}" "$date" "${desc_file:-none}"

if [ "$META_ONLY" = "1" ]; then
  printf 'yt-transcript[1]{transcript,state}:\n  "none","skipped (--meta)"\n'
  exit 0
fi

# 3. the transcript — auto-generated when none is published. YouTube throttles
#    caption fetches (429); retry with a pause, and report partial honestly.
vtt=""; attempt=1
while [ "$attempt" -le 3 ]; do
  if yt-dlp --skip-download --write-auto-sub --sub-lang en --sub-format vtt \
       -o "$OUT/%(id)s.%(ext)s" "$URL" >/dev/null 2>&1; then
    vtt="$(ls "$OUT/$id".*.vtt 2>/dev/null | head -1)"; [ -n "$vtt" ] && break
  fi
  attempt=$((attempt + 1)); sleep 5
done

if [ -z "$vtt" ] || [ ! -r "$vtt" ]; then
  printf 'yt-transcript[1]{transcript,state}:\n  "none","unavailable — YouTube refused the captions (429); metadata still read"\n'
  exit 3
fi

txt="$OUT/$id.txt"
# VTT -> plain text: drop the header, the cue timings, the tags, and the
# consecutive duplicate lines the generator emits.
sed -e '/^WEBVTT/d' -e '/^[0-9][0-9]:[0-9][0-9]/d' -e '/^$/d' "$vtt" \
  | sed 's/<[^>]*>//g' | uniq >"$txt" 2>/dev/null || true

printf 'yt-transcript[1]{transcript,path,lines}:\n  "ok","%s",%s\n' "$txt" "$(wc -l <"$txt" 2>/dev/null || echo 0)"
exit 0
