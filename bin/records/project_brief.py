#!/usr/bin/env python3
"""project_brief — the "this project" section of the session-start digest (see project-brief.sh)."""
import glob, os, re, subprocess, sys, tempfile

NOTE_LINES = 40
TODO_LINES = 12
DAILY_LINES = 10


def load_registry(home):
    path = os.path.join(home, 'hodd', 'identity', 'projects.yaml')
    try:
        import yaml
        with open(path, encoding='utf-8') as f:
            data = yaml.safe_load(f) or []
    except (OSError, ImportError):
        return []
    if isinstance(data, dict):
        data = data.get('projects', [])
    return [p for p in data if isinstance(p, dict)]


def git(args, cwd):
    try:
        return subprocess.run(['git', *args], cwd=cwd, capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ''


def repo_of(url):
    m = re.search(r'[:/]([^/:]+/[^/]+?)(?:\.git)?/?$', url or '')
    return m.group(1).lower() if m else ''


def find_project(projects, where):
    top = git(['rev-parse', '--show-toplevel'], where) or os.path.abspath(where)
    # a worktree's top is its own folder; the main checkout is what the registry records
    common = git(['rev-parse', '--path-format=absolute', '--git-common-dir'], where)
    main_top = os.path.dirname(common) if common.endswith('/.git') else top
    remote = repo_of(git(['remote', 'get-url', 'origin'], where))
    paths = {os.path.realpath(top), os.path.realpath(main_top)}
    for p in projects:
        repo = str(p.get('repo') or '').lower()
        if not repo and isinstance(p.get('git'), dict):
            repo = f"{p['git'].get('owner', '')}/{p['git'].get('repo', '')}".lower()
        if remote and repo == remote:
            return p
        clones = list((p.get('clones') or {}).values()) + [p.get('local_clone')]
        if any(c and os.path.realpath(str(c)) in paths for c in clones):
            return p
    return None


def head(path, n):
    try:
        with open(path, encoding='utf-8') as f:
            return [l.rstrip('\n') for l in f][:n]
    except OSError:
        return []


def mentions(lines, words):
    pat = re.compile('|'.join(re.escape(w) for w in words if w), re.I)
    return [l for l in lines if pat.search(l)]


def brief(home, where):
    if not home or not os.path.isdir(home):
        return 'project: no home resolved — set YMIR_HOME'
    p = find_project(load_registry(home), where)
    if not p:
        return 'project: this directory is not in hodd/identity/projects.yaml — add it (repo, clones, seat) to get a brief'
    out = [f"project: {p.get('name') or p.get('id')} ({p.get('id')}) · company {p.get('company', '?')}"]
    seat = p.get('seat')
    words = {str(p.get('id') or ''), str(p.get('name') or '')}
    words |= {w.split('-')[0] for w in words if '-' in w}
    words |= {str(a) for a in (p.get('aliases') or [])}
    if seat:
        folder = os.path.join(home, seat)
        out.append(f'home folder: {seat}')
        note = next((os.path.join(folder, n) for n in ('NOW.md', 'README.md') if os.path.isfile(os.path.join(folder, n))), None)
        if note:
            out.append(f'--- {os.path.relpath(note, home)} (first {NOTE_LINES} lines)')
            out += head(note, NOTE_LINES)
    else:
        out.append('home folder: none — add `seat:` to its registry entry')
    todo = os.path.join(home, 'hodd', 'life', 'personal', 'me', 'todo.md')
    open_lines = [l for l in head(todo, 10_000) if l.lstrip().startswith('- [ ]')]
    hits = mentions(open_lines, words)[:TODO_LINES]
    out.append(f'--- open to-do lines naming it: {len(hits)}')
    out += hits
    daily = sorted(glob.glob(os.path.join(home, 'hodd', 'memory', 'daily', '*.md')))
    if daily:
        hits = mentions(head(daily[-1], 10_000), words)[-DAILY_LINES:]
        out.append(f'--- {os.path.basename(daily[-1])} lines naming it: {len(hits)}')
        out += hits
    return '\n'.join(out)


def self_test():
    ok = True
    with tempfile.TemporaryDirectory() as t:
        home = os.path.join(t, 'home'); repo = os.path.join(t, 'code', 'demo')
        os.makedirs(os.path.join(home, 'hodd', 'identity')); os.makedirs(os.path.join(home, 'hodd', 'life', 'personal', 'me'))
        os.makedirs(os.path.join(home, 'hodd', 'memory', 'daily')); os.makedirs(os.path.join(home, 'realm', 'demo'))
        os.makedirs(repo)
        subprocess.run(['git', 'init', '-q', repo]); subprocess.run(['git', '-C', repo, 'remote', 'add', 'origin', 'git@github.com:Acme/Demo-App.git'])
        open(os.path.join(home, 'hodd', 'identity', 'projects.yaml'), 'w').write(
            '- id: demo-app\n  name: Demo-App\n  company: acme\n  repo: Acme/Demo-App\n  seat: realm/demo\n  aliases: [Widget]\n'
            '- id: other\n  name: Other\n  repo: Acme/Other\n')
        open(os.path.join(home, 'realm', 'demo', 'NOW.md'), 'w').write('# Demo — where we are\nthe gate is waiting on review\n')
        open(os.path.join(home, 'hodd', 'life', 'personal', 'me', 'todo.md'), 'w').write(
            '- [ ] send the demo letter\n- [ ] ship the Widget\n- [x] done demo thing\n- [ ] unrelated task\n')
        open(os.path.join(home, 'hodd', 'memory', 'daily', '2026-01-02.md'), 'w').write('worked on Demo-App all day\nlunch\n')
        b = brief(home, repo)
        for want in ('Demo-App (demo-app)', 'home folder: realm/demo', 'the gate is waiting on review',
                     'send the demo letter', 'ship the Widget', 'worked on Demo-App'):
            if want not in b:
                print(f'FAIL  brief lacks: {want}'); ok = False
        for refuse in ('done demo thing', 'unrelated task', 'lunch'):
            if refuse in b:
                print(f'FAIL  brief carries: {refuse}'); ok = False
        stray = os.path.join(t, 'stray'); os.makedirs(stray)
        if 'not in hodd/identity/projects.yaml' not in brief(home, stray):
            print('FAIL  an unregistered directory is not named as such'); ok = False
        if 'no home resolved' not in brief(os.path.join(t, 'none'), repo):
            print('FAIL  a missing home is not named'); ok = False
    print('project-brief: self-test ' + ('PASS' if ok else 'FAILED'))
    return 0 if ok else 1


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['--self-test']:
        sys.exit(self_test())
    where = args[0] if args else os.environ.get('YMIR_SESSION_CWD') or os.getcwd()
    print(brief(os.environ.get('YMIR_HOME', ''), where))
