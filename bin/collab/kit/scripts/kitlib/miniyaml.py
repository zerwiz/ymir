"""miniyaml — the small YAML subset project.yaml is written in, read with the standard library only.

The kit must run on any machine with a python3, so it carries no dependency. This reader handles what the
kit's own files use and refuses nothing silently:

  key: value              scalars: strings, quoted strings, integers, floats, true/false, null
  key:                    a nested block (a map or a list), indented deeper
  - item                  list items, including "- key: value" maps with their keys indented under them
  [a, "b c"]  {a: 1}      flat inline lists and maps
  # comment               anywhere outside quotes

It is not a general YAML parser: anchors, multi-line strings and tags are not supported, and a line it
cannot read raises ValueError with the line number.
"""
from __future__ import annotations

import re

_KEY = re.compile(r'^("(?:[^"\\]|\\.)*"|\'[^\']*\'|[^\s\'"\[\{#-][^:]*?|-[^\s:][^:]*?)\s*:(\s|$)')


def _strip_comment(s: str) -> str:
    out, quote = [], None
    for i, c in enumerate(s):
        if quote:
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "#" and (i == 0 or s[i - 1] in " \t"):
            break
        out.append(c)
    return "".join(out).rstrip()


def _split_top(s: str) -> list[str]:
    parts, depth, quote, cur = [], 0, None, []
    for c in s:
        if quote:
            cur.append(c)
            if c == quote:
                quote = None
            continue
        if c in "\"'":
            quote = c
        elif c in "[{":
            depth += 1
        elif c in "]}":
            depth -= 1
        elif c == "," and depth == 0:
            parts.append("".join(cur).strip())
            cur = []
            continue
        cur.append(c)
    tail = "".join(cur).strip()
    if tail:
        parts.append(tail)
    return parts


def _unquote(s: str) -> str:
    if len(s) >= 2 and s[0] == s[-1] == '"':
        return re.sub(r'\\(["\\])', r"\1", s[1:-1]).replace("\\n", "\n").replace("\\t", "\t")
    if len(s) >= 2 and s[0] == s[-1] == "'":
        return s[1:-1].replace("''", "'")
    return s


def scalar(s: str):
    s = s.strip()
    if s == "" or s in ("~", "null", "Null", "NULL"):
        return None
    if s[0] in "\"'":
        return _unquote(s)
    if s.startswith("[") and s.endswith("]"):
        return [scalar(x) for x in _split_top(s[1:-1])]
    if s.startswith("{") and s.endswith("}"):
        out = {}
        for part in _split_top(s[1:-1]):
            k, _, v = part.partition(":")
            out[_unquote(k.strip())] = scalar(v)
        return out
    low = s.lower()
    if low in ("true", "yes", "on"):
        return True
    if low in ("false", "no", "off"):
        return False
    if re.fullmatch(r"[-+]?\d+", s):
        return int(s)
    if re.fullmatch(r"[-+]?\d+\.\d*", s):
        return float(s)
    return s


def loads(text: str):
    lines = []
    for n, raw in enumerate(text.splitlines(), 1):
        if "\t" in raw[: len(raw) - len(raw.lstrip())]:
            raise ValueError(f"line {n}: a tab in the indentation")
        content = _strip_comment(raw)
        if not content.strip():
            continue
        indent = len(content) - len(content.lstrip(" "))
        lines.append([indent, content.strip(), n])
    if not lines:
        return {}
    value, i = _block(lines, 0, lines[0][0])
    if i != len(lines):
        raise ValueError(f"line {lines[i][2]}: unexpected indentation")
    return value


def _is_item(content: str) -> bool:
    return content == "-" or content.startswith("- ")


def _block(lines, i, ind):
    if _is_item(lines[i][1]):
        return _list(lines, i, ind)
    return _map(lines, i, ind)


def _list(lines, i, ind):
    out = []
    while i < len(lines) and lines[i][0] == ind and _is_item(lines[i][1]):
        content = lines[i][1]
        rest = content[1:].lstrip()
        if rest == "":
            i += 1
            if i < len(lines) and lines[i][0] > ind:
                v, i = _block(lines, i, lines[i][0])
            else:
                v = None
        elif _KEY.match(rest):
            col = ind + (len(content) - len(rest))
            lines[i] = [col, rest, lines[i][2]]
            v, i = _map(lines, i, col)
        else:
            v = scalar(rest)
            i += 1
        out.append(v)
    return out, i


def _map(lines, i, ind):
    out = {}
    while i < len(lines) and lines[i][0] == ind and not _is_item(lines[i][1]):
        content, n = lines[i][1], lines[i][2]
        m = _KEY.match(content)
        if not m:
            raise ValueError(f"line {n}: expected 'key: value', got {content!r}")
        key = _unquote(m.group(1).strip())
        rest = content[m.end():].strip()
        i += 1
        if rest:
            out[key] = scalar(rest)
        elif i < len(lines) and lines[i][0] > ind:
            out[key], i = _block(lines, i, lines[i][0])
        elif i < len(lines) and lines[i][0] == ind and _is_item(lines[i][1]):
            out[key], i = _list(lines, i, ind)
        else:
            out[key] = None
    return out, i


def load(path: str):
    with open(path, encoding="utf-8") as fh:
        return loads(fh.read())
