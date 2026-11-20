#!/usr/bin/env bash
# tui-frame-check.sh — prove that what the TUI writes to the terminal fits the terminal.
#
#   bin/pi/tui-frame-check.sh [--cols 60] [--rows 18] [--mode regular|fullscreen|both] [--quiet]
#
# WHY THIS EXISTS (2026-10-23). The Allfather's screen corrupted twice in one evening: a rule from the
# `Working` header painted through the middle of a transcript line, a status row with a stray `(` on the
# right edge, a transcript row eaten, and the bottom hint clipped mid-word (`MCP: 12 servers enab`).
#
# Measured with `PI_TUI_WRITE_LOG` in a 66x18 pty:
#   * `fullscreen` sends `ESC[?7l` (AUTOWRAP OFF) at startup and NEVER restores it. Under that mode a row
#     that is even one column too long is CLIPPED, not wrapped — and the next component that repaints
#     that row shifts what is already there, which is exactly the artefact on his screen: a fragment of
#     one row living inside another. Upstream: #4568 ("TUI rendering breaks after terminal window
#     resize", closed `no-action`), #9255 (redraw storm, open), #941/#8805/#8606 (rows wider than the
#     terminal), #6696 (a raw TAB laid out as 3 columns, written as a TAB).
#   * `regular` never touches autowrap and has no fixed chrome composited over the transcript, so that
#     class cannot occur. That is why this seat runs `"tuiMode": "regular"`.
#
# This is the check that keeps it that way: it drives a real pi in a pty at a narrow width, captures the
# raw ANSI stream, and FAILS if any write reaches past the terminal's right edge. A capability without a
# check is a claim; a rendering fault found by the operator is a fault found too late.
set -u
VERSION="1.0.0"
COLS=60; ROWS=18; MODE="both"; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --cols) COLS="${2:-60}"; shift 2 ;;
    --rows) ROWS="${2:-18}"; shift 2 ;;
    --mode) MODE="${2:-both}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    *) printf 'error: unknown flag %s\n' "$1" >&2; exit 2 ;;
  esac
done
command -v python3 >/dev/null 2>&1 || { printf 'skip: python3 is absent — nothing to drive a pty with\n'; exit 0; }
command -v pi >/dev/null 2>&1 || { printf 'skip: pi is not on PATH\n'; exit 0; }

exec python3 - "$COLS" "$ROWS" "$MODE" "$QUIET" <<'PY'
import os, pty, select, shutil, struct, subprocess, sys, termios, fcntl, time, tempfile, unicodedata

cols, rows, mode, quiet = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3], sys.argv[4] == "1"
modes = ["regular", "fullscreen"] if mode == "both" else [mode]

def cell_width(ch):
    if unicodedata.combining(ch):
        return 0
    return 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1

def capture(tui_mode, seconds=9.0):
    """Start pi in a pty of the given size and return (raw ANSI stream, log path)."""
    tmp = tempfile.mkdtemp(prefix="pi-frame-")
    log = os.path.join(tmp, "write.log")
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    env = dict(os.environ, PI_TUI_WRITE_LOG=log, TERM="xterm-256color", COLUMNS=str(cols), LINES=str(rows))
    proc = subprocess.Popen(["pi", "--tui-mode", tui_mode], stdin=slave, stdout=slave, stderr=slave,
                            env=env, cwd=os.environ.get("HOME", "/"), start_new_session=True)
    os.close(slave)
    end = time.time() + seconds
    buf = b""
    while time.time() < end:
        ready, _, _ = select.select([master], [], [], 0.3)
        if ready:
            try:
                chunk = os.read(master, 65536)
            except OSError:
                break
            if not chunk:
                break
            buf += chunk
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except Exception:
        proc.kill()
    os.close(master)
    raw = open(log, "rb").read() if os.path.exists(log) else b""
    shutil.rmtree(tmp, ignore_errors=True)
    return raw.decode("utf-8", "replace"), tui_mode

def scan(stream):
    """Replay the stream: every write past the right edge is a finding. Autowrap state is recorded."""
    i, n, row, col = 0, len(stream), 0, 0
    overs, autowrap, rows_seen = [], None, set()
    while i < n:
        ch = stream[i]
        if ch == "\x1b":
            if i + 1 < n and stream[i + 1] == "[":
                j = i + 2
                while j < n and not ("\x40" <= stream[j] <= "\x7e"):
                    j += 1
                body, cmd = stream[i + 2:j], (stream[j] if j < n else "")
                if cmd in "Hf":
                    parts = [p for p in body.lstrip("?").split(";") if p.isdigit()]
                    row = (int(parts[0]) - 1) if parts else 0
                    col = (int(parts[1]) - 1) if len(parts) > 1 else 0
                elif cmd in "hl" and body.startswith("?") and "7" in body[1:].split(";"):
                    autowrap = (cmd == "h")
                elif cmd == "C":
                    col += int(body or 1)
                elif cmd == "D":
                    col = max(0, col - int(body or 1))
                elif cmd == "G":
                    col = int(body or 1) - 1
                elif cmd == "A":
                    row = max(0, row - int(body or 1))
                elif cmd == "B":
                    row += int(body or 1)
                i = j + 1
                continue
            if i + 1 < n and stream[i + 1] == "]":
                j = i + 2
                while j < n and stream[j] != "\x07" and not (stream[j] == "\x1b" and j + 1 < n and stream[j + 1] == "\\"):
                    j += 1
                i = j + (2 if j < n and stream[j] == "\x1b" else 1)
                continue
            i += 2
            continue
        if ch == "\n":
            row += 1; col = 0; i += 1; continue
        if ch == "\r":
            col = 0; i += 1; continue
        if ch == "\x07":
            i += 1; continue
        if ch == "\t":
            col += 8 - (col % 8); i += 1; continue
        col += cell_width(ch)
        rows_seen.add(row)
        if col > cols:
            overs.append((row + 1, col, stream[max(0, i - 40):i + 40].replace("\n", " ")))
        i += 1
    return overs, autowrap, len(rows_seen)

fails = 0
for m in modes:
    stream, _ = capture(m)
    if not stream:
        print(f'  "frame-check","SKIP","{m}: no ANSI stream captured (is pi interactive here?)"')
        continue
    overs, autowrap, drawn = scan(stream)
    if autowrap is False:
        note = "AUTOWRAP DISABLED by pi (?7l) — an over-wide row is clipped, then the next repaint desyncs"
    elif autowrap is True:
        note = "autowrap enabled"
    else:
        note = "autowrap untouched"
    if overs:
        fails += 1
        print(f'  "{m}","FAIL","{len(overs)} write(s) past column {cols} of {drawn} rows drawn"')
        for r, c, sample in overs[:5]:
            print(f'    row {r} -> col {c}: ...{sample[-46:]!r}')
    else:
        print(f'  "{m}","ok","{drawn} rows drawn, none past column {cols} · {note}"')
    if m == "fullscreen" and autowrap is False and not quiet:
        print('    note: fullscreen leaves autowrap OFF for the whole session — that is the class of'
              ' fault this seat avoids by running "tuiMode": "regular"')
print(f'tui-frame-check: {len(modes)} mode(s) · columns {cols} rows {rows} · {"FAIL" if fails else "pass"} · {fails} fault(s)')
sys.exit(1 if fails else 0)
PY
