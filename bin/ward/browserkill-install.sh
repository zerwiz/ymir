#!/usr/bin/env bash
# browserkill-install.sh — seat the kill tracer and its GPU note (plan 152 / 271). Needs root: run it with sudo.
#
#   sudo bin/ward/browserkill-install.sh            install and (re)start
#   bin/ward/browserkill-install.sh --check         what is seated, and whether it matches the repo
#
# Seats /etc/ymir/browserkill.bt (the probe), keeps browserkill-trace.service, and adds
# browserkill-note.service, which pipes the tracer's journal through browserkill-note.sh.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BT=/etc/ymir/browserkill.bt; UNIT=/etc/systemd/system/browserkill-note.service
if [ "${1-}" = --check ]; then
  cmp -s "$HERE/browserkill.bt" "$BT" && echo "probe: current" || echo "probe: STALE or absent — run: sudo $0"
  [ -f "$UNIT" ] && echo "note unit: seated" || echo "note unit: absent — run: sudo $0"
  exit 0
fi
[ "$(id -u)" = 0 ] || { echo "error: needs root — run: sudo $0" >&2; exit 1; }
command -v bpftrace >/dev/null 2>&1 || { echo "error: bpftrace is not installed" >&2; exit 1; }
install -d /etc/ymir
[ -f "$BT" ] && cp -p "$BT" "$BT.bak-$(date +%Y%m%d%H%M%S)"
install -m 0644 "$HERE/browserkill.bt" "$BT"
cat > "$UNIT" <<U
[Unit]
Description=Write the GPU's side of every browser kill (plan 271)
After=browserkill-trace.service
Requires=browserkill-trace.service

[Service]
Type=simple
ExecStart=/bin/bash -c 'journalctl -fu browserkill-trace -n 0 -o cat | exec $HERE/browserkill-note.sh'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl restart browserkill-trace.service && systemctl enable --now browserkill-note.service
sleep 2
systemctl is-active browserkill-trace.service browserkill-note.service
journalctl -u browserkill-trace -n 5 --no-pager -o cat | grep -i -E "error|cannot|unknown" && echo "warning: the probe reported an error above (a kprobe name this kernel lacks?)"
echo "read the next death: journalctl -u browserkill-note -n 40"
