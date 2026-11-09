#!/usr/bin/env bash
# telegram-seat.sh — WHICH BOT IS WHOSE, and a repair when a journal disagrees.
#
# THE FAULT (2026-11-09, the Allfather, twice in one night): a Telegram message meant for the assistant
# arrived in the counsellor's chat and the counsellor answered it, and the extension then refused to run at
# all — "Telegram update journal belongs to another Telegram bot identity". Two causes, both of them the same
# mistake in different clothes:
#
#   1 · ONE CONFIG, MANY CONSUMERS. `@llblab/pi-telegram` reads `~/.pi/agent/telegram.json` for the whole
#       harness, so EVERY pi session inherits whichever bot is written there. A seat that is not that bot's
#       owner will answer as it.
#   2 · A TOKEN FROM ONE BOT UNDER THE NAME OF ANOTHER. The file carried the seat's name and id with a
#       different bot's token, so the extension derived one identity from the credential and found another in
#       the journal on disk. It refused — correctly — and the seat went dark.
#
# So this door answers three questions and repairs the third: which bot the harness is configured for, which
# bot the journal on disk was written by, and whether every OTHER consumer (a system's own services, read from
# the vault by key name) is on a different bot. A seat and a system must never wear one face.
#
#   telegram-seat.sh check            # report: harness identity · journals · other consumers (names only)
#   telegram-seat.sh repair           # move aside any journal whose identity disagrees with the config
#   telegram-seat.sh repair --dry-run # say what would move, move nothing
#
# Never prints a token. Never writes a token. Never deletes a journal — it moves it aside, dated, because a
# journal holds update offsets and a thrown-away offset is a swallowed message.
#
# Exit: 0 every identity agrees (or a clean skip) · 1 a disagreement was found · 2 usage
set -uo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/../.." && pwd)"
ACTION="${1:-check}"; shift || true
dry=0
for a in "$@"; do case "$a" in --dry-run) dry=1 ;; -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) printf 'unknown: %s\n' "$a" >&2; exit 2 ;; esac; done

python3 - "$ROOT" "$ACTION" "$dry" <<'PY'
import glob, json, os, re, sys, time

root, action, dry = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
TOKRE = re.compile(r'^\d{8,12}:[A-Za-z0-9_-]{30,}$')
faults = 0

def say(block, rows):
    print(f'{block}[{len(rows)}]{{' + ','.join(r[0] for r in rows) + '}:')
    for r in rows:
        print('  ' + ','.join('"%s"' % str(v).replace('"', "'") for v in r[1:]))

def note_token(v):
    v = (v or '').strip()
    if not v:
        return "(none)"
    if TOKRE.match(v):
        return "a token (value withheld) id=" + v.split(':')[0]
    return "(not a token: %s…)" % v[:6]

# ── 1 · the harness identity ───────────────────────────────────────────────────────────────────────────
cfg_path = os.path.expanduser('~/.pi/agent/telegram.json')
harness_id, harness_name, declared_id = "", "", ""
if os.path.exists(cfg_path):
    try:
        cfg = json.load(open(cfg_path))
    except Exception as e:
        print(f'telegram-seat: the config does not parse — {e}', file=sys.stderr)
        raise SystemExit(1)
    prof_name = os.environ.get('TELEGRAM_DEFAULT_PROFILE_NAME') or 'default'
    prof = (cfg.get('profiles') or {}).get(prof_name) or (cfg.get('profiles') or {}).get('default') or {}
    declared_id = str(prof.get('botId') or '')
    harness_name = str(prof.get('botUsername') or '')
    tok = str(prof.get('botToken') or '')
    if TOKRE.match(tok):
        harness_id = tok.split(':')[0]          # the credential is the authority; the label is only a claim
say('harness', [
    ('profile', prof_name if os.path.exists(cfg_path) else '(no config)'),
    ('credential', note_token(tok if os.path.exists(cfg_path) else '')),
    ('labelled', f'{harness_name or "?"} / {declared_id or "?"}'),
])
if declared_id and harness_id and declared_id != harness_id:
    faults += 1
    print(f'  FAULT: the config is LABELLED {declared_id} but its credential is bot {harness_id} — '
          f'the label would answer as somebody else')

# ── 2 · the journals on disk ──────────────────────────────────────────────────────────────────────────
troot = os.path.expanduser('~/.pi/agent/tmp/pi-telegram/sessions')
rows, stale = [], []
for d in sorted(glob.glob(os.path.join(troot, '*'))):
    j = os.path.join(d, 'inbox.json')
    if not os.path.isdir(d) or '.backup-' in d or not os.path.exists(j):
        continue
    try:
        blob = open(j).read()
        m = re.search(r'"botId"\s*:\s*"?(\d+)"?', blob)
        jid = m.group(1) if m else ''
    except Exception:
        jid = ''
    agrees = (not jid) or (not harness_id) or jid == harness_id
    rows.append((os.path.basename(d)[:12], jid or '?', 'agrees' if agrees else 'DISAGREES'))
    if not agrees:
        faults += 1
        stale.append(d)
say('journals', rows or [('none', 'no journal on disk', '')])

# ── 3 · other consumers, by NAME (a system's own door) ───────────────────────────────────────────────
others = []
try:
    out = os.popen(f'cd {root} && bash bin/vault/hodd.sh emit secrets/platform.env 2>/dev/null').read()
    for line in out.splitlines():
        line = line.strip().removeprefix('export ').strip("'\"")
        if 'TELEGRAM' in line and '=' in line:
            k, v = line.split('=', 1)
            v = v.strip().strip("'\"")
            bid = v.split(':')[0] if TOKRE.match(v) else '?'
            # THE SAME BOT IS CORRECT WHERE IT BELONGS: a key that names THIS seat's pi bot (PI_TELEGRAM…)
            # is expected to equal the harness bot — that is the seat's own token kept by name. A CLASH is a
            # SYSTEM's key (Skírnir and the like) pointing at the seat's bot: two doors, one face.
            same = bool(TOKRE.match(v) and harness_id and bid == harness_id)
            is_seat_key = k.upper().startswith('PI_TELEGRAM')
            clash = 'same (this seat\'s own bot, by name)' if (same and is_seat_key) else \
                    ('CLASH' if same else 'distinct')
            others.append((k, f'bot {bid}', clash))
except Exception:
    pass
say('consumers', others or [('none', 'no other Telegram key in the vault', '')])
for k, bid, state in others:
    if state == 'CLASH':
        faults += 1
        print(f'  FAULT: {k} uses the SAME bot as the harness — a seat and a system must not wear one face')

# ── 4 · the repair ───────────────────────────────────────────────────────────────────────────────────
if action == 'repair' and stale:
    for d in stale:
        target = d + '.backup-' + time.strftime('%Y%m%d-%H%M%S')
        if dry:
            print(f'would move aside: {os.path.basename(d)}')
        else:
            os.rename(d, target)
            print(f'moved aside: {os.path.basename(d)} → {os.path.basename(target)} '
                  f'(kept: a journal holds update offsets, and a thrown-away offset swallows a message)')
    if not dry:
        faults = 0

sys.exit(1 if faults else 0)
PY
