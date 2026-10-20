#!/usr/bin/env python3
"""private-guard — private structure and protected material never cross a surface."""
import hashlib, os, re, subprocess, sys

def ymir_home():
    h = os.environ.get('YMIR_HOME')
    if h:
        return h
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
    return subprocess.check_output(['bash', '-c', f'. "{root}/bin/vault/hoard-lib.sh"; ymir_home_root']).decode().strip()


REG = os.path.join(ymir_home(), 'hodd/identity/confidential.yaml')
FIND = False
PATTERNS = [
    (re.compile(r'/home/|/Users/|[A-Z]:\\'), 'absolute path'),
    (re.compile(r'\$YMIR_HOME|~/[A-Za-z]|(?:^|[\s`(])hodd/|svartalfaheim/|\.yggdrasil/'), 'private hoard path'),
    (re.compile(r'platform\.env|age\.key|secrets/|\.age\b'), 'vault filename'),
    (re.compile(r'\bsk-[A-Za-z0-9]|\bghp_[A-Za-z0-9]|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|password=|api_key=|Bearer [A-Za-z0-9._-]{12,}'), 'secret shape'),
]

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
