#!/usr/bin/env bash
# browserkill-note.sh — at every browser/Discord death, write down the GPU's side of it (plan 271 piece 5).
#
# bpftrace (bin/ward/browserkill.bt) says WHO signalled and which scope fell. It cannot ask the card.
# This reads the tracer's journal lines on stdin and, at each `DIE ... sig=9` of a main process or a
# CGKILL / OOMKILL line, prints a one-block note: the line, the GPU processes at that instant, and
# the user manager's recent scope endings — so an unsigned SIGKILL has the context to be named.
#
#   journalctl -fu browserkill-trace -o cat | bin/ward/browserkill-note.sh      (the unit does this)
#
# Env: YMIR_NVIDIA_SMI (default nvidia-smi) · YMIR_NOTE_DEBOUNCE_S (default 5) · YMIR_NOTE_SCOPES=0 skips the scope log
set -u
SMI="${YMIR_NVIDIA_SMI:-nvidia-smi}"; DEB="${YMIR_NOTE_DEBOUNCE_S:-5}"; last=0
gpu_now() {
  command -v "$SMI" >/dev/null 2>&1 || { echo "  gpu: no nvidia-smi on this seat"; return; }
  "$SMI" --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>/dev/null | sed 's/^/  gpu compute: /'
  "$SMI" 2>/dev/null | sed -n '/Processes:/,$p' | grep -E '^\| +[0-9]+ ' | sed 's/^/  gpu: /' | head -20
}
while IFS= read -r line; do
  case "$line" in
    *" CGKILL "*|*" OOMKILL "*) ;;
    *" DIE "*"sig=9"*) case "$line" in *"code=9"*) ;; *) continue ;; esac ;;
    *) continue ;;
  esac
  now=$(date +%s); [ $((now - last)) -ge "$DEB" ] || { printf 'note: %s\n' "$line"; continue; }
  last=$now
  printf 'KILL-NOTE %s\n  trace: %s\n' "$(date -Is)" "$line"
  gpu_now
  if [ "${YMIR_NOTE_SCOPES:-1}" = 1 ] && command -v journalctl >/dev/null 2>&1; then
    journalctl --user --since "-30s" --no-pager -o cat 2>/dev/null | grep -E 'scope: (Consumed|Deactivated|Failed)|Stopping|Stopped' | tail -6 | sed 's/^/  scope: /'
  fi
done
