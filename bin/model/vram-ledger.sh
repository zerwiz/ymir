#!/usr/bin/env bash
# vram-ledger.sh — WHO HOLDS THE CARD, and how much of it.
#
# WHY THIS EXISTS (plan 275 item 23, measured 2026-11-14 03:16): the rail failed to load
# `qwen3.6-35b-a3b@q4_k_xl-mtp` (cudaMalloc of 1,184 MiB) and `apodex-1.0-mini`
# (3,314 MiB) — out of memory — while Rödd's voice engine (`speech-to-speech serve`) held
# 2,762 MiB and voxtype 480 MiB on the same 16 GiB card. OmniChat's other road was the rail,
# so both roads failed at once and the chat could only say "no model backend answered".
#
# A machine with one card cannot serve everything at once, so somebody has to say who is
# holding it. This door says exactly that and nothing more: the numbers, the holders, and a
# verdict. It never stops anything (the voice's own idle-out is bin/voice/voice-idle.sh).
#
#   vram-ledger.sh who            the holders and the verdict, TOON (agent-facing)
#   vram-ledger.sh who --json     the same as JSON (the gate's chat reads this)
#   vram-ledger.sh --busy-with-voice   exit 0 when the VOICE holds the card and the rail holds nothing
#   vram-ledger.sh --check        exit 0 when the ledger could be read at all, 1 (loudly) when not
#   vram-ledger.sh --version
#
# AGNOSTIC (RULES/25): NVIDIA is read through `nvidia-smi`; anything else (no discrete card,
# macOS, a hand-held seat) reports `known: false` WITH THE REASON — a chat then says only
# what it knows instead of inventing a voice it cannot see.
#
# Env:
#   YMIR_VOICE_HOLD_MIB   the MiB that counts as "the voice holds the card" (default 1500)
set -u
VERSION="1.0.0"
case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

HOLD_MIB="${YMIR_VOICE_HOLD_MIB:-1500}"
VERB="${1:-who}"; shift || true
JSON=0; BUSY=0
case "$VERB" in
  who) ;;
  --busy-with-voice|busy-with-voice) BUSY=1; VERB=who ;;
  --check|check) VERB=check ;;
  *) printf 'error: unknown verb %s\nhelp: vram-ledger.sh [who [--json] | --busy-with-voice | --check]\n' "$VERB" >&2; exit 2 ;;
esac
while [ $# -gt 0 ]; do case "$1" in --json) JSON=1 ;; *) ;; esac; shift; done

have() { command -v "$1" >/dev/null 2>&1; }

# The voice engine is named by what it IS, not by a pid anyone handed us: the streaming
# pipeline (`speech-to-speech`), Rödd's face, and the small TTS server the voice also uses.
is_voice() { case "$1" in *speech-to-speech*|*s2s*|*rodd*|*kokoro*) return 0 ;; esac; return 1; }
is_rail()  { case "$1" in *llama-server*|*llama_server*|*llama-swap*|*llamacpp*) return 0 ;; esac; return 1; }

ledger() {  # prints JSON on stdout; exits 3 when the card cannot be read
  if ! have nvidia-smi || ! nvidia-smi -L >/dev/null 2>&1; then
    printf '{"known":false,"reason":"no NVIDIA card this door can read (nvidia-smi answered nothing)"}\n'
    return 3
  fi
  local total used
  total="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -dc '0-9')"
  used="$(nvidia-smi --query-gpu=memory.used  --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -dc '0-9')"
  total="${total:-0}"; used="${used:-0}"
  python3 - "$total" "$used" <<'PY'
import json, subprocess, sys
total, used = int(sys.argv[1] or 0), int(sys.argv[2] or 0)
holders = []
try:
    out = subprocess.run(["nvidia-smi", "--query-compute-apps=pid,process_name,used_memory",
                          "--format=csv,noheader,nounits"], capture_output=True, timeout=10)
    for line in out.stdout.decode("utf-8", "replace").splitlines():
        parts = [p.strip() for p in line.split(",")]
        if len(parts) < 3 or not parts[0].isdigit():
            continue
        pid, name, mib = int(parts[0]), parts[1], int(parts[2] or 0)
        # A VRAM holder is named by its EXECUTABLE (`.../venvs/s2s/bin/python`), which says
        # nothing about what it is doing — the engine's entry point is an argument. So the
        # command line decides, and the executable is only the fallback (measured 2026-11-14:
        # the voice engine showed up as `python` and the ledger called it "other").
        try:
            with open("/proc/%d/cmdline" % pid, "rb") as f:
                cmdline = f.read(4096).replace(b"\x00", b" ").decode("utf-8", "replace").strip()
        except OSError:
            cmdline = ""
        what = cmdline or name
        if "speech-to-speech" in what or "s2s" in what or "rodd" in what or "kokoro" in what:
            who = "voice"
        elif "llama-server" in what or "llama_server" in what or "llama-swap" in what:
            who = "rail"
        else:
            who = "other"
        # The command line is used to CLASSIFY and then thrown away: a holder's argv can
        # carry a bearer key (the voice engine takes its head key as a flag), and this door
        # prints what it sees in a chat. The executable's name is all that leaves here.
        holders.append({"who": who, "pid": pid, "name": name, "mib": mib})
except Exception:
    pass
voice = sum(h["mib"] for h in holders if h["who"] == "voice")
rail = sum(h["mib"] for h in holders if h["who"] == "rail")
print(json.dumps({
    "known": True, "total_mib": total, "used_mib": used,
    "free_mib": max(0, total - used), "holders": holders,
    "voice_mib": voice, "rail_mib": rail, "rail_resident": rail > 0,
}, separators=(",", ":")))
PY
}

case "$VERB" in
  check)
    out="$(ledger)"; rc=$?
    if [ "$rc" -ne 0 ]; then
      printf '%s\n' "$out" | python3 -c 'import json,sys;d=json.load(sys.stdin);print("check{vram}:\n  readable FAIL -> "+d.get("reason",""))' >&2
      printf 'help: this door reads the card through nvidia-smi; on a seat without one the chat says only what it knows\n' >&2
      exit 1
    fi
    printf '%s\n' "$out" | python3 -c 'import json,sys;d=json.load(sys.stdin);print("check{vram}:\n  readable PASS -> %s of %s MiB used, voice %s MiB, rail %s MiB" % (d["used_mib"], d["total_mib"], d["voice_mib"], d["rail_mib"]))'
    exit 0 ;;
esac

out="$(ledger)"; rc=$?

if [ "$BUSY" = 1 ]; then
  [ "$rc" -eq 0 ] || exit 1
  printf '%s\n' "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
hold = int(sys.argv[1])
busy = d.get("voice_mib", 0) >= hold and not d.get("rail_resident", False)
raise SystemExit(0 if busy else 1)' "$HOLD_MIB"
  exit $?
fi

if [ "$JSON" = 1 ]; then
  printf '%s\n' "$out"
  exit 0
fi

# The JSON is passed as an ARGUMENT, never on stdin: a heredoc would take stdin and the
# pipe would be silently ignored (the door then died on an empty document).
python3 - "$HOLD_MIB" "$out" <<'PY'
import json, sys
d = json.loads(sys.argv[2])
hold = int(sys.argv[1])
if not d.get("known"):
    print("vram[1]{known,reason}:")
    print('  "no","%s"' % d.get("reason", "unreadable"))
    raise SystemExit(0)
rows = d.get("holders") or []
print("vram[%d]{holder,pid,mib}:" % len(rows))
for h in rows:
    print('  "%s",%d,%d' % (h["who"], h["pid"], h["mib"]))
verdict = "free"
if d.get("voice_mib", 0) >= hold and not d.get("rail_resident"):
    verdict = "the voice holds the card"
elif d.get("rail_resident"):
    verdict = "the rail holds the card"
print("card[4]{total_mib,used_mib,free_mib,verdict}:")
print('  %d,%d,%d,"%s"' % (d["total_mib"], d["used_mib"], d["free_mib"], verdict))
PY
exit 0
