#!/usr/bin/env bash
# trello-due.sh — a card's due date is a promise; say when it is broken.
#
# The digest counts overdue ACTIONS from the meeting record. The board is where the work actually
# lives, and until now nothing read a due date from it — which is how a passed deadline went
# unnoticed. This reads the board and says one line per bucket per day, through Hófvarpnir.
#
#   bin/time/snotra/trello-due.sh [--dry-run] [--board NAME]
#
# Exit: 0 ok (including "nothing due") · 1 the board could not be read · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

DRY=0; BOARD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --board) BOARD="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
    *) printf 'error: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

ROOT_DIR="$ROOT" DRY_Q="$DRY" BOARD_Q="$BOARD" python3 - <<'PY'
import datetime, importlib.util, json, os, subprocess, sys

root = os.environ["ROOT_DIR"]
dry = os.environ["DRY_Q"] == "1"
want_board = os.environ.get("BOARD_Q") or ""

spec = importlib.util.spec_from_file_location(
    "snotra_trello", os.path.join(root, "bin", "time", "snotra", "snotra-trello.py"))
trello = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(trello)          # defines CONFIG, token(), api()
except SystemExit as err:                     # its die() calls sys.exit
    print(f'trello-due[1]{{state}}: "the trello module refused: {err}"')
    sys.exit(1)

try:
    boards = trello.api("GET", "/members/me/boards", {"fields": "name,closed"})
except Exception as err:
    print(f'trello-due[1]{{state}}: "the board list failed: {err}"')
    sys.exit(1)

name = want_board or (trello.CONFIG.get("board") or "Meetings")
open_boards = [b for b in boards if not b.get("closed")]
match = next((b for b in open_boards if b.get("name", "").lower() == name.lower()), None)
if not match:  # fall back to a substring, so a renamed board does not silence the watch
    match = next((b for b in open_boards if name.lower() in b.get("name", "").lower()), None)
if not match:
    print(f'trello-due[1]{{state}}: "no open board named {name!r} — found: '
          f'{", ".join(b.get("name","?") for b in boards[:6])}"')
    sys.exit(1)

try:
    cards = trello.api("GET", f'/boards/{match["id"]}/cards',
                       {"fields": "name,due,dueComplete,closed,shortUrl"})
except Exception as err:
    print(f'trello-due[1]{{state}}: "the cards failed: {err}"')
    sys.exit(1)

today = datetime.date.today()
overdue, due_today = [], []
for card in cards:
    if card.get("closed") or card.get("dueComplete") or not card.get("due"):
        continue
    try:
        due = datetime.date.fromisoformat(card["due"][:10])
    except ValueError:
        continue
    if due < today:
        overdue.append((card, (today - due).days))
    elif due == today:
        due_today.append(card)

door = os.path.join(root, "bin", "notify", "send.sh")
def say(severity, message, key):
    args = ["bash", door, "--source", "trello", "--severity", severity,
            "--message", message, "--key", key]
    if dry:
        args.append("--dry-run")
    subprocess.run(args, check=False, stdout=subprocess.DEVNULL)

if overdue:
    overdue.sort(key=lambda pair: -pair[1])
    worst, days = overdue[0]
    say("HIGH", f'{len(overdue)} card(s) overdue — worst: {worst["name"]} ({days}d)',
        f"trello:overdue:{today}")
if due_today:
    say("MEDIUM", f'{len(due_today)} card(s) due today — first: {due_today[0]["name"]}',
        f"trello:today:{today}")

print(f'trello-due[1]{{board,overdue,due_today,worst}}:"{match["name"]}","{len(overdue)}","{len(due_today)}",'
      f'"{overdue[0][0]["name"][:40] if overdue else ""}"')
PY
