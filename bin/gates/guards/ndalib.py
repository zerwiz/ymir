#!/usr/bin/env python3
"""ndalib — the NDA matcher: company, client and NDA-project names never enter the public tree.

ONE module, used by the guard (pre-commit, pre-push, CI) and by the Claude Code write hook,
so the two can never disagree (RULES/04, appended 2026-11-12).

The names are NEVER in this repository. They are read at run time from the operator's home:
  hodd/identity/companies.yaml      every company
  hodd/identity/clients.yaml        every client
  hodd/identity/projects.yaml       every project that is not Ymir's own or openly public
  svartalfaheim/<realm>/            every realm directory
  hodd/identity/confidential.yaml   `nda:` — names the operator adds by hand
  hodd/identity/collaborators.yaml  every person: full name, email local part, chat and code-host handles
  hodd/identity/names.yaml          entries of kind `person`
  hodd/data/telegram-rosters/*.yaml every name and username a chat roster has recorded
Words that are also ordinary English live in config/nda-allow.yaml, each with its reason; the
operator's own additions are read from $YMIR_HOME/config/nda-allow.yaml (never from here).
"""
import os, re, subprocess, sys

OPEN_KINDS = {'oss', 'oss-fork', 'vendored', 'docs'}
MIN_LEN = 4


def repo_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))


def ymir_home():
    """The home, or None. Never invents one."""
    h = os.environ.get('YMIR_HOME')
    if h:
        return h if os.path.isdir(h) else None
    try:
        root = repo_root()
        out = subprocess.run(
            ['bash', '-c', f'. "{root}/bin/vault/hoard-lib.sh" >/dev/null 2>&1; out=""; ymir_home_root out; printf "%s" "$out"'],
            capture_output=True, timeout=10).stdout.decode().strip()
        if out and os.path.isdir(out):
            return out
    except Exception:
        pass
    d = os.path.join(os.path.expanduser('~'), 'Documents', 'ymirhome')
    return d if os.path.isdir(d) else None


def _yaml(path):
    try:
        import yaml
        return yaml.safe_load(open(path, encoding='utf-8')) or {}
    except Exception:
        return {}


def _add(names, value, source):
    if not isinstance(value, str):
        return
    v = value.strip()
    if len(v) >= MIN_LEN:
        names.setdefault(v.lower(), source)


def _allow_rows(path, out):
    data = _yaml(path)
    for e in data.get('allow', []) or []:
        if isinstance(e, dict) and e.get('word') and str(e.get('reason', '')).strip():
            out[str(e['word']).strip().lower()] = e['reason']
    return out


def load_allow(root=None):
    """{word_lower: reason}. An entry without a reason is ignored: an allowance is a claim.

    TWO files, and the split is the line this house draws (RULES/04, RULES/42): the repository ships
    the GENERIC words any operator's tree needs (ordinary English that also names a shelf), and the
    operator's own — his realm, his domain, his handle — are read at run time from his home
    (`$YMIR_HOME/config/nda-allow.yaml`, template in `.agents/config/`). A word of his is never
    written here, because that is exactly the leak the gate exists to refuse."""
    out = _allow_rows(os.path.join(root or repo_root(), 'config', 'nda-allow.yaml'), {})
    home = ymir_home()
    if home:
        _allow_rows(os.path.join(home, 'config', 'nda-allow.yaml'), out)
    return out


GENERIC_LOCALS = {'info', 'admin', 'hello', 'contact', 'support', 'office', 'mail', 'noreply', 'no-reply',
                  'team', 'sales', 'hola', 'webmaster', 'postmaster'}


def _walk_strings(node, out):
    if isinstance(node, dict):
        for v in node.values():
            _walk_strings(v, out)
    elif isinstance(node, list):
        for v in node:
            _walk_strings(v, out)
    elif isinstance(node, str):
        out.append(node)


def load_people(home, names):
    """People are private data like companies are: a full name, the local part of an address, and every
    chat or code-host handle the home records. Roles and ids are not read; only what identifies a person."""
    ident = os.path.join(home, 'hodd', 'identity')
    for p in _yaml(os.path.join(ident, 'collaborators.yaml')).get('people', []) or []:
        if not isinstance(p, dict):
            continue
        _add(names, p.get('name'), 'person')
        for e in p.get('emails', []) or []:
            if isinstance(e, str) and '@' in e:
                local = e.split('@', 1)[0].strip().lower()
                if local not in GENERIC_LOCALS:
                    _add(names, local, 'person-handle')
        for key in ('telegram', 'github', 'handles', 'usernames'):
            v = p.get(key)
            vals = v if isinstance(v, list) else [v]
            for h in vals:
                _add(names, str(h).lstrip('@') if h else None, 'person-handle')
    for kind_list in (_yaml(os.path.join(ident, 'names.yaml')).get('names', {}) or {}).values():
        for e in kind_list or []:
            if isinstance(e, dict) and e.get('kind') == 'person':
                _add(names, e.get('name') or e.get('owner'), 'person')
    rosters = os.path.join(home, 'hodd', 'data', 'telegram-rosters')
    if os.path.isdir(rosters):
        for f in sorted(os.listdir(rosters)):
            if f.endswith('.yaml'):
                strings = []
                _walk_strings(_yaml(os.path.join(rosters, f)), strings)
                for t in strings:
                    _add(names, t.lstrip('@'), 'person-roster')
    return names


def load_names(home, allow=None):
    """{name_lower: source_kind} read from the home. Source kinds, never values, are what is reported."""
    names = {}
    ident = os.path.join(home, 'hodd', 'identity')
    for c in _yaml(os.path.join(ident, 'companies.yaml')).get('companies', []) or []:
        if isinstance(c, dict):
            _add(names, c.get('name'), 'company'); _add(names, c.get('id'), 'company')
    for c in _yaml(os.path.join(ident, 'clients.yaml')).get('clients', []) or []:
        if isinstance(c, dict):
            _add(names, c.get('name'), 'client'); _add(names, c.get('id'), 'client')
    apps_dir = os.path.join(repo_root(), 'apps')
    own_apps = [a.lower() for a in os.listdir(apps_dir)] if os.path.isdir(apps_dir) else []
    for p in _yaml(os.path.join(ident, 'projects.yaml')).get('projects', []) or []:
        if not isinstance(p, dict):
            continue
        ident_s = f"{p.get('id', '')} {p.get('name', '')}".lower()
        pid = str(p.get('id', '')).lower()
        if p.get('posture') == 'public' or p.get('kind') in OPEN_KINDS or ident_s.strip().startswith('ymir'):
            continue
        # Ymir's own applications live in apps/ of THIS repository: they are the public product, not a client's.
        if str(p.get('repo') or p.get('workspace') or '').startswith('apps/') or \
                any(pid == a or pid.startswith(a + '-') for a in own_apps):
            continue
        _add(names, p.get('name'), 'project'); _add(names, p.get('id'), 'project')
        _add(names, p.get('realm'), 'realm')
    sv = os.path.join(home, 'svartalfaheim')
    if os.path.isdir(sv):
        for d in os.listdir(sv):
            if not d.startswith('.') and os.path.isdir(os.path.join(sv, d)):
                _add(names, d, 'realm')
    conf = _yaml(os.path.join(ident, 'confidential.yaml'))
    for n in conf.get('nda', []) or []:
        _add(names, n if isinstance(n, str) else (n or {}).get('name'), 'nda-list')
    load_people(home, names)
    for w in (allow if allow is not None else load_allow()):
        names.pop(w, None)
    return names


def compile_names(names):
    if not names:
        return None
    alts = '|'.join(re.escape(n) for n in sorted(names, key=len, reverse=True))
    return re.compile(r'(?<![A-Za-z0-9_])(' + alts + r')(?![A-Za-z0-9_])', re.I)


class Matcher:
    def __init__(self, home=None, root=None):
        self.home = home if home is not None else ymir_home()
        self.allow = load_allow(root)
        self.names = load_names(self.home, self.allow) if self.home else {}
        self.rx = compile_names(self.names)

    @property
    def armed(self):
        return self.rx is not None

    def scan_text(self, text):
        """[(line_no, matched_name, source_kind)] — never more than the name is echoed."""
        out = []
        if not self.rx:
            return out
        for n, line in enumerate(text.splitlines(), 1):
            for m in self.rx.finditer(line):
                out.append((n, m.group(1), self.names.get(m.group(1).lower(), '?')))
        return out

    def scan_path(self, path):
        return [(0, m.group(1), self.names.get(m.group(1).lower(), '?')) for m in
                (self.rx.finditer(path) if self.rx else [])]


def is_binary(raw):
    return b'\x00' in raw[:8192]
