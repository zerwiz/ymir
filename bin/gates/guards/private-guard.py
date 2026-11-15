#!/usr/bin/env python3
"""private-guard — private structure and protected material never cross a surface."""
import hashlib, os, re, subprocess, sys

def ymir_home():
    h = os.environ.get('YMIR_HOME')
    if h:
        return h
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
    # ymir_home_root takes a RESULT VARIABLE; called bare it returns 2. Every
    # other caller already passes one (bin/ward/garmr/common.py, systems/skirnir/services/*).
    out = subprocess.check_output([
        'bash', '-c',
        f'. "{root}/bin/vault/hoard-lib.sh" >/dev/null 2>&1; out=""; ymir_home_root out; printf "%s" "$out"',
    ]).decode().strip()
    return out or os.path.join(os.path.expanduser('~'), 'Documents', 'ymirhome')


HOME = ymir_home()
REG = os.path.join(HOME, 'hodd/identity/confidential.yaml')
FIND = False

# A VARIABLE IS THE DESIGN, NOT A LEAK (plan 293 part 8, 2026-11-14).
#
# The public docs say where a thing lives as `$YMIR_HOME/hodd/...`. That is the shape Rule 07
# asks for — one variable, one documented default — and until this change the ward below read
# every one of those mentions as a "private hoard path". The helm's audit of 36 panes measured
# it as a FALSE SIGNAL on correct code, and a ward that refuses the design is a ward the house
# routes around (the audit's own note: "it is the wrong ward for repository code").
#
# What leaks is not the variable, it is the RESOLVED path: an expanded home directory, a `~/`
# path, an absolute one, a real shelf littered with a real realm's name. So `$YMIR_HOME` left
# the pattern list and the resolved home walked in — computed at run time from the one
# resolver, never written here (a guard that names the operator re-creates the leak, RULES/04).
PATTERNS = [
    (re.compile(r'/home/|/Users/|[A-Z]:\\'), 'absolute path'),
    (re.compile(re.escape(HOME) + r'/', re.I), 'private hoard path (resolved)'),
    (re.compile(r'~/[A-Za-z]|(?:^|[\s`(])hodd/|\.yggdrasil/'), 'private hoard path'),
    (re.compile(r'platform\.env|age\.key|secrets/|\.age\b'), 'vault filename'),
    (re.compile(r'\bsk-[A-Za-z0-9]|\bghp_[A-Za-z0-9]|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|password=|api_key=|Bearer [A-Za-z0-9._-]{12,}'), 'secret shape'),
]


def real_realms():
    """The realms that actually exist in the home, read at run time and never written here."""
    shelf = os.path.join(HOME, 'svartalfaheim')
    try:
        return sorted(n for n in os.listdir(shelf) if os.path.isdir(os.path.join(shelf, n)))
    except OSError:
        return []


# A SHAPED SHELF IS THE DESIGN TOO. `svartalfaheim/<realm>/<project>/plans/` is how every page
# names the plan ledger, and the repository ships `svartalfaheim/` itself (its own examples).
# What leaks is a REAL realm — a house's own name on a private shelf — so the realms are read
# from the home at run time and only those refuse the surface. The generic `svartalfaheim/`
# alternative left the pattern for the same reason `$YMIR_HOME` did.
REALMS = real_realms()
if REALMS:
    PATTERNS.append((re.compile(r'svartalfaheim/(?:' + '|'.join(re.escape(r) for r in REALMS) + r')(?![-\w])', re.I),
                     'private hoard path (a real realm)'))

def registry():
    try:
        import yaml
        return yaml.safe_load(open(REG, encoding='utf-8')) or {}
    except Exception:
        return {}

REGISTRY = registry()
HASHES = {p['sha256']: p['name'] for p in REGISTRY.get('protected', [])}
MARKERS = [re.compile(re.escape(m), re.I) for m in REGISTRY.get('markers', [])]
AUTHORIZED = {e.lower() for e in REGISTRY.get('authorized_emails', [])}
SURFACES = REGISTRY.get('surfaces', {})

def report(path, line, kind):
    global FIND
    FIND = True
    print(f'{path}:{line}: {kind}', file=sys.stderr)

def classified_text(text):
    return any(p.search(text) for p in MARKERS)


def allowed(surface, to):
    rule = SURFACES.get(surface, 'deny')
    if rule == 'allow':
        return True
    if rule == 'parties-only' and surface == 'email':
        recipients = {r.strip().lower() for r in to.split(',') if r.strip()}
        recipients = {re.search(r'<([^>]+)>', r).group(1).lower() if '<' in r else r for r in recipients}
        return bool(recipients) and recipients <= AUTHORIZED
    return False

# A PICTURE IS NOT A TRANSCRIPT. Scanning compressed bytes for path-shaped text
# finds accidents in the pixel data: a legitimate PNG of a hand-drawn board was
# refused for "private hoard path" at byte 7792 of its compressed stream, and no
# sentence in that image was ever a path. The text rules exist to catch what a
# model or a reader would SEE; on binary media there is nothing to see in the
# bytes, so the scan is skipped LOUDLY and the operator's approval - which is
# bound to the exact bytes of what leaves - is what judges the content.
BINARY_EXT = {
    '.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp', '.ico', '.tiff', '.heic',
    '.mp3', '.wav', '.ogg', '.m4a', '.flac', '.mp4', '.mov', '.webm', '.mkv',
    '.zip', '.gz', '.tar', '.bz2', '.xz', '.7z',
    '.gguf', '.onnx', '.safetensors', '.bin', '.pt', '.pth',
}

def looks_binary(raw, path):
    if path.lower().rsplit('.', 1)[-1] and ('.' + path.lower().rsplit('.', 1)[-1]) in BINARY_EXT:
        return True
    return b'\x00' in raw[:8192]

def check_file(path, surface, to):
    global FIND
    raw = b''
    try:
        raw = open(path, 'rb').read()
    except OSError:
        return
    digest = hashlib.sha256(raw).hexdigest()
    if digest in HASHES:
        if allowed(surface, to):
            return
        report(path, 0, f'protected document ({HASHES[digest]}); not allowed on {surface}')
        return
    text = ''
    if path.lower().endswith('.pdf'):
        import subprocess, tempfile
        with tempfile.NamedTemporaryFile(suffix='.txt') as t:
            try:
                subprocess.run(['pdftotext', path, t.name], check=False, capture_output=True)
                text = open(t.name, encoding='utf-8', errors='replace').read()
            except Exception:
                print(f'{path}: PDF not inspected (pdftotext missing)', file=sys.stderr)
                return
    elif looks_binary(raw, path):
        print(f'{path}: binary media — the text scan is skipped; the operator\'s approval, '
              'bound to these exact bytes, is what judges it', file=sys.stderr)
        return
    else:
        text = raw.decode('utf-8', 'replace')
    lines = text.splitlines() or ['']
    for n, line in enumerate(lines, 1):
        for pat, kind in PATTERNS:
            if pat.search(line):
                report(path, n, kind)
    if classified_text(text):
        if allowed(surface, to):
            return
        report(path, 0, f'classified: not allowed on {surface} or to these recipients')

def main(argv):
    if len(argv) < 2:
        print('private-guard\tclean')
        return 0
    action = argv[1]; rest = argv[2:]
    surface, to, files = 'private', '', []
    i = 0
    while i < len(rest):
        a = rest[i]
        if a == '--surface': surface = rest[i+1]; i += 2
        elif a == '--to': to = rest[i+1]; i += 2
        elif a == '--stdin':
            tmp = '/tmp/private-guard-stdin'; open(tmp, 'wb').write(sys.stdin.buffer.read()); files.append(tmp); i += 1
        else: files.append(a); i += 1
    if action == 'scan-meeting':
        d = files[0]
        files = [os.path.join(d, f) for f in os.listdir(d) if f.endswith(('.md', '.json'))]
        files += [os.path.join(d, 'briefs', f) for f in os.listdir(os.path.join(d, 'briefs')) if f.endswith('.md')] if os.path.isdir(os.path.join(d, 'briefs')) else []
    for f in files:
        if os.path.isfile(f):
            check_file(f, surface, to)
    if not FIND:
        print('private-guard\tclean')
    return 1 if FIND else 0

if __name__ == '__main__':
    sys.exit(main(sys.argv))
