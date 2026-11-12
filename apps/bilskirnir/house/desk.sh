#!/usr/bin/env bash
# desk.sh — the door to the hall's own computer: one Linux desktop in a container, one screen per agent.
#
#   house/desk.sh up        build the image if it is missing, then start the desk (idempotent)
#   house/desk.sh down      stop the desk (its home volume, with the agents' browser profiles, stays)
#   house/desk.sh status    one line: image=… container=… screens=…   (exit 0 only when up)
#   house/desk.sh build     (re)build the image from house/desk/
#   house/desk.sh --check   same as status, for setup.sh --check
#
# The desk listens on loopback only: each screen is an Xvnc display whose RFB port is
# BILSKIRNIR_DESK_VNC_BASE + (display - 99), bound to 127.0.0.1, and the container shares the host's
# network so the agents' Chrome DevTools ports (9200 + display) are on the same loopback for Hermes.
# The VNC password lives in data/desk/vnc.pass (0600, git-ignored); the app's server reads it and does
# the VNC handshake itself, so the password never reaches a browser (server/src/vnc.ts).
#
# Settings (RULES/07), each with one documented default:
#   BILSKIRNIR_DESK_IMAGE      the image                      (ymir/bilskirnir-desk:1)
#   BILSKIRNIR_DESK_CONTAINER  the container's name           (bilskirnir-desk)
#   BILSKIRNIR_DESK_VNC_BASE   RFB port of the first screen   (5990)
#   BILSKIRNIR_DESK_GEOMETRY   each screen's size             (1280x800)
#   BILSKIRNIR_DESK_DIR        where the password is kept     (apps/bilskirnir/data/desk)
#   DOCKER                     the container engine's CLI     (docker)
set -u
APP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${BILSKIRNIR_DESK_IMAGE:-ymir/bilskirnir-desk:1}"
NAME="${BILSKIRNIR_DESK_CONTAINER:-bilskirnir-desk}"
BASE="${BILSKIRNIR_DESK_VNC_BASE:-5990}"
GEOMETRY="${BILSKIRNIR_DESK_GEOMETRY:-1280x800}"
DIR="${BILSKIRNIR_DESK_DIR:-$APP/data/desk}"
DOCKER="${DOCKER:-docker}"
say() { printf 'desk: %s\n' "$*"; }

have_engine() { command -v "$DOCKER" >/dev/null 2>&1 && "$DOCKER" info >/dev/null 2>&1; }
image_present() { "$DOCKER" image inspect "$IMAGE" >/dev/null 2>&1; }
# Where the running desk reads its VNC password from. It is bound once, when the container is made, to the
# checkout that raised it — and the app reads data/desk/vnc.pass of ITS OWN checkout. Two checkouts (a worktree
# and the pinned runtime) are two passwords: every screen then answers "Authentication failure" and the panel
# says "Couldn't reach <agent>'s screen" (2026-11-12, a new agent's first screen).
secret_source() { "$DOCKER" inspect -f '{{range .Mounts}}{{if eq .Destination "/run/desk-secret"}}{{.Source}}{{end}}{{end}}' "$NAME" 2>/dev/null; }
state() { local s; s="$("$DOCKER" inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null)" && [ -n "$s" ] && echo "$s" || echo absent; }

build() { say "building $IMAGE from house/desk/"; "$DOCKER" build -q -t "$IMAGE" "$APP/house/desk" >/dev/null; }

password() {
  mkdir -p "$DIR" && chmod 700 "$DIR"
  # VNC's own authentication uses the first eight characters; eight random ones are the whole key.
  [ -s "$DIR/vnc.pass" ] || { (umask 077; head -c 64 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 8 > "$DIR/vnc.pass"); }
}

up() {
  have_engine || { say "no container engine ($DOCKER) answers — the desk cannot start here"; return 1; }
  image_present || build || { say "the image did not build"; return 1; }
  password
  # a desk bound to another checkout's password is recreated (its home volume, the browser profiles, stays)
  if [ "$(state)" != absent ] && [ "$(secret_source)" != "$(cd "$DIR" && pwd -P)" ]; then
    say "the desk was raised from another checkout ($(secret_source)) — recreating it for $DIR"
    "$DOCKER" rm -f "$NAME" >/dev/null 2>&1
  fi
  case "$(state)" in
    running) ;;
    absent)
      "$DOCKER" run -d --name "$NAME" --network host --shm-size 1g \
        -e "DESK_VNC_BASE=$BASE" -e "DESK_GEOMETRY=$GEOMETRY" \
        -v "$DIR:/run/desk-secret:ro" -v "$NAME-root:/root" \
        --label ymir.app=bilskirnir "$IMAGE" >/dev/null || { say "the desk did not start"; return 1; } ;;
    *) "$DOCKER" start "$NAME" >/dev/null || { say "the desk did not start"; return 1; } ;;
  esac
  for _ in $(seq 1 50); do "$DOCKER" exec "$NAME" desk-screen list 2>/dev/null | grep -q '^99 ' && break; sleep 0.2; done
  status
}

down() { [ "$(state)" = running ] && "$DOCKER" stop -t 5 "$NAME" >/dev/null; say "down"; }

status() {
  have_engine || { echo "image=unknown container=no-engine screens=0"; return 1; }
  local img=absent st screens=0
  image_present && img=present
  st="$(state)"
  [ "$st" = running ] && screens="$("$DOCKER" exec "$NAME" desk-screen list 2>/dev/null | wc -l)"
  local other=""
  # a password the screens do not share with the app is a desk nobody can look at — say so, fail
  [ "$st" = running ] && [ "$(secret_source)" != "$(cd "$DIR" 2>/dev/null && pwd -P)" ] && other=" secret=other-checkout"
  echo "image=$img container=$st screens=$screens$other"
  [ -z "$other" ] || return 1
  [ "$img" = present ] && [ "$st" = running ]
}

case "${1-status}" in
  up) up ;;
  down) down ;;
  status|--check) status ;;
  build) have_engine && build ;;
  -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) say "unknown verb '${1-}' (up | down | status | build)"; exit 2 ;;
esac
