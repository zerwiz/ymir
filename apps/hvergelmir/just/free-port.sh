#!/usr/bin/env sh
# Stop whatever listens on a TCP port so a server can take it: SIGTERM, then SIGKILL after 5s.
port="$1"
pids=$(lsof -ti "tcp:$port" -sTCP:LISTEN 2>/dev/null)
[ -z "$pids" ] && exit 0
echo "port $port in use; stopping pid $(echo $pids)" >&2
kill $pids 2>/dev/null
i=0
while [ $i -lt 10 ]; do
  sleep 0.5
  lsof -ti "tcp:$port" -sTCP:LISTEN >/dev/null 2>&1 || exit 0
  i=$((i + 1))
done
# Ask the holder to stop, give it a moment to close its sockets, and only then insist. SIGKILL leaves the port in
# TIME_WAIT and takes the process's own cleanup with it; the portability ward (check_platform) refuses a bare kill -9
# for that reason.
pids="$(lsof -ti "tcp:$port" -sTCP:LISTEN 2>/dev/null)"
if [ -n "$pids" ]; then
  kill $pids 2>/dev/null
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    lsof -ti "tcp:$port" -sTCP:LISTEN >/dev/null 2>&1 || break
    sleep 0.5
  done
  # a holder that ignored TERM for five seconds is wedged; blunt kill, reason declared
  lsof -ti "tcp:$port" -sTCP:LISTEN >/dev/null 2>&1 && kill -9 $pids 2>/dev/null  # kill: wedged after TERM and five seconds of waiting
fi
exit 0
