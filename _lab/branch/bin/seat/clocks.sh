#!/usr/bin/env bash
# bin/seat/clocks.sh — seat the three loops: plan-watch, ship-watch, update-loop.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
USER_UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

# loop name | published script path (relative to repo root) | OnCalendar
LOOPS=(
  "plan-watch|bin/time/nornir-job-plan-watch.sh|*-*-* 07:30:00|true"
  "ship-watch|bin/forge/ship-watch.sh|*:0/5|false"
  "update-loop|bin/engine/update-loop.sh|*:0/15|false"
)

gen_service() {
  local name="$1" script="$2"
  local exec="$REPO/$script"
  cat <<UNIT
[Unit]
Description=$name (Ymir loop)

[Service]
Type=oneshot
ExecStart=$exec
UNIT
}

gen_timer() {
  local name="$1" oncal="$2" persistent="$3"
  local svc="ymir-$name.service"
  {
    echo "[Unit]"
    echo "Description=$name timer"
    echo ""
    echo "[Timer]"
    echo "OnCalendar=$oncal"
    [ "$persistent" = "true" ] && echo "Persistent=true"
    echo "Unit=$svc"
    echo ""
    echo "[Install]"
    echo "WantedBy=timers.target"
  }
}

cmd_status() {
  for entry in "${LOOPS[@]}"; do
    IFS='|' read -r name script oncal persistent <<< "$entry"
    local svc="ymir-$name.service"
    local tmr="ymir-$name.timer"
    local installed="no"
    [ -f "$USER_UNIT_DIR/$tmr" ] && installed="yes"
    local active="inactive"
    systemctl --user is-active "$tmr" 2>/dev/null | grep -q active && active="active"
    local last=""
    last=$(journalctl --user -u "$svc" -n 1 --no-pager -o short-iso 2>/dev/null | tail -n 1 || true)
    [ -z "$last" ] && last="(never ran)"
    echo "$name: installed=$installed active=$active last=$last"
  done
}

cmd_install() {
  local dry=0
  [ "${1:-}" = "--dry-run" ] && dry=1
  # refuse missing ExecStart
  for entry in "${LOOPS[@]}"; do
    IFS='|' read -r name script oncal persistent <<< "$entry"
    local exec="$REPO/$script"
    if [ ! -x "$exec" ] && [ ! -f "$exec" ]; then
      echo "REFUSE: ExecStart does not exist: $exec" >&2
      exit 1
    fi
  done
  for entry in "${LOOPS[@]}"; do
    IFS='|' read -r name script oncal persistent <<< "$entry"
    local svc="ymir-$name.service"
    local tmr="ymir-$name.timer"
    if [ "$dry" = "1" ]; then
      echo "===== $svc ====="
      gen_service "$name" "$script"
      echo ""
      echo "===== $tmr ====="
      gen_timer "$name" "$oncal" "$persistent"
      echo ""
    else
      mkdir -p "$USER_UNIT_DIR"
      gen_service "$name" "$script" > "$USER_UNIT_DIR/$svc"
      gen_timer "$name" "$oncal" "$persistent" > "$USER_UNIT_DIR/$tmr"
    fi
  done
  if [ "$dry" = "0" ]; then
    systemctl --user daemon-reload
    for entry in "${LOOPS[@]}"; do
      IFS='|' read -r name script oncal persistent <<< "$entry"
      systemctl --user enable --now "ymir-$name.timer" 2>/dev/null || true
    done
    echo "installed"
  fi
}

cmd_uninstall() {
  for entry in "${LOOPS[@]}"; do
    IFS='|' read -r name script oncal persistent <<< "$entry"
    systemctl --user disable --now "ymir-$name.timer" 2>/dev/null || true
    rm -f "$USER_UNIT_DIR/ymir-$name.timer" "$USER_UNIT_DIR/ymir-$name.service"
  done
  systemctl --user daemon-reload 2>/dev/null || true
  echo "uninstalled"
}

case "${1:-}" in
  status) cmd_status ;;
  install) shift; cmd_install "$@" ;;
  uninstall) cmd_uninstall ;;
  *) echo "usage: clocks.sh {status|install [--dry-run]|uninstall}" >&2; exit 2 ;;
esac
