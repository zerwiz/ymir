#!/usr/bin/env bash
# search-ensure.sh — keep the house's own web search standing: a SearXNG container on loopback (plan 275).
#
#   bin/voice/search-ensure.sh            ensure it answers (create, or start, the container)
#   bin/voice/search-ensure.sh status     say whether it answers, and from where
#   bin/voice/search-ensure.sh --stop     stop the container (it is kept, not removed)
#
# WHY. Rödd's web_search reads the house's own SearXNG (open source, no key, no account) at YMIR_SEARCH_URL, default
# http://127.0.0.1:8899. It was raised by hand on two of our machines (2026-11-12/13), and nothing in the repo knew it
# existed — so a fresh install had no search, and a machine with docker.service disabled (socket only) would have lost
# it at the next reboot. Rödd's start runs this, so a reboot is healed by her first start: `docker start` knocks on
# the socket and the socket wakes docker.
#
# The container never takes the desktop's breath: one CPU, 512 MB, bound to 127.0.0.1 only. Its settings (a random
# secret, the JSON format turned on) live in ~/.config/ymir/searxng, never in this repository.
#
# If YMIR_SEARCH_URL points at another machine's instance, nothing is raised here. No docker: a loud skip, exit 3.
set -u
NAME="${YMIR_SEARCH_CONTAINER:-ymir-searxng}"
URL="${YMIR_SEARCH_URL:-http://127.0.0.1:8899}"
PORT="${URL##*:}"; PORT="${PORT%%/*}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/ymir/searxng"
IMAGE="${YMIR_SEARCH_IMAGE:-searxng/searxng:latest}"
say() { printf 'search\t%s\t%s\n' "$1" "$2"; }

answers() { curl -s -o /dev/null --max-time 4 -w '%{http_code}' "$URL/search?q=ymir&format=json" 2>/dev/null | grep -q '^200$'; }

case "$URL" in http://127.0.0.1:*|http://localhost:*) local_url=1 ;; *) local_url=0 ;; esac

case "${1:-ensure}" in
  status)
    if answers; then say up "$URL"; exit 0; fi
    say down "$URL"; exit 1 ;;
  --stop)
    docker stop "$NAME" >/dev/null 2>&1 && say stopped "$NAME" || say "not running" "$NAME"; exit 0 ;;
  ensure) ;;
  *) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac

if answers; then say up "$URL"; exit 0; fi
if [ "$local_url" = 0 ]; then say down "$URL is another machine's; nothing is raised here"; exit 1; fi
command -v docker >/dev/null 2>&1 || { say skipped "no docker on this machine — web search needs SearXNG at $URL"; exit 3; }

if [ ! -f "$CONF/settings.yml" ]; then
  mkdir -p "$CONF"
  key="$(head -c 48 /dev/urandom | base64 | tr -dc A-Za-z0-9 | head -c 40)"
  umask 077
  printf 'use_default_settings: true\nserver:\n  secret_key: "%s"\n  limiter: false\n  image_proxy: false\nsearch:\n  formats: [html, json]\n' "$key" > "$CONF/settings.yml"
fi

if docker inspect "$NAME" >/dev/null 2>&1; then
  docker start "$NAME" >/dev/null 2>&1 || { say failed "docker start $NAME"; exit 1; }
else
  docker run -d --name "$NAME" --restart unless-stopped -p "127.0.0.1:$PORT:8080" \
    -v "$CONF:/etc/searxng:rw" --cpus 1 --memory 512m "$IMAGE" >/dev/null 2>&1 \
    || { say failed "docker run $IMAGE"; exit 1; }
fi
for _ in $(seq 1 30); do answers && { say up "$URL"; exit 0; }; sleep 2; done
say failed "$NAME runs but $URL does not answer — docker logs $NAME"; exit 1
