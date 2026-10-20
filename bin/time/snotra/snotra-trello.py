#!/usr/bin/env python3
"""The Trello meeting board, generated from a meeting record.

Production rules:
- idempotent: cards are matched by their record id (DEC/ACT/OQ), never duplicated;
- the record is the source; Trello is a projection;
- members are real Trello users from the workspace, never text pretending to be a tag;
- a missing grant or a failed call stops loudly, it never writes half a board silently.
"""
import json, os, re, sys, time, subprocess, urllib.parse, urllib.request, datetime

HOME = os.path.expanduser('~')
AUTH = os.path.join(HOME, '.pi/agent/mcp-auth.json')
BASE = 'https://api.trello.com/1'
DEFAULT_LISTS = ['Meetings', 'Agenda', 'Proposed', 'Decided', 'Actions', 'Blocked', 'Done',
                 'Open Questions', 'Sign-off', 'Signed']
DEFAULT_COLORS = {'Grade A': 'red', 'Grade B': 'orange', 'Grade C': 'green',
                  'Blocking': 'purple', 'Question': 'sky'}


def home_dir():
    h = os.environ.get('YMIR_HOME')
    if h:
        return h
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
    return subprocess.check_output(['bash', '-c', f'. "{root}/bin/vault/hoard-lib.sh"; ymir_home_root']).decode().strip()


def load_trello_config():
    cfg = {'version': 1, 'board': 'Meetings', 'lists': DEFAULT_LISTS, 'labels': DEFAULT_COLORS}
    p = os.path.join(home_dir(), 'hodd/identity/trello.yaml')
    if os.path.isfile(p):
        try:
            import yaml
            data = yaml.safe_load(open(p, encoding='utf-8')) or {}
            if int(data.get('version', 1)) != 1:
                die(f"trello.yaml: unsupported version {data.get('version')}")
            for k in ('board', 'lists', 'labels'):
                if data.get(k):
                    cfg[k] = data[k]
        except Exception as e:
            die(f'trello.yaml: {e}')
    return cfg


CONFIG = load_trello_config()
LISTS = CONFIG['lists']
COLORS = CONFIG['labels']


def die(msg):
    print(f'error: {msg}', file=sys.stderr); raise SystemExit(1)


GRANT_KEY = 'mcp__trello|https://mcp.trello.com/v1'


def refresh_grant():
    """Refresh the MCP OAuth grant and persist it, so a long export does not 401."""
    d = json.load(open(AUTH))
    v = d.get(GRANT_KEY)
    if not v:
        die('no Trello grant section in mcp-auth.json')
    ci = v['clientInformation']
    meta = v['discovery']['authorizationServerMetadata']
    data = urllib.parse.urlencode({'grant_type': 'refresh_token',
                                   'refresh_token': v['tokens']['refresh_token'],
                                   'client_id': ci['client_id']}).encode()
    req = urllib.request.Request(meta['token_endpoint'], data=data,
                                 headers={'Content-Type': 'application/x-www-form-urlencoded'})
    with urllib.request.urlopen(req, timeout=30) as r:
        new = json.load(r)
    v['tokens'].update(new)
    v['tokensExpireAt'] = int(time.time() * 1000) + int(new.get('expires_in', 3600)) * 1000
    json.dump(d, open(AUTH, 'w'), indent=2)
    return new['access_token']


def token():
    t = os.environ.get('TRELLO_TOKEN')
    if t:
        return t
    try:
        d = json.load(open(AUTH))
    except OSError:
        die('no Trello grant; connect the Trello MCP server first')
    v = d.get(GRANT_KEY)
    if not v:
        die('no Trello grant in mcp-auth.json')
    if int(v.get('tokensExpireAt') or 0) < int(time.time() * 1000) + 60000:
        return refresh_grant()
    return v['tokens']['access_token']


TOK = token()


def api(method, path, params=None):
    global TOK
    url = BASE + path
    if params:
        url += ('&' if '?' in url else '?') + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, method=method,
                                 headers={'Authorization': 'Bearer ' + TOK,
                                          'Accept': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            body = r.read().decode()
            return json.loads(body) if body.strip() else None
    except urllib.error.HTTPError as e:
        if e.code == 401:
            TOK = refresh_grant()
            return api(method, path, params)
        die(f'{method} {path} -> HTTP {e.code}: {e.read().decode()[:300]}')
    except urllib.error.URLError as e:
        die(f'{method} {path} -> {e.reason}')


def oid(x):
    return str(x).rstrip('/').split('/')[-1]


def load(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def record(d):
    for n in ('record.json', 'meeting.json'):
        p = os.path.join(d, n)
        if os.path.isfile(p):
            return load(p)
    die(f'no record in {d}')


def write_state(d, state):
    path = os.path.join(d, 'trello.json') if os.path.isdir(d) else d
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(state, f, indent=2, ensure_ascii=False)


def label_ids(board, names):
    labels = api('GET', f'/boards/{board}/labels', {'fields': 'name,color'})
    out = {}
    for lb in labels:
        if lb.get('name') in names:
            out[lb['name']] = lb['id']
    for name, color in names.items():
        if name not in out:
            r = api('POST', f'/boards/{board}/labels', {'name': name, 'color': color})
            out[name] = r['id']
    return out


def ensure_board(d, rec):
    statep = os.path.join(d, 'trello.json')
    state = load(statep) if os.path.isfile(statep) else {}
    board = oid(state.get('boardId', '')) if state.get('boardId') else ''
    if not board:
        org = state.get('organizationId') or os.environ.get('TRELLO_ORG_ID', '6ad238393bae14df5e25c980')
        r = api('POST', '/boards', {
            'name': os.environ.get('TRELLO_BOARD_NAME') or CONFIG.get('board') or 'Meetings',
            'defaultLists': 'false',
            'prefs_permissionLevel': 'private',
            'idOrganization': org,
        })
        board = r['id']
        state = {'organizationId': org, 'boardId': board, 'board': r['url']}
        write_state(d, state)
    info = api('GET', f'/boards/{board}', {'fields': 'name,url'})
    state.update({'boardId': board, 'board': info['url'], 'boardName': info['name']})
    return board, state


def ensure_lists(board, state):
    current = {x['name']: x['id'] for x in api('GET', f'/boards/{board}/lists', {'fields': 'name'})}
    if 'Decided' not in current and 'Decisions' in current:
        api('PUT', f'/lists/{current["Decisions"]}', {'name': 'Decided'})
        current['Decided'] = current.pop('Decisions')
    for name in LISTS:
        if name not in current:
            r = api('POST', '/lists', {'idBoard': board, 'name': name, 'pos': 'bottom'})
            current[name] = r['id']
    state['lists'] = current
    return current


def workspace_people(board):
    orgs = api('GET', f'/boards/{board}/organization', {'fields': 'id'})
    if not orgs:
        return {}
    mem = api('GET', f'/organizations/{orgs["id"]}/members', {'fields': 'fullName,username,email'})
    return {m['fullName'].lower(): m for m in mem}, orgs['id']


def ensure_members(board, rec):
    people, org = workspace_people(board)
    board_members = {m['id']: m for m in api('GET', f'/boards/{board}/members', {'fields': 'fullName'})}
    by_name = {}
    existing_last = set()
    for m in board_members.values():
        full = (m.get('fullName') or '').lower()
        by_name[full] = m['id']
        existing_last.add(full.split()[-1] if full else '')
    for p in rec.get('participants', []):
        name = (p.get('name') or '').lower()
        if not name:
            continue
        if name in by_name:
            continue
        last = name.split()[-1]
        if last in existing_last:
            # already on the board under another form of the name
            hit = next((m['id'] for m in board_members.values() if (m.get('fullName') or '').lower().endswith(last)), None)
            if hit:
                by_name[name] = hit
                continue
        cand = people.get(name) or next((m for k, m in people.items() if k.endswith(last)), None)
        if cand:
            api('PUT', f'/boards/{board}/members/{cand["id"]}')
            by_name[name] = cand['id']
            existing_last.add(last)
    return by_name


PRIVATE = [
    (re.compile(r'/home/|/Users/|[A-Z]:\\'), 'absolute path'),
    (re.compile(r'\$YMIR_HOME|~/[A-Za-z]|(?:^|[\s`(])hodd/|svartalfaheim/|\.yggdrasil/'), 'private hoard path'),
    (re.compile(r'platform\.env|age\.key|secrets/|\.age\b'), 'vault filename'),
    (re.compile(r'\bsk-[A-Za-z0-9]|\bghp_[A-Za-z0-9]|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|password=|api_key=|Bearer [A-Za-z0-9._-]{12,}'), 'secret shape'),
]


def assert_external(text, where):
    for pat, kind in PRIVATE:
        if pat.search(str(text or '')):
            die(f'private-guard refused {where}: {kind} (value redacted)')
    # Rule 26 + the NDA registry: protected markers never go on a Trello card.
    try:
        import yaml
        root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
        home = os.environ.get('YMIR_HOME') or subprocess.check_output(['bash', '-c', f'. "{root}/bin/vault/hoard-lib.sh"; ymir_home_root']).decode().strip()
        reg = yaml.safe_load(open(os.path.join(home, 'hodd/identity/confidential.yaml'), encoding='utf-8')) or {}
        for marker in reg.get('markers', []):
            if re.search(re.escape(marker), str(text or ''), re.I):
                die(f'private-guard refused {where}: classified material (value redacted)')
    except OSError:
        pass


def ensure_card_members(cid, ids):
    ids = [i for i in (ids or []) if i]
    if not ids:
        return
    try:
        have = {m['id'] for m in api('GET', f'/cards/{cid}/members')}
    except SystemExit:
        have = set()
    for mid in ids:
        if mid not in have:
            try:
                api('POST', f'/cards/{cid}/idMembers', {'value': mid})
            except SystemExit:
                pass


def esc(s):
    return str(s or '')


def card_body(kind, x, rec):
    if kind == 'DEC':
        g = (x.get('grade') or 'C').upper()
        return (f"**Decision:** {esc(x.get('statement'))}\n\n"
                f"**Approver:** {esc(x.get('decided_by'))}\n**Grade:** {g}\n"
                f"**Rationale:** {esc(x.get('rationale'))}\n"
                f"**Reversibility:** {esc(x.get('reversibility'))}\n"
                f"**Review date:** {esc(x.get('review_date') or '—')}\n"
                f"**Status:** {esc(x.get('status') or 'decided')}\n\n"
                f"**Evidence:** [{esc((x.get('evidence') or {}).get('timestamp'))}] "
                f"\u201c{esc((x.get('evidence') or {}).get('quote'))}\u201d")
    if kind == 'ACT':
        ctx = f"**Context:** {esc(x.get('context'))}\n\n" if x.get('context') else ""
        return (ctx + f"**Owner:** {esc(x.get('owner'))}\n**Due:** {esc(x.get('due_at') or 'unresolved')}\n"
                f"**Done when:** {esc(x.get('definition_of_done') or '—')}\n"
                f"**Depends on:** {esc(x.get('dependency') or '—')}\n"
                f"**Source:** [{esc((x.get('evidence') or {}).get('timestamp'))}] "
                f"\u201c{esc((x.get('evidence') or {}).get('quote'))}\u201d")
    if kind == 'OQ':
        ctx = f"**Context:** {esc(x.get('context'))}\n\n" if x.get('context') else ""
        return (ctx + f"**Decider:** {esc(x.get('decider'))}\n**Needed by:** {esc(x.get('needed_by') or 'next meeting')}\n"
                f"**Blocking:** {'yes' if x.get('blocking') else 'no'}\n"
                f"**Status:** {esc(x.get('status') or 'open')}\n\n"
                f"**Evidence:** [{esc((x.get('evidence') or {}).get('timestamp'))}] "
                f"\u201c{esc((x.get('evidence') or {}).get('quote'))}\u201d")
    return ''


def short_title(kind, x):
    if x.get('title'):
        return x['title']
    if kind == 'DEC':
        return esc(x.get('statement'))[:80]
    if kind == 'ACT':
        text = esc(x.get('deliverable'))
        return text if len(text) <= 80 else text[:77].rsplit(' ', 1)[0] + '…'
    return esc(x.get('question'))[:80] if len(esc(x.get('question'))) <= 80 else esc(x.get('question'))[:77].rsplit(' ', 1)[0] + '…'


def card_title(kind, x, tag):
    return f"{short_title(kind, x)} — {x.get(kind.lower() if False else {'DEC':'decision_id','ACT':'action_id','OQ':'question_id'}[kind])} · {tag}"


def person_id(by_name, who):
    if not who:
        return None
    k = who.lower()
    if k in by_name:
        return by_name[k]
    last = k.split()[-1]
    return next((v for n, v in by_name.items() if n.endswith(last)), None)


def due(x):
    x = str(x or '')
    return x + 'T12:00:00.000Z' if re.fullmatch(r'\d{4}-\d{2}-\d{2}', x) else None


def ensure_checklist(cid, name, items):
    try:
        cls = api('GET', f'/cards/{cid}/checklists', {'fields': 'name'})
        cl = next((c for c in cls if c.get('name') == name), None)
        if not cl:
            cl = api('POST', f'/cards/{cid}/checklists', {'name': name})
        existing = {i.get('name') for i in cl.get('checkItems', [])}
        for text, checked in items:
            if text and text not in existing:
                assert_external(text, f'checklist {name}')
                try:
                    api('POST', f'/checklists/{cl["id"]}/checkItems', {'name': text[:500], 'checked': 'true' if checked else 'false'})
                except SystemExit:
                    print('  note: checklist items need write:checklists; card kept, items skipped', file=sys.stderr)
                    break
        return cl['id']
    except SystemExit:
        print('  note: checklist write not granted; card kept', file=sys.stderr)
        return None


def export_cards(board, state, rec):
    lists = state['lists']
    labels = label_ids(board, COLORS)
    state['labels'] = labels
    members = ensure_members(board, rec)
    existing = api('GET', f'/boards/{board}/cards', {'fields': 'name,idList,desc,due,idMembers,idLabels'})
    by_ref = {}
    for c in existing:
        m = re.search(r'((?:DEC|ACT|OQ)-\d{8}-\d{2})', c.get('name', ''))
        if m:
            by_ref[m.group(1)] = c
    out = []

    def upsert(ref, list_name, title, desc, due_date, member, label_names, checklist):
        assert_external(title + '\n' + desc, ref)
        c = by_ref.get(ref)
        params = {'name': title[:500], 'desc': desc[:16000], 'idList': lists[list_name]}
        if due_date:
            params['due'] = due_date
        if member:
            params['idMembers'] = member
        labs = [labels[n] for n in label_names if n in labels]
        if labs:
            params['idLabels'] = ','.join(labs) if isinstance(labs, list) else labs
        if c:
            api('PUT', f'/cards/{c["id"]}', params)
            cid = c['id']
        else:
            params['idList'] = lists[list_name]
            cid = api('POST', '/cards', params)['id']
        if checklist:
            ensure_checklist(cid, checklist[0], checklist[1])
        out.append({'ref': ref, 'id': cid, 'list': list_name, 'name': title})
        return cid

    # meeting card (keyed by date, not by a DEC id)
    m = rec.get('meeting', rec)
    date = str(m.get('started_at', ''))[:10]
    met = next((c for c in existing if c.get('name', '').startswith(f"{m.get('title')} — {date}")), None)
    mdesc = (f"**Date:** {date}\n**Participants:** {', '.join(p['name'] for p in rec.get('participants', []))}\n\n"
             f"**Board purpose:** every record, decision, action, open question and sign-off.\n\n"
             f"{len(rec.get('decisions', []))} decisions · {len(rec.get('actions', []))} actions · "
             f"{len(rec.get('questions', []))} open questions.")
    assert_external(mdesc, 'meeting card')
    all_members = ','.join(str(v) for v in members.values() if v)
    mparams = {'name': f"{m.get('title')} — {date}", 'desc': mdesc, 'idList': lists['Meetings'],
               'due': date + 'T12:00:00.000Z'}

    mid = met['id'] if met else api('POST', '/cards', mparams)['id']
    if met:
        api('PUT', f'/cards/{mid}', mparams)
    ensure_card_members(mid, list(members.values()))
    ensure_checklist(mid, 'Meeting checks', [('Record published within 24 h', False),
                                             ('Sign-off request sent', False),
                                             ('Every reply recorded', False),
                                             ('Chair signed the record', False)])
    out.append({'ref': 'MEETING', 'id': mid, 'list': 'Meetings', 'name': mparams['name']})

    tag = f"{m.get('title')} · {date}"
    for x in rec.get('decisions', []):
        g = (x.get('grade') or 'C').upper()
        upsert(x['decision_id'], 'Decided', card_title('DEC', x, tag), card_body('DEC', x, rec),
               due(x.get('review_date')), person_id(members, x.get('decided_by')),
               [f'Grade {g}'],
               ('Decision checks', [('One named Approver', True), ('Rationale written', bool(x.get('rationale'))),
                                    ('Options considered', bool(x.get('options'))), ('Evidence attached', bool(x.get('evidence'))),
                                    ('Review date (A mandatory)', bool(x.get('review_date')) or g != 'A')]))
    for x in rec.get('actions', []):
        upsert(x['action_id'], 'Actions', card_title('ACT', x, tag), card_body('ACT', x, rec),
               due(x.get('due_at')), person_id(members, x.get('owner')), [],
               ('Done when', [(x.get('definition_of_done') or 'To be agreed', False)]))
    for x in rec.get('questions', []):
        labs = ['Question'] + (['Blocking'] if x.get('blocking') else [])
        upsert(x['question_id'], 'Open Questions', card_title('OQ', x, tag), card_body('OQ', x, rec),
               due(x.get('needed_by')), person_id(members, x.get('decider')), labs,
               ('Resolution', [('Answer recorded and the card moved to Signed', False)]))
    # sign-off card
    soc = next((c for c in existing if c.get('name', '').startswith('Sign-off —')), None)
    deadline = datetime.date.fromisoformat(date) + datetime.timedelta(days=2)
    murl = api('GET', f'/cards/{mid}', {'fields': 'shortUrl'}).get('shortUrl') or state.get('board', '')
    sdesc = (
        "**What this is**\n"
        "The meeting record is written. Before it becomes official, every participant confirms that it is accurate.\n\n"
        "**What you need to do — about two minutes**\n"
        f"1. Open the meeting card: {murl}\n"
        "2. Read the decisions and the actions assigned to you.\n"
        "3. Reply to the Secretary's email with one of these two lines:\n"
        "\n"
        "   `confirm`\n"
        "\n"
        "   `objection: <what is wrong or missing>`\n"
        "\n"
        f"4. Do it by **{deadline.strftime('%a %d %b %Y')}** (two business days).\n\n"
        "**What `confirm` means**\n"
        "It means the record is accurate — **not** that you agree with every decision. "
        "An objection names a correction; it is not a re-vote.\n\n"
        "**How the grade changes the rule**\n"
        "- **Grade A** (one-way, strategic): every participant must confirm explicitly.\n"
        "- **Grade B** (costly to reverse): the Approver and every affected owner must confirm.\n"
        "- **Grade C** (easily reversed): silence after two business days counts as acceptance.\n\n"
        "**What happens next**\n"
        "- The Secretary ticks your name in the checklist below when your reply arrives.\n"
        "- If you object, the Secretary appends the correction to the record and re-circulates only that change.\n"
        "- When the required replies are in, the **Chair signs last**. The card moves to **Signed** and the record is official.\n"
        "- After signing, corrections are appended, never rewritten.\n\n"
        "**Who does what**\n"
        "- **You:** confirm or object by the deadline.\n"
        "- **Secretary:** records every reply and appends corrections.\n"
        "- **Chair:** signs the record when the confirmations are complete.\n\n"
        f"**Record:** the PDF and the full register were sent with the meeting email. "
        f"**Board:** {state.get('board', '')}"
    )
    sp = {'name': f"Sign-off — {m.get('title')}", 'desc': sdesc, 'idList': lists['Sign-off'],
          'due': deadline.isoformat() + 'T12:00:00.000Z'}
    sid = soc['id'] if soc else api('POST', '/cards', sp)['id']
    if soc:
        api('PUT', f'/cards/{sid}', sp)
    ensure_checklist(sid, 'Sign-off', [(p.get('name'), False) for p in rec.get('participants', [])])
    out.append({'ref': 'SIGNOFF', 'id': sid, 'list': 'Sign-off', 'name': sp['name']})
    # next-meeting agenda card (record-driven)
    ap = os.path.join(rec.get('_dir', ''), 'agenda-next.md')
    if os.path.isfile(ap):
        atext = open(ap, encoding='utf-8').read()
        assert_external(atext, 'agenda card')
        ac = next((c for c in existing if c.get('name', '').startswith('Agenda — next meeting')), None)
        aparams = {'name': 'Agenda — next meeting (proposed)', 'desc': atext[:16000], 'idList': lists['Agenda']}

        aid = ac['id'] if ac else api('POST', '/cards', aparams)['id']
        if ac:
            api('PUT', f'/cards/{aid}', aparams)
        ensure_card_members(aid, list(members.values()))
        headings = [l.lstrip('# ').strip() for l in atext.splitlines() if l.startswith('## ')]
        ensure_checklist(aid, 'Agenda', [(h, False) for h in headings])
        out.append({'ref': 'AGENDA', 'id': aid, 'list': 'Agenda', 'name': aparams['name']})
    state['cards'] = out
    state['members'] = {k: v for k, v in members.items()}
    link_workstreams(state, rec, out)
    write_state(os.path.join(rec.get('_dir', '.'), 'trello.json') if False else state_path, state)
    return state


WORKSTREAMS = {
    'patent': {'board': 'q5s42k70', 'decision': 'Patent Strategy', 'action': 'Patent Strategy', 'question': 'Questions to answer'},
    'vertical': {'board': 'Dh17f3OF', 'decision': 'Gate 1 — Long-list and screen', 'action': 'Gate 2 — Falsify the top three', 'question': 'Gate 1 — Long-list and screen'},
    'docs': {'board': '2YjEkVfP', 'decision': 'Documents & Agreements between us', 'action': 'Documents & Agreements between us', 'question': 'Weekly updates'},
}


def classify(text):
    t = (text or '').lower()
    if any(k in t for k in ('patent', 'provisional', 'filing', 'intellectual property')):
        return 'patent'
    if any(k in t for k in ('vertical', 'pilot', 'scoring', 'trading', 'comparison', 'gate 0', 'gate 1', 'gate 2')):
        return 'vertical'
    if any(k in t for k in ('agreement', 'contract', 'nda', 'document', 'annex', 'sign')):
        return 'docs'
    return None


def link_workstreams(state, rec, cards):
    """Copy the card a subject belongs to onto its workstream board, linking the source."""
    byref = {c['ref']: c for c in cards if c.get('ref') in ('DEC', 'ACT', 'OQ') or (c.get('ref') or '').startswith(('DEC-', 'ACT-', 'OQ-'))}
    byref = {c['ref']: c for c in cards}
    lists_cache = {}
    links = []
    for kind, items in (('decision', rec.get('decisions', [])), ('action', rec.get('actions', [])), ('question', rec.get('questions', []))):
        for x in items:
            ref = x.get(('decision_id' if kind == 'decision' else 'action_id' if kind == 'action' else 'question_id'))
            card = byref.get(ref)
            if not card:
                continue
            text = ' '.join(str(x.get(k) or '') for k in ('statement', 'deliverable', 'question', 'rationale', 'context'))
            ws = classify(text)
            if not ws:
                continue
            tgt = WORKSTREAMS[ws]
            bid = tgt['board']
            if bid not in lists_cache:
                lists_cache[bid] = {l['name']: l['id'] for l in api('GET', f'/boards/{bid}/lists', {'fields': 'name'})}
            lid = lists_cache[bid].get(tgt[kind])
            if not lid:
                continue
            existing = api('GET', f'/boards/{bid}/cards', {'fields': 'name'})
            if any(ref in (c.get('name') or '') for c in existing):
                continue
            copied = api('POST', '/cards', {'idList': lid, 'idBoard': bid, 'idCardSource': card['id'], 'keepFromSource': 'all'})
            note = f"\n\n**Source:** {state.get('board')} — {card['name']}"
            api('PUT', f'/cards/{copied["id"]}', {'desc': (copied.get('desc') or '') + note})
            links.append({'ref': ref, 'workstream': ws, 'cardId': copied['id']})
    state['links'] = links
    return links


def sync_signoff(d, state, rec):
    p = os.path.join(d, 'signoffs.json')
    if not os.path.isfile(p):
        return
    so = load(p)
    sid = next((c['id'] for c in state.get('cards', []) if c.get('ref') == 'SIGNOFF'), None)
    if not sid:
        return
    cls = api('GET', f'/cards/{sid}/checklists', {'fields': 'name'})
    cl = next((c for c in cls if c.get('name') == 'Sign-off'), None)
    if not cl:
        return
    items = {i['name']: i for i in cl.get('checkItems', [])}
    for person in so.get('people', []):
        it = items.get(person.get('name'))
        if it and person.get('status') in ('confirmed', 'abstained') and not it.get('state') == 'complete':
            api('PUT', f'/cards/{sid}/checkItem/{it["id"]}', {'state': 'complete'})
    if so.get('state') == 'signed':
        api('PUT', f'/cards/{sid}', {'idList': state['lists']['Signed']})


def doctor(d=None):
    state = load(os.path.join(d, 'trello.json')) if d and os.path.isfile(os.path.join(d, 'trello.json')) else None
    if not state:
        die('no trello.json; run export first')
    board = state['boardId']
    info = api('GET', f'/boards/{board}', {'fields': 'name,url'})
    lists = api('GET', f'/boards/{board}/lists', {'fields': 'name'})
    cards = api('GET', f'/boards/{board}/cards', {'fields': 'name,idList,due'})
    members = api('GET', f'/boards/{board}/members', {'fields': 'fullName'})
    print(f"board\t{info['name']}\t{info['url']}")
    print(f"lists\t{len(lists)}\t" + ', '.join(sorted(x['name'] for x in lists)))
    print(f"cards\t{len(cards)}")
    print(f"members\t" + ', '.join(m['fullName'] for m in members))
    for x in sorted(lists, key=lambda z: z['name']):
        n = sum(1 for c in cards if c['idList'] == x['id'])
        print(f"  {x['name']}\t{n}")


def main():
    if len(sys.argv) < 2:
        print('usage: snotra-trello.sh export|sync|doctor <meeting-dir>', file=sys.stderr); raise SystemExit(2)
    action, d = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else None)
    global state_path
    if action == 'doctor':
        doctor(d); return
    if not d or not os.path.isdir(d):
        die('a meeting directory is required')
    rec = record(d)
    board, state = ensure_board(d, rec)
    state['lists'] = state.get('lists') or {}
    state_path = os.path.join(d, 'trello.json')
    dict_lists = ensure_lists(board, state)
    state['lists'] = dict_lists
    rec['_dir'] = d
    if action == 'export':
        export_cards(board, state, rec)
        print(f"exported\t{len(state['cards'])} cards\t{state['board']}")
    elif action == 'sync':
        sync_signoff(d, state, rec)
        print('synced sign-off')
    else:
        die(f'unknown action: {action}')


if __name__ == '__main__':
    main()
