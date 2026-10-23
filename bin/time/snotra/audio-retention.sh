#!/usr/bin/env bash
# audio-retention.sh — Rule 30 in one command: turn the sound into text, then let the sound go.
#
#   audio-retention.sh scan    [--hours 24] [--cap-mb 2048]
#   audio-retention.sh apply   [--hours 24] [--cap-mb 2048] [--force]
#                              [--archive DIR]     move the compressed audio to a cold shelf
#                              [--send HOST:PATH]  send it to a remote disk (rsync over ssh)
#
# WHAT IT TOUCHES
#   1. meeting audio under <home>/hodd/life/meetings/**  (*.wav *.ogg *.opus *.mp3 *.webm)
#   2. the meeting bot's recording shelf (the Vexa storage volume), oldest first
#   3. stray captures in /tmp (meeting-mic-*.wav and friends)
#
# WHAT IT NEVER DOES
#   * it never deletes audio that has no transcript, unless --force is given (Rule 30: a deleted
#     meeting with no text is a lost meeting);
#   * it never deletes a transcript, minutes file, card or record — text is the record;
#   * it never removes the NEWEST audio to satisfy a cap: oldest first, always.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'audio-retention: the hoard is unresolved\n' >&2; exit 2; }
ACTION="${1:-scan}"; shift || true
HOURS="${SNOTRA_AUDIO_HOURS:-24}"; CAP_MB="${SNOTRA_AUDIO_CAP_MB:-2048}"; FORCE=0
ARCHIVE="${SNOTRA_AUDIO_ARCHIVE:-}"; SEND="${SNOTRA_AUDIO_SEND:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --hours) HOURS="${2:-24}"; shift 2 ;;
    --cap-mb) CAP_MB="${2:-2048}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --archive) ARCHIVE="${2:-}"; shift 2 ;;
    --send) SEND="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
# a drive plugged in later is the cold shelf: /run/media/<user>/<LABEL> or /media/<LABEL>
if [ -z "$ARCHIVE" ] && [ -d /run/media ]; then
  ARCHIVE="$(find /run/media -maxdepth 2 -mindepth 2 -type d 2>/dev/null | head -1)"
fi
[ "$ACTION" = "scan" ] || [ "$ACTION" = "apply" ] || { printf 'usage: audio-retention.sh scan|apply\n' >&2; exit 2; }

# Every meetings shelf under the home, discovered — not one hard-coded path. Measured 2026-10-23: the
# old single path (`hodd/life/meetings`) reported 0 files / 0 B while five real recordings sat on disk,
# because the company meetings live in `svartalfaheim/<realm>/meetings/`. A door that scans the wrong
# shelf is a door that says "nothing to do" while the disk fills.
STAGE="${SNOTRA_HARVEST_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir/snotra-harvest}"
MEETINGS="$(ls -d "$HOME_R"/hodd/life/meetings "$HOME_R"/svartalfaheim/*/meetings \
  "$HOME_R"/svartalfaheim/*/projects/*/meetings "$HOME_R"/svartalfaheim/*/workspace/*/meetings \
  "$STAGE" 2>/dev/null | paste -sd: -)"
[ -n "$MEETINGS" ] || MEETINGS="$HOME_R/hodd/life/meetings"
HOURS_Q="$HOURS" CAP_Q="$CAP_MB" FORCE_Q="$FORCE" ACTION_Q="$ACTION" MEETINGS_Q="$MEETINGS" \
ARCHIVE_Q="$ARCHIVE" SEND_Q="$SEND" \
ROOT_Q="$ROOT" HOME_Q="$HOME_R" python3 - <<'PY'
import os, subprocess, time

hours = float(os.environ["HOURS_Q"]); cap_mb = float(os.environ["CAP_Q"])
force = os.environ["FORCE_Q"] == "1"; action = os.environ["ACTION_Q"]
meetings = os.environ["MEETINGS_Q"]; root = os.environ["ROOT_Q"]; home = os.environ["HOME_Q"]
cutoff = time.time() - hours * 3600
AUDIO = (".wav", ".ogg", ".opus", ".mp3", ".webm")

def transcripts_for(base: str) -> bool:
    """A transcript is a sibling .md/.txt/.json with the same stem — or a minutes file in the dir."""
    stem = os.path.splitext(base)[0]
    for ext in (".md", ".txt", ".json", ".jsonl"):
        if os.path.exists(stem + ext):
            return True
    d = os.path.dirname(base)
    for name in os.listdir(d) if os.path.isdir(d) else []:
        if name.endswith((".md", ".json")) and os.path.splitext(base)[0].split("-")[-1][:6] in name:
            return True
    return False

def compress(path: str, archive: str) -> tuple[bool, str]:
    """Speech does not need PCM: Opus at 24 kbit/s mono is ~1/10 the size and still words.
    The source is deleted ONLY after the encoded file exists and is non-empty."""
    import datetime as dt
    out_dir = archive or os.path.dirname(path)
    if archive:
        out_dir = os.path.join(archive, dt.date.today().strftime("%Y-%m"))
        os.makedirs(out_dir, exist_ok=True)
    stem = os.path.splitext(os.path.basename(path))[0]
    out = os.path.join(out_dir, stem + ".opus")
    if os.path.exists(out) and os.path.getsize(out) > 0:
        try:
            os.unlink(path); return True, out
        except OSError:
            return False, out
    r = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", path,
                        "-c:a", "libopus", "-b:a", "24k", "-ar", "16000", "-ac", "1", out],
                       capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(out) or os.path.getsize(out) == 0:
        return False, r.stderr.strip()[:120]
    try:
        os.unlink(path)
    except OSError:
        pass
    return True, out


def human(n: float) -> str:
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024: return f"{n:.0f}{unit}"
        n /= 1024
    return f"{n:.1f}TiB"

rows = []
def collect(base_dir: str, pattern_ok) -> None:
    for dirpath, _dirs, files in os.walk(base_dir):
        for name in files:
            if not name.lower().endswith(AUDIO) or not pattern_ok(name):
                continue
            path = os.path.join(dirpath, name)
            try:
                st = os.stat(path)
            except OSError:
                continue
            rows.append({"path": path, "size": st.st_size, "mtime": st.st_mtime,
                          "has_text": transcripts_for(path)})

for shelf in [m for m in meetings.split(":") if m and os.path.isdir(m)]:
    collect(shelf, lambda n: True)
collect("/tmp", lambda n: n.startswith(("meeting-mic-", "snotra-")) or "meeting" in n.lower())

rows.sort(key=lambda r: r["mtime"])
total = sum(r["size"] for r in rows)
stale = [r for r in rows if r["mtime"] < cutoff]
cap_over = total - cap_mb * 1024 * 1024
evict = []
if cap_over > 0:
    for r in rows:
        if cap_over <= 0: break
        if r not in evict:
            evict.append(r); cap_over -= r["size"]

print('audio[1]{shelf,files,total,cap_mb,older_than_h}:')
print(f'  "{meetings}","{len(rows)}","{human(total)}","{cap_mb:.0f}","{hours:.0f}"')
print('audio_rows{n,file,size,age_h,transcript,verdict}:')
print(f"audio_rows{len(rows)}")
gone = 0
for r in rows:
    age = (time.time() - r["mtime"]) / 3600
    old = r["mtime"] < cutoff
    capped = r in evict
    if (old or capped) and (r["has_text"] or force):
        verdict = "delete"
    elif (old or capped):
        verdict = "KEEP — no transcript (Rule 30)"
    else:
        verdict = "keep"
    if verdict == "delete" and action == "apply":
        if r["path"].lower().endswith(".opus"):
            # ALREADY compressed: it is the archive copy, not raw capture. It goes to the cold/far
            # shelf if one is configured; with no shelf it STAYS (Rule 30: offload, do not destroy).
            # Measured 2026-10-23: the first run deleted two .opus files — their transcripts survived,
            # but the audio did not, which is the opposite of what the Allfather asked for.
            archive = os.environ.get("ARCHIVE_Q", "")
            if archive and os.access(archive, os.W_OK):
                import datetime as dt, shutil
                out_dir = os.path.join(archive, dt.date.today().strftime("%Y-%m"))
                os.makedirs(out_dir, exist_ok=True)
                dest = os.path.join(out_dir, os.path.basename(r["path"]))
                try:
                    shutil.move(r["path"], dest)
                    gone += 1; verdict = f"offloaded → {os.path.basename(dest)}"
                except OSError as exc:
                    verdict = f"offload failed: {exc}"
            else:
                verdict = "keep — already compressed, no cold shelf to offload to"
        else:
            ok, where = compress(r["path"], os.environ.get("ARCHIVE_Q", ""))
            if ok:
                gone += 1
                verdict = f"compressed → {os.path.basename(where)}"
            else:
                verdict = f"compress failed: {where}"
    print(f'  "{os.path.basename(r["path"])}","{human(r["size"])}","{age:.1f}","{"yes" if r["has_text"] else "no"}","{verdict}"')
send_to = os.environ.get("SEND_Q", "")
if send_to and action == "apply":
    # the cold shelf is a DISK, not a guess: rsync verifies, and the local file goes only after it lands
    src_dir = os.environ.get("ARCHIVE_Q", "") or meetings
    r = subprocess.run(["rsync", "-a", "--remove-source-files", src_dir.rstrip("/") + "/",
                        send_to.rstrip("/") + "/"], capture_output=True, text=True, timeout=3600)
    print(f'audio_sent[2]{{target,result}}: "{send_to}","{"ok" if r.returncode == 0 else r.stderr.strip()[:120]}"')

if action == "apply":
    print(f'audio_removed[1]{{files}}: "{gone}"')
    if gone:
        subprocess.run(["bash", os.path.join(root, "bin", "records", "runes-append.sh"), "brokk",
                        "retention", "--message",
                        f"Audio retention: removed {gone} file(s) under Rule 30 "
                        f"(hours={hours:.0f}, cap={cap_mb:.0f}MB)"],
                       check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
PY
