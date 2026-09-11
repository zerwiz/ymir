# YMIR — scripts

Local run helpers. Both scripts are safe to call repeatedly.

## Hlidskjalf (control plane SPA)

```bash
scripts/start.sh          # raise the SPA  → http://127.0.0.1:3888/
scripts/start.sh --foreground   # run in the foreground (Ctrl-C to stop)
scripts/stop.sh           # lower it (process group, then port fallback)
scripts/stop.sh --force   # SIGKILL if TERM did not land
```

- Installs `apps/hlidskjalf` dependencies on first run if missing.
- Writes a PID file to `.run/hlidskjalf.pid` and logs to `.run/hlidskjalf.log`.
- `HLIDSKJALF_PORT` overrides the default port (`3888`).

## Notes

- Never `pkill -f` on a path that appears in your own command line — kill by the
  PID file (process group) or by port, as `stop.sh` does.
- `.run/` is runtime-only and must not be committed.
