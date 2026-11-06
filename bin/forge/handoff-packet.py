#!/usr/bin/env python3
"""handoff-packet.py — the one artefact that crosses from a smith to the reviewer.

WHY (plan 203 §3, §14.1, §15.2 gap 1): the plan described a packet and built no door, so
every smith invented a shape and the reviewer parsed prose. This is the door: it writes the
packet in the house's TOON face and it REFUSES a packet that cannot be trusted.

The two refusals that carry the design:

  · the sha check (§14.1) — a packet names a commit. If the head that will be reviewed has
    moved, or the base it names is not in this repository, the packet is refused rather than
    read. A packet may not vouch for code that moved.
  · the changed list is CHECKED, not believed — every path the packet claims is compared with
    `git diff --name-only base...head`, so a packet that understates its footprint is refused.

A gate named is not evidence: `gates` and `tests` must carry OUTPUT, and "all pass", "CI green",
"n/a" and their cousins are refused by name.

Usage:
  handoff-packet.sh write <id> --task T --plan P [--branch B] [--base REF] [--head SHA]
                              --gates FILE|TEXT --tests FILE|TEXT
                              [--claim C]... [--not-done N]... [--need X]... [--repo DIR]
  handoff-packet.sh check <id> [--repo DIR] [--fetched SHA] [--packet FILE]
  handoff-packet.sh show  <id> [--packet FILE]

Exit: 0 written / the packet is sound · 1 refused (the refusal names the fault) · 2 usage.
"""
import argparse
import os
import re
import subprocess
import sys

TOOL = "handoff-packet"
REQUIRED = ["task", "plan", "branch", "base", "head", "changed", "gates", "tests",
            "claims", "not_done", "needs"]
EMPTY_CLAIMS = {"", "all pass", "all passed", "pass", "passed", "green", "ci green",
                "n/a", "na", "none", "ok", "tests pass", "gates pass", "see ci"}

# --------------------------------------------------------------------------- refusal


def refuse(headline, rows=None, help_line=None):
    print(f'{TOOL}: REFUSED — {headline}', file=sys.stderr)
    if rows:
        print(f'{TOOL}[{len(rows)}]{{fault,detail}}:', file=sys.stderr)
        for fault, detail in rows:
            print(f'  "{fault}","{detail}"', file=sys.stderr)
    if help_line:
        print(f'help: {help_line}', file=sys.stderr)
    sys.exit(1)


def usage_error(msg):
    print(f'{TOOL}: {msg}', file=sys.stderr)
    print('help: handoff-packet.sh --help', file=sys.stderr)
    sys.exit(2)


# --------------------------------------------------------------------------- home


def home_root():
    """The home is RESOLVED, never guessed (defaults-guard): hoard-lib owns where it lives."""
    here = os.path.dirname(os.path.abspath(__file__))
    lib = os.path.join(here, "..", "vault", "hoard-lib.sh")
    if os.path.exists(lib):
        try:
            out = subprocess.run(["bash", "-c",
                                  f'. "{os.path.abspath(lib)}"; v=""; ymir_home_root v; printf %s "$v"'],
                                 capture_output=True, text=True, timeout=30)
            home = out.stdout.strip()
            if home:
                return home
        except Exception:
            pass
    return os.environ.get("YMIR_HOME", "")


def packet_dir():
    state = os.environ.get("YMIR_STATE_DIR") or os.path.join(home_root(), "state")
    return os.path.join(state, "handoff")


# --------------------------------------------------------------------------- git


def git(repo, *args, check=True):
    p = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)
    if check and p.returncode != 0:
        refuse(f"git {' '.join(args)} failed in {repo}", [("git", (p.stderr or p.stdout).strip()[:300])])
    return p.stdout.strip()


def repo_root(path):
    return git(path or ".", "rev-parse", "--show-toplevel")


# --------------------------------------------------------------------------- packet io


def read_packet(path):
    if not os.path.exists(path):
        refuse(f"no packet at {path}", [("missing", path)],
               "handoff-packet.sh write <id> — a reviewer reads a packet, never a promise")
    text = open(path, encoding="utf-8").read()
    packet = {"changed": [], "claims": [], "not_done": [], "needs": []}
    block = None
    for line in text.splitlines():
        m = re.match(r"^([a-z_]+)\[(\d+)\]\{([^}]*)\}:\s*$", line)
        if m:
            block = m.group(1)
            continue
        m = re.match(r'^\s+"([^"]*)"(?:\s*,\s*"([^"]*)")?\s*$', line)
        if not m or block is None:
            continue
        a, b = m.group(1), m.group(2)
        b = (b or "").strip()
        if block == "packet":
            packet[a] = b
        elif block in ("changed", "claims", "not_done", "needs"):
            packet[block].append(a if block != "changed" else {"path": a, "detail": b})
    return packet


def toon_line(value):
    return str(value).replace('"', "'").replace("\n", " ").strip()


def write_packet(path, packet):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = []
    out.append(f'packet[{len(REQUIRED)}]{{field,value}}:')
    for k in REQUIRED:
        v = packet.get(k)
        if isinstance(v, list):
            continue
        out.append(f'  "{k}","{toon_line(v)}"')
    out.append(f'changed[{len(packet["changed"])}]{{path,detail}}:')
    for c in packet["changed"]:
        out.append(f'  "{c["path"]}","{toon_line(c["detail"])}"')
    for block in ("claims", "not_done", "needs"):
        items = packet[block] or ["none"]
        out.append(f'{block}[{len(items)}]{{item}}:')
        for i in items:
            out.append(f'  "{toon_line(i)}"')
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out) + "\n")
    return path


def evidence(value, what):
    """A gate named is not evidence: refuse a value that carries no output."""
    v = (value or "").strip()
    if not v:
        refuse(f"{what} carries no evidence", [(what, "empty")],
               f"a {what} field carries the OUTPUT — a command and its tail, or a file's text")
    if v.lower() in EMPTY_CLAIMS:
        refuse(f"{what} is a claim, not evidence: {v!r}", [(what, v)],
               f'write the {what} as the command and what it printed, never "all pass"')
    return v


def read_evidence(arg, kind):
    if os.path.exists(arg):
        text = open(arg, encoding="utf-8", errors="replace").read().strip()
        if not text:
            refuse(f"{kind} file is empty: {arg}", [(kind, arg)])
        return text
    return arg


# --------------------------------------------------------------------------- write


def cmd_write(a):
    repo = repo_root(a.repo)
    if not a.task:
        usage_error("write needs --task (what this was supposed to be)")
    if not a.plan:
        usage_error("write needs --plan (the document that says so)")
    branch = a.branch or git(repo, "rev-parse", "--abbrev-ref", "HEAD")
    head = a.head or git(repo, "rev-parse", "HEAD")
    base_ref = a.base or "origin/main"
    if not re.fullmatch(r"[0-9a-f]{40}", head):
        refuse(f"head is not a full sha: {head}", [("head", head)],
               "a packet names a commit by its full sha — a branch name can move")
    base = git(repo, "rev-parse", base_ref, check=False) or ""
    if not base:
        refuse(f"base {base_ref} does not resolve in {repo}", [("base", base_ref)],
               "fetch first: a packet whose base nobody has cannot be verified")
    diff = git(repo, "diff", "--numstat", f"{base}...{head}", check=False)
    changed = []
    for line in diff.splitlines():
        parts = line.split("\t")
        if len(parts) == 3:
            changed.append({"path": parts[2], "detail": f'+{parts[0]} -{parts[1]}'})
    gates = read_evidence(a.gates, "gates")
    tests = read_evidence(a.tests, "tests")
    packet = {
        "task": a.task, "plan": a.plan, "branch": branch,
        "base": f"{base_ref} {base}", "head": head,
        "changed": changed, "gates": evidence(gates, "gates"), "tests": evidence(tests, "tests"),
        "claims": a.claim or [], "not_done": a.not_done or ["none"], "needs": a.need or ["none"],
    }
    path = a.packet or os.path.join(packet_dir(), f"{a.id}.packet")
    write_packet(path, packet)
    print(f'{TOOL}[1]{{packet,branch,head,changed,state}}:')
    print(f'  "{path}","{branch}","{head}","{len(changed)}","written"')
    print(f'help: the reviewer runs `handoff-packet.sh check {a.id}` before the diff')


# --------------------------------------------------------------------------- check


def cmd_check(a):
    path = a.packet or os.path.join(packet_dir(), f"{a.id}.packet")
    p = read_packet(path)
    faults = []

    for k in REQUIRED:
        if k in ("changed", "claims", "not_done", "needs"):
            if not p.get(k):
                faults.append((k, "empty — a required block carries nothing"))
        elif not p.get(k):
            faults.append((k, "missing"))

    head = p.get("head", "")
    if head and not re.fullmatch(r"[0-9a-f]{40}", head):
        faults.append(("head", f"not a full sha: {head!r}"))

    repo = a.repo
    if repo is None:
        guess = os.environ.get("YMIR_PACKET_REPO", ".")
        repo = guess if os.path.isdir(guess) else "."
    try:
        repo = repo_root(repo)
    except SystemExit:
        repo = None

    base_sha = ""
    if p.get("base"):
        base_sha = p["base"].split()[-1]
        if not re.fullmatch(r"[0-9a-f]{40}", base_sha):
            faults.append(("base", f"no full sha in {p['base']!r}"))

    if repo and head and re.fullmatch(r"[0-9a-f]{40}", head):
        if subprocess.run(["git", "-C", repo, "cat-file", "-e", f"{head}^{{commit}}"],
                          capture_output=True).returncode != 0:
            faults.append(("head", f"{head[:12]} is not a commit in {repo} — fetch the branch first"))
        if base_sha and subprocess.run(["git", "-C", repo, "cat-file", "-e", f"{base_sha}^{{commit}}"],
                                       capture_output=True).returncode != 0:
            faults.append(("base", f"{base_sha[:12]} is not in {repo} — the diff cannot be verified"))
        else:
            claimed = [c["path"] for c in p.get("changed", [])]
            actual = [ln for ln in git(repo, "diff", "--name-only", f"{base_sha}...{head}",
                                       check=False).splitlines() if ln]
            missing = sorted(set(actual) - set(claimed))
            extra = sorted(set(claimed) - set(actual))
            if missing:
                faults.append(("changed", f"understated — the diff carries {len(missing)} path(s) the packet omits: "
                                          + ", ".join(missing[:5])))
            if extra:
                faults.append(("changed", f"overstated — the packet claims {len(extra)} path(s) the diff does not touch: "
                                          + ", ".join(extra[:5])))

    if a.fetched:
        if not head:
            faults.append(("fetched", "the packet names no head to compare against"))
        elif a.fetched.strip() != head:
            faults.append(("fetched", f"the fetched head {a.fetched[:12]} is not the packet's head {head[:12]} "
                                      "— a packet may not vouch for code that moved (plan 203 §14.1)"))

    if p.get("gates", "").strip().lower() in EMPTY_CLAIMS:
        faults.append(("gates", f"{p.get('gates')!r} is a claim, not evidence"))
    if p.get("tests", "").strip().lower() in EMPTY_CLAIMS:
        faults.append(("tests", f"{p.get('tests')!r} is a claim, not evidence"))

    if faults:
        refuse(f"packet {a.id or path} cannot be trusted",
               faults,
               "the packet is not read: fix the named rows, or write a new packet for the new head")

    print(f'{TOOL}[1]{{packet,branch,head,changed,state}}:')
    print(f'  "{path}","{p.get("branch", "")}","{p.get("head", "")}","{len(p.get("changed", []))}","sound"')
    print("note: soundness is not approval — run the gates on the fetched commit yourself (plan 203 §15.3)")


# --------------------------------------------------------------------------- show


def cmd_show(a):
    path = a.packet or os.path.join(packet_dir(), f"{a.id}.packet")
    if not os.path.exists(path):
        refuse(f"no packet at {path}", [("missing", path)])
    sys.stdout.write(open(path, encoding="utf-8").read())


# --------------------------------------------------------------------------- main


def main():
    ap = argparse.ArgumentParser(prog="handoff-packet.sh", add_help=True)
    sub = ap.add_subparsers(dest="cmd")

    w = sub.add_parser("write")
    w.add_argument("id")
    w.add_argument("--task"); w.add_argument("--plan")
    w.add_argument("--branch"); w.add_argument("--base"); w.add_argument("--head")
    w.add_argument("--gates", required=True); w.add_argument("--tests", required=True)
    w.add_argument("--claim", action="append"); w.add_argument("--not-done", action="append")
    w.add_argument("--need", action="append")
    w.add_argument("--repo"); w.add_argument("--packet")

    c = sub.add_parser("check")
    c.add_argument("id", nargs="?")
    c.add_argument("--repo"); c.add_argument("--fetched"); c.add_argument("--packet")

    s = sub.add_parser("show")
    s.add_argument("id", nargs="?")
    s.add_argument("--packet")

    a = ap.parse_args()
    if a.cmd == "write":
        cmd_write(a)
    elif a.cmd == "check":
        if not a.id and not a.packet:
            usage_error("check needs an id or --packet")
        cmd_check(a)
    elif a.cmd == "show":
        if not a.id and not a.packet:
            usage_error("show needs an id or --packet")
        cmd_show(a)
    else:
        print(__doc__.strip())
        sys.exit(2)


if __name__ == "__main__":
    main()
