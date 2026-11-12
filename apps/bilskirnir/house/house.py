#!/usr/bin/env python3
"""house.py — the ONE renderer of an agent's house parts: soul, MCP doors, toolsets, hooks.

Every agent of the hall is a house agent from birth. The primary's engine (setup.sh) and every bot made in
the app (server/src/engine.ts) are dressed by this one file, so the two can never disagree.

  house.py names                       the hall's assistant and the house values, one tab-separated line
  house.py parts  [--name N --role R --browser URL --json]
                                       the config keys the house owns (mcp_servers, platform_toolsets,
                                       hooks, browser) as YAML, or as JSON for the server to merge
  house.py soul   --name N --role R [--description D] [--existing FILE | --full]
                                       the soul: the whole house soul (--full, the primary's), or the
                                       user's existing lines kept and the house block appended/refreshed

Settings (RULES/07), each with one documented default:
  YMIR_HOME, YMIR_HOST, YMIR_RUNTIME_DIR, BILSKIRNIR_MCP_GATEWAY, BILSKIRNIR_SESSION_HOOK — as in setup.sh.
Names are read from the home (hodd/identity/seats.yaml, operator.yaml); nothing is hard-coded but Nanna,
Ymir's own assistant, shipped with the app (RULES/44).
"""
import argparse, json, os, socket, sys

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY = '<!-- house:begin'
BEGIN = KEY + ' — managed by Bilskirnir, refreshed on every start; write your own lines outside it -->'
END = '<!-- house:end -->'


def is_legacy(text, name):
    """The stock soul every bot had before it was housed: it carries nothing of the user's own."""
    return text.startswith('You are %s' % name) and 'one of a small team of AI agents, each with its own screen' in text \
        and text.rstrip().endswith('what you could not do.')

HOME = os.environ.get('YMIR_HOME') or os.path.expanduser('~/Documents/ymirhome')
HOST = os.environ.get('YMIR_HOST') or socket.gethostname().split('.')[0]


def runtime_dir():
    r = os.environ.get('YMIR_RUNTIME_DIR') or os.path.expanduser('~/ymir-runtime')
    if not os.path.isfile(os.path.join(r, 'bin/mcp/ymir-mcp.py')):
        r = os.path.dirname(os.path.dirname(APP))
    return r


def _load(p):
    try:
        import yaml
        return yaml.safe_load(open(os.path.join(HOME, 'hodd', 'identity', p))) or {}
    except Exception:
        return {}


def names():
    """name, role, house, fleet, operator — the same values setup.sh has always rendered."""
    seats, op = _load('seats.yaml'), _load('operator.yaml')
    fleet = seats.get('fleet') or {}
    asst = fleet.get('assistant') or {}
    if asst.get('name'):
        name, role = asst['name'], asst.get('role') or 'the one who answers'
    else:
        name, role = 'Nanna', 'the one who answers'
    return {
        'name': name or 'unnamed',
        'role': role,
        'house': fleet.get('house') or 'unnamed',
        'fleet': fleet.get('name') or 'unnamed',
        'operator': (op.get('allfather') or {}).get('display') or fleet.get('operator') or 'the Allfather (unnamed in the home)',
        'home': HOME,
    }


def render_template(name, role):
    v = names()
    v['name'], v['role'] = name, role
    t = open(os.path.join(APP, 'house', 'soul.md.tmpl')).read()
    for k, val in v.items():
        t = t.replace('{{%s}}' % k, val)
    return t


def soul(name, role, description='', existing=None, full=False):
    body = render_template(name, role)
    if full:
        return body
    block = '%s\n%s\n%s\n' % (BEGIN, body.rstrip('\n'), END)
    mine = (existing or '')
    if KEY in mine and END in mine:
        # refresh the managed block in place; everything the user wrote around it stays
        head = mine.split(KEY)[0]
        tail = mine.split(END, 1)[1]
        return head + block.rstrip('\n') + tail
    mine = mine.strip('\n')
    if not mine or is_legacy(mine, name):
        # nothing of the user's: the house soul, then the description the user gave the agent
        return block + (('\n%s\n' % description.strip()) if description.strip() else '')
    return mine + '\n\n' + block


def parts(browser=''):
    r = runtime_dir()
    gw = os.environ.get('BILSKIRNIR_MCP_GATEWAY') or 'http://127.0.0.1:8316'
    hook = os.environ.get('BILSKIRNIR_SESSION_HOOK') or os.path.expanduser('~/.hermes/agent-hooks/ymir-session-hook.sh')
    mcp = {'ymir': {'command': 'python3', 'args': [os.path.join(r, 'bin/mcp/ymir-mcp.py')], 'enabled': True}}
    for d in ('well', 'skuld', 'bolthorn'):
        mcp[d] = {'url': '%s/mcp/%s' % (gw, d), 'enabled': True}
    # the house's hands — Rödd's toolbox through one door, so every agent holds the hands Nanna holds
    mcp['house'] = {'command': 'python3', 'args': [os.path.join(APP, 'house', 'hands-mcp.py')], 'enabled': True}
    tools = ['web', 'terminal', 'file', 'skills', 'todo', 'cronjob', 'vision']
    out = {'mcp_servers': mcp}
    if browser:
        # only when the agent has a desk to drive: a missing tool is a loop
        tools.append('browser')
        out['browser'] = {'cdp_url': browser}
    out['platform_toolsets'] = {'api_server': tools}
    if os.access(hook, os.X_OK):
        out['hooks'] = {'on_session_start': [{'command': hook, 'timeout': 180}],
                        'pre_llm_call': [{'command': hook, 'timeout': 60}]}
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('cmd', choices=['names', 'parts', 'soul'])
    ap.add_argument('--name', default='')
    ap.add_argument('--role', default='')
    ap.add_argument('--description', default='')
    ap.add_argument('--browser', default='')
    ap.add_argument('--existing', default='')
    ap.add_argument('--full', action='store_true')
    ap.add_argument('--json', action='store_true')
    a = ap.parse_args()
    if a.cmd == 'names':
        n = names()
        print('\t'.join([n['name'], n['role'], n['house'], n['fleet'], n['operator']]))
    elif a.cmd == 'parts':
        p = parts(a.browser)
        if a.json:
            print(json.dumps(p))
        else:
            import yaml
            sys.stdout.write(yaml.safe_dump(p, sort_keys=False, default_flow_style=None, width=1000))
    else:
        n = names()
        name = a.name or n['name']
        role = a.role or n['role']
        ex = None
        if a.existing:
            try:
                ex = open(a.existing).read()
            except OSError:
                ex = None
        sys.stdout.write(soul(name, role, a.description, ex, a.full))


if __name__ == '__main__':
    main()
