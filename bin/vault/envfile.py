#!/usr/bin/env python3
"""envfile.py — ONE parser for an env file, reading WHOLE ENTRIES.

Why this file exists. `hodd-set.sh` used to read the vault a LINE at a time, with
`grep` and `awk`. The vault holds multi-line values — an armoured OpenSSH block, a
quoted certificate — and a line reader has three faults against them:

* it treats the body of a block as so many loose lines, so a body line that happens
  to look like `KEY=` is counted as an entry that does not exist;
* it replaces or removes only the FIRST line of an entry, so the rest of a
  multi-line value is left behind as orphan text;
* it cannot tell that an edit was supposed to move the count by exactly one.

On 2026-11-20 that class of reading was half of the fault that took
`hodd/secrets/platform.env.age` from 91 secrets to 75 (the other half was reading a
stale plaintext sibling). This module is the one reader, and `hodd-set.sh` writes
through it.

An ENTRY is one of:

    NAME=value                          one line
    NAME="first line                    a quoted value, quoted across lines
    second line"
    NAME=-----BEGIN <KIND>-----          an armoured block, to its own END line
    ...base64...
    -----END <KIND>-----
    NAME=first\\                          a backslash continuation
    second

Everything that is not an entry — blank lines, comments, stray text — is carried
through byte for byte. Every record is a SLICE of the original text, so a file is
rebuilt by concatenating the untouched slices; the entries that are kept are never
re-rendered, and their bytes cannot drift.

CLI
    envfile.py names FILE                  one NAME per line, file order
    envfile.py count FILE                  how many entries
    envfile.py has FILE NAME               exit 0 when NAME is an entry, 1 when not
    envfile.py get FILE NAME               the value of the first entry named NAME
    envfile.py emit FILE                   `export NAME=<quoted value>` lines, for eval
    envfile.py unterminated FILE           names of armoured blocks whose END is missing
    envfile.py set FILE NAME --value-file F [--out O]
    envfile.py del FILE NAME [--out O]
    envfile.py diff A B --except NAME      entries whose bytes differ, by NAME
    envfile.py guard --before FILE --after FILE --key NAME --action set|replace|del

`guard` is the independent write check: it counts the file AS IT IS ON DISK and
refuses unless the after-file holds exactly before+1 entries (a new key), before
(a replaced key) or before-1 (a deleted key). A refused write names the entries
that would go missing — by NAME only, never by value.

Names, counts and refusals never print a value, so a test log carries no secret.
"""

import argparse
import re
import shlex
import sys

# A key name is ASCII, may not start with a digit, and may be written `export NAME=`.
KEY_RE = re.compile(r"(?:export[ \t]+)?([A-Za-z_][A-Za-z0-9_]*)=", re.ASCII)
BLOCK_OPEN = "-----BEGIN"
BLOCK_CLOSE = "-----END"
# A block body is base64 with padding only at the end (a body line can therefore look a
# lot like `NAME=`, and must never be read as an entry), or an old-style PEM header.
BASE64ISH = re.compile(r"[A-Za-z0-9+/]+={0,2}")
PEM_HEADER = re.compile(r"[A-Za-z-]+: .*")


class Entry:
    """One whole entry: its name, its byte range in the text, its value and its prefix."""

    __slots__ = ("name", "start", "end", "header", "value")

    def __init__(self, name, start, end, header, value):
        self.name = name
        self.start = start
        self.end = end
        self.header = header          # e.g. "NAME=" or "export NAME=", kept verbatim
        self.value = value

    @property
    def raw(self):  # pragma: no cover - kept for callers that want the bytes
        return self.header + self.value


def read_text(path):
    """Read a file as text that round-trips every byte (surrogateescape)."""
    with open(path, "rb") as fh:
        return fh.read().decode("utf-8", "surrogateescape")


def write_text(path, text):
    with open(path, "wb") as fh:
        fh.write(text.encode("utf-8", "surrogateescape"))


def _line_end(text, pos):
    nl = text.find("\n", pos)
    return len(text) if nl < 0 else nl + 1


def _unquote(raw):
    """The value of a raw entry body (`everything after `NAME=`), unquoted."""
    if raw[:1] == '"':
        out = []
        i = 1
        while i < len(raw):
            ch = raw[i]
            if ch == "\\" and i + 1 < len(raw):
                nxt = raw[i + 1]
                out.append({"n": "\n", "t": "\t", "r": "\r"}.get(nxt, nxt))
                i += 2
                continue
            if ch == '"':
                return "".join(out)
            out.append(ch)
            i += 1
        return "".join(out)                      # an unterminated quote reads to the end
    if raw[:1] == "'":
        close = raw.find("'", 1)
        return raw[1:] if close < 0 else raw[1:close]
    return raw.rstrip("\r\n")


def _scan_value_end(text, pos):
    """Where the value that starts at `pos` ends (exclusive), as an index into text."""
    n = len(text)
    if pos >= n:
        return n
    if text.startswith(BLOCK_OPEN, pos):
        # An armoured block runs to its own END line — but a block whose END was lost must
        # NOT swallow the entries below it. Measured 2026-11-20: one entry in the real
        # vault is a BEGIN header with no body and no END (a hand restore), and a block
        # reader that scans on to the next END — three entries later — takes five live
        # entries with it. So the block also ends where the next entry begins; the
        # unterminated entry is then reported by name, never silently eaten.
        p = _line_end(text, pos)                       # after the BEGIN line itself
        while p < n:
            end = _line_end(text, p)
            line = text[p:end].strip()
            if line.startswith(BLOCK_CLOSE):
                return end
            # A body line is base64 (padding at the end only) or an old-style PEM header.
            # This test comes BEFORE the entry test on purpose: `ZmFrZQ==` looks like
            # `NAME=` to a regex, and reading it as an entry would split a real block —
            # while a real entry name carries `_`, which base64 never does.
            if line and not line.startswith("#") and (BASE64ISH.fullmatch(line) or PEM_HEADER.fullmatch(line)):
                p = end
                continue
            return p                                   # blank, comment, entry: unterminated
        return n
    if text[pos] == '"':
        i = pos + 1
        while i < n:
            ch = text[i]
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                return _line_end(text, i + 1)
            i += 1
        return n
    if text[pos] == "'":
        close = text.find("'", pos + 1)
        return n if close < 0 else _line_end(text, close + 1)
    p = pos
    while p < n:
        end = _line_end(text, p)
        if not text[p:end].rstrip("\r\n").endswith("\\"):
            return end
        p = end
    return n


def parse(text):
    """Every entry in the text, in file order. Non-entry text is not returned."""
    entries = []
    i = 0
    n = len(text)
    while i < n:
        m = KEY_RE.match(text, i)
        if not m:
            i = _line_end(text, i)
            continue
        start = i
        header = text[start:m.end()]
        vstart = m.end()
        end = _scan_value_end(text, vstart)
        entries.append(Entry(m.group(1), start, end, header, _unquote(text[vstart:end])))
        i = end
    return entries


def render(name, value, header=None):
    """The entry text for one name and value, in a form this parser reads back exactly."""
    head = header or (name + "=")
    if "\n" in value and value.lstrip().startswith(BLOCK_OPEN):
        return head + value.strip("\n") + "\n"           # armoured block, written verbatim
    quoted = (
        "\n" in value
        or value[:1] in ('"', "'")
        or value != value.strip()
        or value.startswith(BLOCK_OPEN)
    )
    if quoted:
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return head + '"' + escaped + '"\n'
    return head + value + "\n"


def set_entry(text, name, value):
    """The text with NAME set to the value: the first entry replaced, or one appended."""
    entries = [e for e in parse(text) if e.name == name]
    if entries:
        first = entries[0]
        return text[:first.start] + render(name, value, first.header) + text[first.end:]
    if text and not text.endswith("\n"):
        text += "\n"
    return text + render(name, value)


def del_entry(text, name):
    """The text with every entry named NAME removed, and nothing else touched."""
    out = []
    cursor = 0
    for entry in parse(text):
        if entry.name != name:
            continue
        out.append(text[cursor:entry.start])
        cursor = entry.end
    out.append(text[cursor:])
    return "".join(out)


def names(text):
    return [e.name for e in parse(text)]


def unterminated(text):
    """The names of armoured blocks whose END line is missing. Names only."""
    return [
        e.name
        for e in parse(text)
        if e.value.lstrip().startswith(BLOCK_OPEN)
        and not e.value.rstrip("\n").splitlines()[-1].lstrip().startswith(BLOCK_CLOSE)
    ]


def diff_entries(before_text, after_text, except_name=None):
    """Entry-level differences between two texts, by NAME.

    Returns a list of (kind, name) where kind is "missing", "extra" or "changed".
    Comparison is byte-for-byte on the raw entry, so a whitespace change is a change.
    """
    before = {}
    order = []
    for e in parse(before_text):
        if e.name == except_name:
            continue
        if e.name not in before:
            order.append(e.name)
        before.setdefault(e.name, []).append(e.raw)
    after = {}
    for e in parse(after_text):
        if e.name == except_name:
            continue
        after.setdefault(e.name, []).append(e.raw)
    problems = []
    for name in order:
        if name not in after:
            problems.append(("missing", name))
        elif after[name] != before[name]:
            problems.append(("changed", name))
    for name in after:
        if name not in before:
            problems.append(("extra", name))
    return problems


def guard(before_text, after_text, key, action):
    """The independent write check. Returns (ok, missing_names, extra_names, message)."""
    before = names(before_text)
    after = names(after_text)
    before_set = {}
    for n in before:
        before_set[n] = before_set.get(n, 0) + 1
    after_set = {}
    for n in after:
        after_set[n] = after_set.get(n, 0) + 1
    missing = [n for n in before_set if after_set.get(n, 0) < before_set[n]]
    extra = [n for n in after_set if after_set.get(n, 0) > before_set.get(n, 0)]

    if action == "set":
        want = len(before) + 1
        ok = not missing and extra == [key]
    elif action == "replace":
        want = len(before)
        ok = not missing and not extra
    elif action == "del":
        want = len(before) - 1
        ok = extra == [] and missing == [key]
    else:
        raise SystemExit("envfile.py: unknown action %r (set|replace|del)" % action)

    if len(after) != want:
        ok = False
    message = ""
    if not ok:
        message = (
            "the write would leave %d entries, not %d (a %s of one key), "
            "so it is refused and nothing was written" % (len(after), want, action)
        )
    return ok, missing, extra, message


def cmd_names(args):
    for name in names(read_text(args.file)):
        print(name)
    return 0


def cmd_count(args):
    print(len(parse(read_text(args.file))))
    return 0


def cmd_has(args):
    return 0 if args.name in names(read_text(args.file)) else 1


def cmd_get(args):
    for entry in parse(read_text(args.file)):
        if entry.name == args.name:
            sys.stdout.write(entry.value + ("\n" if not entry.value.endswith("\n") else ""))
            return 0
    return 1


def cmd_unterminated(args):
    for name in unterminated(read_text(args.file)):
        print(name)
    return 0


def cmd_emit(args):
    for entry in parse(read_text(args.file)):
        print("export %s=%s" % (entry.name, shlex.quote(entry.value)))
    return 0


def _value_from(path):
    text = read_text(path)
    return text.rstrip("\n")


def _emit_result(text, out):
    if out:
        write_text(out, text)
    else:
        sys.stdout.write(text)
    return 0


def cmd_set(args):
    text = read_text(args.file)
    value = _value_from(args.value_file) if args.value_file else args.value
    if value is None:
        print("envfile.py: set needs --value-file or --value", file=sys.stderr)
        return 2
    return _emit_result(set_entry(text, args.name, value), args.out)


def cmd_del(args):
    return _emit_result(del_entry(read_text(args.file), args.name), args.out)


def cmd_diff(args):
    problems = diff_entries(read_text(args.a), read_text(args.b), args.except_name)
    for kind, name in problems:
        print("%s %s" % (kind, name))
    return 1 if problems else 0


def cmd_guard(args):
    ok, missing, extra, message = guard(
        read_text(args.before), read_text(args.after), args.key, args.action
    )
    if ok:
        return 0
    print("error: %s" % message, file=sys.stderr)
    if missing:
        print("the entries that would go missing (names only): %s" % " ".join(missing), file=sys.stderr)
    if extra:
        print("the entries that would appear (names only): %s" % " ".join(extra), file=sys.stderr)
    if not missing and not extra:
        print("the entries kept are not byte-identical to the vault on disk", file=sys.stderr)
    return 1


def main(argv):
    ap = argparse.ArgumentParser(prog="envfile.py", description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("names"); p.add_argument("file"); p.set_defaults(func=cmd_names)
    p = sub.add_parser("count"); p.add_argument("file"); p.set_defaults(func=cmd_count)
    p = sub.add_parser("has"); p.add_argument("file"); p.add_argument("name"); p.set_defaults(func=cmd_has)
    p = sub.add_parser("get"); p.add_argument("file"); p.add_argument("name"); p.set_defaults(func=cmd_get)
    p = sub.add_parser("emit"); p.add_argument("file"); p.set_defaults(func=cmd_emit)
    p = sub.add_parser("unterminated"); p.add_argument("file"); p.set_defaults(func=cmd_unterminated)

    p = sub.add_parser("set")
    p.add_argument("file"); p.add_argument("name")
    p.add_argument("--value-file"); p.add_argument("--value"); p.add_argument("--out")
    p.set_defaults(func=cmd_set)

    p = sub.add_parser("del")
    p.add_argument("file"); p.add_argument("name"); p.add_argument("--out")
    p.set_defaults(func=cmd_del)

    p = sub.add_parser("diff")
    p.add_argument("a"); p.add_argument("b"); p.add_argument("--except", dest="except_name")
    p.set_defaults(func=cmd_diff)

    p = sub.add_parser("guard")
    p.add_argument("--before", required=True); p.add_argument("--after", required=True)
    p.add_argument("--key", required=True); p.add_argument("--action", required=True)
    p.set_defaults(func=cmd_guard)

    args = ap.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
