#!/usr/bin/env bash
# test_browserkill_note.sh — plan 271 piece 5: a planted scope stop is named, with the GPU's side.
# No bpftrace, no root: the tracer's journal lines are planted on stdin and nvidia-smi is a stand-in.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; N="$HERE/../browserkill-note.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/smi" <<'S'
#!/usr/bin/env bash
case "$*" in
  *query-compute-apps*) echo "4242, python3, 900 MiB" ;;
  *) printf 'Processes:\n|  GPU   GI   CI    PID   Type   Process name   GPU Memory |\n|    0   N/A  N/A   1337    G   chromium     210MiB |\n' ;;
esac
S
chmod +x "$T/smi"
fail=0; ok() { printf 'ok   %s\n' "$1"; }; no() { printf 'FAIL %s\n' "$1"; fail=1; }
out="$(printf '%s\n' \
  '13:56:34 CGKILL from=systemd(1282) unit=app-org.chromium.Chromium-212514.scope' \
  '13:56:34 DIE chromium pid=212514 code=9 sig=9' \
  '13:56:35 SEND sig=15 from=bash(1) to=chromium(5)' \
  | YMIR_NVIDIA_SMI="$T/smi" YMIR_NOTE_SCOPES=0 YMIR_NOTE_DEBOUNCE_S=0 bash "$N")"
grep -q "unit=app-org.chromium.Chromium-212514.scope" <<<"$out" && ok "the scope that fell is named, with its writer" || no "scope: $out"
grep -q "gpu compute: 4242, python3" <<<"$out" && ok "the GPU's compute processes are written at the death" || no "gpu: $out"
grep -q "gpu: .*1337" <<<"$out" && ok "the graphics processes are written too" || no "gfx: $out"
grep -q "SEND sig=15" <<<"$out" && no "a plain SIGTERM must not raise a note" || ok "a plain SIGTERM is not a kill note"
grep -q "CGKILL" "$HERE/../browserkill.bt" && grep -q "cgroup_kill_write" "$HERE/../browserkill.bt" && ok "the probe carries the cgroup.kill door" || no "probe lacks cgroup_kill_write"
exit $fail
