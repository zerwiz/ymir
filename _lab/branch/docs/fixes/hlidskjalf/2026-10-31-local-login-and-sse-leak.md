# Fix: local login exemption + SSE interval leak

- /api/session and /api/* now treat loopback (localhost/127.0.0.1/::1) requests as authenticated when HLIDSKJALF_AUTH is set, so the local desktop seat opens without a login while the tunnelled door still demands one.
- /api/stream's ReadableStream cancel() now clears its setInterval, preventing a leaked 2s timer polling runes_audit.md after a tab closes.
