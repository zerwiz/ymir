#!/usr/bin/env python3
"""nda-guard — company, client and NDA-project names never reach Ymir's public repository.

  nda-guard.py staged              the staged diff           (git pre-commit)
  nda-guard.py message FILE        a commit message          (git commit-msg; pre-commit cannot see it)
  nda-guard.py push                refs on stdin             (git pre-push; judges what the push adds)
  nda-guard.py range A..B          the commits A..B
  nda-guard.py tree [FILE...]      tracked files, whole (or the named ones) — CI and the ward
  nda-guard.py hook                a Claude Code PreToolUse JSON on stdin (Write / Edit)

A refusal names the file, the line and the matched name — nothing else of the line. The names are read
from the operator's home at run time (ndalib.py); with no home the gate says so loudly and cannot judge.
Exit: 0 clean (or unarmed, said aloud) · 1 a protected name · 2 usage.
"""
import json, os, re, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ndalib

ROOT = ndalib.repo_root()
ZERO = '0' * 40


def git(*a):
    return subprocess.run(['git', '-C', ROOT, *a], capture_output=True).stdout.decode('utf-8', 'replace')


def added_lines(diff):
    """Yield (path, line_no, text) for every added line of a -U0 diff."""
    path, ln = None, 0
    for raw in diff.splitlines():
        if raw.startswith('+++ '):
            path = raw[6:] if raw.startswith('+++ b/') else None
        elif raw.startswith('@@'):
            m = re.search(r'\+(\d+)', raw)
            ln = int(m.group(1)) if m else 0
        elif raw.startswith('+') and not raw.startswith('+++'):
            if path:
                yield path, ln, raw[1:]
            ln += 1


def report(hits):
    for path, n, name, kind in hits:
        print(f'nda-guard: {path}:{n}: protected {kind} name "{name}"', file=sys.stderr)
    if hits:
        print(f'nda-guard: {len(hits)} hit(s). Company, client and personal names are private data (RULES/04); '
              'rewrite to a neutral word or move the file into the home. An ordinary English word '
              'goes in config/nda-allow.yaml with its reason.', file=sys.stderr)
    return 1 if hits else 0


def diff_hits(M, diff):
    hits, seen = [], set()
    for path, n, text in added_lines(diff):
        for _ln, name, kind in M.scan_text(text):
            hits.append((path, n, name, kind))
        if path not in seen:
            seen.add(path)
            for _, name, kind in M.scan_path(path):
                hits.append((path, 0, name, kind))
    return hits


def tree_hits(M, files):
    hits = []
    for f in files:
        full = f if os.path.isabs(f) else os.path.join(ROOT, f)
        for _, name, kind in M.scan_path(f):
            hits.append((f, 0, name, kind))
        try:
            raw = open(full, 'rb').read()
        except OSError:
            continue
        if ndalib.is_binary(raw):
            continue
        for ln, name, kind in M.scan_text(raw.decode('utf-8', 'replace')):
            hits.append((f, ln, name, kind))
    return hits


def hook(M):
    """Claude Code PreToolUse: refuse a Write/Edit into the public Ymir tree that carries a protected name."""
    def decide(reason=None):
        if reason:
            print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse',
                  'permissionDecision': 'deny', 'permissionDecisionReason': reason}}))
        return 0
    try:
        ev = json.load(sys.stdin)
    except Exception:
        return decide()
    ti = ev.get('tool_input') or {}
    path = ti.get('file_path') or ti.get('path') or ''
    if not path:
        return decide()
    real = os.path.realpath(path)
    home = M.home and os.path.realpath(M.home)
    if home and (real == home or real.startswith(home + os.sep)):
        return decide()                      # the home is where private data belongs
    d = os.path.dirname(real)
    while d != os.path.dirname(d):
        if os.path.isdir(os.path.join(d, 'RULES')) and os.path.isfile(os.path.join(d, 'bin', 'gates', 'guards', 'ndalib.py')):
            break
        d = os.path.dirname(d)
    else:
        return decide()                      # not inside a Ymir checkout
    if not M.armed:
        return decide()
    text = '\n'.join(str(ti.get(k)) for k in ('content', 'new_string') if ti.get(k))
    for e in ti.get('edits') or []:
        if isinstance(e, dict) and e.get('new_string'):
            text += '\n' + str(e['new_string'])
    hits = M.scan_text(text) + M.scan_path(real[len(d) + 1:])
    if hits:
        names = sorted({h[1] for h in hits})
        return decide('NDA gate (RULES/04): this write goes into the PUBLIC Ymir tree and carries a protected '
                      f'company/client/project name ({", ".join(names)}). Company and client names are private data. '
                      'Use a neutral word, or write the file under $YMIR_HOME instead. '
                      'An ordinary English word belongs in config/nda-allow.yaml with its reason.')
    return decide()


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd = argv[1]
    M = ndalib.Matcher()
    if cmd == 'hook':
        return hook(M)
    if not M.home:
        print('nda-guard: UNARMED — no Ymir home resolves on this machine, so no protected name can be read '
              'and NOTHING was judged. This is not a pass. (On a seat that has a home, this is a fault.)', file=sys.stderr)
        return 0
    if not M.armed:
        print('nda-guard: UNARMED — the home names no company, client or NDA project; nothing was judged.', file=sys.stderr)
        return 0
    if cmd == 'message':
        text = open(argv[2], encoding='utf-8', errors='replace').read() if len(argv) > 2 else sys.stdin.read()
        text = '\n'.join(l for l in text.splitlines() if not l.startswith('#'))
        return report([('commit message', n, name, kind) for n, name, kind in M.scan_text(text)])
    if cmd == 'staged':
        return report(diff_hits(M, git('diff', '--cached', '-U0', '--no-renames', '--src-prefix=a/', '--dst-prefix=b/', '--diff-filter=AM')))
    if cmd == 'range':
        return report(diff_hits(M, git('diff', '-U0', '--no-renames', '--src-prefix=a/', '--dst-prefix=b/', '--diff-filter=AM', argv[2])))
    if cmd == 'push':
        hits = []
        for line in sys.stdin:
            p = line.split()
            if len(p) < 4 or p[1] == ZERO:
                continue
            local, remote = p[1], p[3]
            base = remote if remote != ZERO else git('merge-base', local, 'origin/main').strip()
            diff = git('diff', '-U0', '--no-renames', '--src-prefix=a/', '--dst-prefix=b/', '--diff-filter=AM', f'{base}..{local}') if base \
                else git('show', '-U0', '--format=', '--src-prefix=a/', '--dst-prefix=b/', local)
            hits += diff_hits(M, diff)
        return report(hits)
    if cmd in ('tree', 'check'):
        files = argv[2:] or git('ls-files').splitlines()
        hits = tree_hits(M, files)
        # A person already named in an old public file is owed a scrub, but a whole-file read cannot tell
        # a line a push adds from one that was there before. People are therefore REFUSED on the lines a
        # change adds (staged, message, push, range, hook) and COUNTED, not refused, on a whole-file read,
        # so touching an old file to add a log line is not blocked by a name it already carried.
        owed = [h for h in hits if str(h[3]).startswith('person')]
        hits = [h for h in hits if not str(h[3]).startswith('person')]
        if owed:
            print(f'nda-guard: {len(owed)} line(s) in {len({h[0] for h in owed})} file(s) name a person from the home; '
                  'owed a scrub (a new line that names one is refused at commit, push and write).', file=sys.stderr)
        return report(hits)
    print(f'error: unknown command {cmd}', file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
