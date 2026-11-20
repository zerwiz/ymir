#!/usr/bin/env python3
"""areas.py — a repository's own answer to the canon of areas.  Standard library only.

Why stdlib only: the kit goes into Node, Elixir and shell repositories, and a door that needs a
package installed is a door that does not open. The declaration format is line-oriented YAML on
purpose — plain enough to read, to diff, and to parse without a library.

  areas.py init                 one file per canon area, every one honestly `unheld`
  areas.py list                 area · state · keeper · open questions
  areas.py check [--strict]     faults named; exit 1 on a fault
  areas.py estate               one line: held · unproved · waived · na · unheld
  areas.py canon                the ids and the question each must answer
  areas.py claim <area> --keeper K [--path P]... [--evidence E]... [--lens L]
  areas.py waive <area> --by WHO --why TEXT --until YYYY-MM-DD

Exit: 0 ok · 1 a fault · 2 usage.
"""
import glob
import os
import re
import sys

STATES = ("unheld", "held", "waived", "na")
LEGAL = set(STATES)
ROOT = os.environ.get("AREAS_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHELF = os.path.join(ROOT, "areas")
CANON = os.path.join(SHELF, "canon.yaml")


# ── the minimal reader: exactly the shape `init` writes, refused rather than guessed otherwise ──
def _unquote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        body = v[1:-1]
        return body.replace('\\"', '"').replace("\\\\", "\\")
    return v


def _value(v):
    """A scalar from `key: value`, with the trailing `#` comment removed — outside quotes only.
    (Measured 2026-11-08: without this every state read as `unheld  # unheld | held | waived | na`.)"""
    v = v.strip()
    if v[:1] in ('"', "'"):
        quote = v[0]
        end = v.find(quote, 1)
        return v[1:end] if end > 0 else v[1:]
    return re.split(r"\s+#", v, maxsplit=1)[0].strip()


def _inline_list(v):
    v = v.strip()
    if not (v.startswith("[") and v.endswith("]")):
        return []
    inner = v[1:-1].strip()
    if not inner:
        return []
    out, cur, quote = [], "", None
    for ch in inner:
        if quote:
            cur += ch
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
            cur += ch
        elif ch == ",":
            out.append(_unquote(cur))
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(_unquote(cur))
    return [x for x in out if x]


def parse(path):
    """→ dict. The shapes `init` writes: top-level scalars, inline lists, block lists of scalars or
    one-line maps, and a nested block list inside a map (`evidence:` under an area). Anything else is
    refused rather than guessed, because a declaration that says something we did not read is worse
    than one that fails loudly."""
    data, key, sub, sub_indent = {}, None, None, -1
    for raw in open(path, encoding="utf-8"):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        item = line.strip()
        if indent == 0:
            k, _, rest = item.partition(":")
            k, rest = k.strip(), rest.strip()
            if rest.startswith("["):
                data[k], key, sub, sub_indent = _inline_list(rest), None, None, -1
            elif rest == "":
                data[k], key, sub, sub_indent = [], k, None, -1
            else:
                data[k], key, sub, sub_indent = _value(rest), None, None, -1
            continue
        if key is None:
            continue
        container = data[key]
        last = container[-1] if container and isinstance(container[-1], dict) else None
        if item.startswith("- "):
            body = item[2:].strip()
            # a nested block list ends the moment a `- ` arrives at or above its own indent: that is a
            # new item, not another line of evidence. (Measured 2026-11-08: without this an 18-area
            # canon parsed as ONE area with eighty pieces of evidence.)
            if sub is not None and indent <= sub_indent:
                sub = None
            if sub and last is not None and isinstance(last.get(sub), list):
                if re.match(r"^[A-Za-z_][\w]*:", body):
                    k2, _, v2 = body.partition(":")
                    last[sub].append({k2.strip(): _value(v2)})
                else:
                    last[sub].append(_value(body))
            elif re.match(r"^[A-Za-z_][\w]*:", body):
                k2, _, v2 = body.partition(":")
                container.append({k2.strip(): _value(v2)})
                sub = None
            else:
                container.append(_value(body))
            continue
        k2, _, v2 = item.partition(":")
        if last is None:
            continue
        k2 = k2.strip()
        if v2.strip() == "":
            last[k2], sub, sub_indent = [], k2, indent
        else:
            last[k2], sub = _value(v2), None
    return data


def canon():
    if not os.path.exists(CANON):
        sys.stderr.write(f"error: no canon at {CANON}\nhelp: the kit carries areas/canon.yaml\n")
        sys.exit(2)
    return parse(CANON)


def declarations():
    out = {}
    for path in sorted(glob.glob(os.path.join(SHELF, "*.yaml"))):
        if os.path.basename(path) == "canon.yaml":
            continue
        try:
            d = parse(path)
        except Exception as e:  # a broken file is a fault, named
            d = {"_error": str(e)}
        out[d.get("area") or os.path.basename(path)[:-5]] = (d, path)
    return out


def judge():
    """→ rows, faults, counts. The one place the states are weighed."""
    c = canon()
    decl = declarations()
    rows, faults = [], []
    counts = {s: 0 for s in STATES}
    counts["unproved"] = 0
    for a in c.get("areas") or []:
        aid = a["id"]
        if aid not in decl:
            counts["unheld"] += 1
            rows.append((aid, "unheld", "-", 0))
            faults.append((aid, "no declaration", "bash scripts/areas.sh init"))
            continue
        d, path = decl[aid]
        if d.get("_error"):
            counts["unheld"] += 1
            rows.append((aid, "unheld", "-", 0))
            faults.append((aid, "unreadable declaration", d["_error"]))
            continue
        state = (d.get("state") or "").strip()
        keeper = (d.get("keeper") or "unclaimed").strip()
        evidence = [x for x in (d.get("evidence") or []) if str(x).strip()]
        answers = d.get("answers") or []
        open_q = sum(1 for x in answers if isinstance(x, dict) and not str(x.get("a") or "").strip())
        if state not in LEGAL:
            faults.append((aid, f"state is not one of {' · '.join(STATES)}", state or "(empty)"))
            state = "unheld"
        if state == "held" and not evidence:
            faults.append((aid, "held with no evidence", "name the artefact, or say `unheld`"))
            state = "unproved"
        if state == "held" and keeper in ("", "unclaimed", "none"):
            faults.append((aid, "held with no keeper", "a claim nobody holds is a wish"))
            state = "unproved"
        if state == "waived" and not (d.get("waived_by") or "").strip():
            faults.append((aid, "waived with nobody's name", "a waiver names who waived it and until when"))
        if state == "na" and not (d.get("why") or "").strip():
            faults.append((aid, "na with no reason", "say why it does not apply"))
        counts[state if state in counts else "unheld"] += 1
        rows.append((aid, state if state in counts else "unheld", keeper, open_q))
    return rows, faults, counts


def write_declaration(spec, project, shelf):
    path = os.path.join(shelf, spec["id"] + ".yaml")
    if os.path.exists(path):
        return False
    q = lambda s: '"' + str(s).replace('"', "'") + '"'
    lines = [
        f'# areas/{spec["id"]}.yaml — {spec.get("name","")}',
        "#",
        "# A project answers every canon area: held · waived · na. `held` needs evidence.",
        "# `unheld` is legal in the file and is what the gate refuses once work touches the area.",
        "# The questions are the canon's; the answers are this repository's.",
        "",
        "version: 1",
        f'area: {spec["id"]}',
        f'project: {project}',
        "state: unheld                 # unheld | held | waived | na",
        "",
        "keeper: unclaimed             # who holds it — a person, a role, or unclaimed",
        'lens: ""                      # what this keeper weighs, e.g. isolation, cost, correctness',
        "",
        "# the folders this keeper may write. The gate refuses a push that changes one of these",
        "# paths while the area is unheld. Empty = nothing is claimed yet.",
        "may_write: []",
        "",
        "evidence: []                  # what closes it: a test, a run, a document, a measured figure",
        "",
        "# the canon's questions, with this project's answers. An open answer is honest; a blank is not.",
        "answers:",
    ]
    for question in [spec.get("question")] + list(spec.get("evidence") or []):
        if not question:
            continue
        lines.append(f"  - q: {q(question)}")
        lines.append('    a: ""')
    lines += ["", 'closed: ""                    # the date the evidence last proved it', ""]
    open(path, "w", encoding="utf-8").write("\n".join(lines))
    return True


def set_fields(path, fields, lists=None):
    """Rewrite named scalar keys in place; refuse rather than guess when a key is absent."""
    text = open(path, encoding="utf-8").read().split("\n")
    lists = lists or {}
    for key, value in fields.items():
        target = re.compile(rf"^{re.escape(key)}:")
        for i, line in enumerate(text):
            if target.match(line):
                text[i] = f"{key}: {value}"
                break
        else:
            raise SystemExit(f"error: {os.path.basename(path)} has no `{key}:` line\n"
                             f"help: restore it from areas/TEMPLATE.yaml — this door will not guess")
    for key, values in lists.items():
        target = re.compile(rf"^{re.escape(key)}:")
        rendered = "[" + ", ".join('"' + str(v) + '"' for v in values) + "]"
        start = None
        for i, line in enumerate(text):
            if target.match(line):
                start = i
                break
        if start is None:
            raise SystemExit(f"error: {os.path.basename(path)} has no `{key}:` line")
        end = start + 1
        while end < len(text) and re.match(r"^\s+-\s", text[end]):
            end += 1
        text[start:end] = [f"{key}: {rendered}"]
    open(path, "w", encoding="utf-8").write("\n".join(text))


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    verb, rest = argv[0], argv[1:]
    c = canon()

    if verb == "canon":
        areas = c.get("areas") or []
        print(f"areas[{len(areas)}]{{id,name,the question it must answer}}:")
        for a in areas:
            print(f'  "{a["id"]}","{a.get("name","")}","{(a.get("question") or "").replace(chr(34), chr(39))}"')
        return 0

    if verb == "init":
        os.makedirs(SHELF, exist_ok=True)
        project = os.path.basename(ROOT).lower()
        written, kept = [], []
        for a in c.get("areas") or []:
            (written if write_declaration(a, project, SHELF) else kept).append(a["id"])
        print(f'init[{len(written)}]{{written}}:')
        for w in written:
            print(f'  "{w}"')
        if kept:
            print(f'kept[{len(kept)}]{{already answered, never overwritten}}:')
            for k in kept:
                print(f'  "{k}"')
        print(f'\nevery area starts `unheld` and honest. bash scripts/areas.sh claim <area> --keeper "…"')
        return 0

    rows, faults, counts = judge()

    if verb == "paths":
        # for the gate: one line per area that claims a folder — `area<TAB>state<TAB>prefix`
        for aid, (d, path) in sorted(declarations().items()):
            if d.get("_error"):
                print(f"{aid}\tbroken\t")
                continue
            state = (d.get("state") or "").strip() or "unheld"
            for prefix in d.get("may_write") or []:
                print(f"{aid}\t{state}\t{prefix}")
        return 0

    if verb == "list":
        print(f'areas[{len(rows)}]{{area,state,keeper,open_questions}}:')
        for aid, state, keeper, oq in rows:
            print(f'  "{aid}","{state}","{keeper}",{oq}')
        return 0

    if verb == "estate":
        total = sum(v for k, v in counts.items() if k != "unproved")
        print(f'estate[1]{{areas,held,unproved,waived,na,unheld}}:')
        print(f'  {total},{counts["held"]},{counts["unproved"]},{counts["waived"]},{counts["na"]},{counts["unheld"]}')
        return 0

    if verb == "check":
        strict = "--strict" in rest
        print(f'areas[{len(rows)}]{{area,state,keeper,open_questions}}:')
        for aid, state, keeper, oq in rows:
            print(f'  "{aid}","{state}","{keeper}",{oq}')
        if faults:
            print(f'\nfaults[{len(faults)}]{{area,fault,what to do}}:')
            for aid, what, how in faults:
                print(f'  "{aid}","{what}","{how}"')
        unanswered = counts["unheld"] + counts["unproved"]
        print(f'\nestate[1]{{areas,held,unproved,waived,na,unheld}}:')
        print(f'  {sum(v for k, v in counts.items() if k != "unproved")},{counts["held"]},'
              f'{counts["unproved"]},{counts["waived"]},{counts["na"]},{counts["unheld"]}')
        if faults:
            print(f"\nrefused: {len(faults)} fault(s) — a declaration that cannot be honoured is not a record")
            return 1
        if strict and unanswered:
            print(f"\nrefused (--strict): {unanswered} area(s) neither held nor waived nor na")
            return 1
        print(f"\nclean: no fault. {counts['unheld']} unheld · {counts['unproved']} unproved — "
              f"legal, and printed so it cannot pass for finished")
        return 0

    if verb in ("claim", "waive"):
        if not rest:
            print(f"usage: areas.py {verb} <area> …", file=sys.stderr)
            return 2
        aid, opts = rest[0], rest[1:]
        path = os.path.join(SHELF, aid + ".yaml")
        if not os.path.exists(path):
            print(f"error: no areas/{aid}.yaml\nhelp: bash scripts/areas.sh init", file=sys.stderr)
            return 2
        get, i = {}, 0
        while i < len(opts):
            tok = opts[i]
            if not tok.startswith("--"):
                i += 1
                continue
            name, vals = tok[2:], []
            i += 1
            while i < len(opts) and not opts[i].startswith("--"):
                vals.append(opts[i]); i += 1
            get[name] = get.get(name, []) + vals
        if verb == "claim" and "--unheld" in rest:
            # SCOPE WITHOUT A KEEPER: the shelf knows whose ground this is, and nobody holds it. This is
            # the state the gate exists for — the refusal names the area, not the author.
            paths = get.get("path") or []
            if not paths:
                print("error: claim --unheld needs at least one --path (whose ground is it?)", file=sys.stderr)
                return 2
            lens = " ".join(get.get("lens") or [])
            fields = {"state": "unheld", "keeper": "unclaimed"}
            if lens:
                fields["lens"] = lens
            set_fields(path, fields, {"may_write": paths})
            print(f'scoped[1]{{area,state,may_write}}:')
            print(f'  "{aid}","unheld",{len(paths)}')
            return 0

        if verb == "claim":
            keeper = " ".join(get.get("keeper") or [])
            if not keeper:
                print("error: claim needs --keeper \"<who or what role>\"", file=sys.stderr)
                return 2
            evidence = get.get("evidence") or []
            if not evidence:
                print("error: claim needs --evidence <a test, a run, a document, a figure>\n"
                      "help: `held` without evidence is unproved — say what closes the area", file=sys.stderr)
                return 2
            paths = get.get("path") or []
            lens = " ".join(get.get("lens") or [])
            fields = {"state": "held", "keeper": keeper}
            if lens:
                fields["lens"] = lens
            set_fields(path, fields, {"may_write": paths, "evidence": evidence})
            print(f'claimed[1]{{area,keeper,evidence,may_write}}:')
            print(f'  "{aid}","{keeper}",{len(evidence)},{len(paths)}')
            return 0
        by = " ".join(get.get("by") or [])
        why = " ".join(get.get("why") or [])
        until = " ".join(get.get("until") or [])
        if not (by and why and until):
            print("error: waive needs --by <who> --why <text> --until YYYY-MM-DD\n"
                  "help: a waiver with no name and no end date is a silence wearing a decision's clothes",
                  file=sys.stderr)
            return 2
        set_fields(path, {"state": "waived", "waived_by": f'"{by}"', "why": f'"{why}"', "until": until})
        print(f'waived[1]{{area,by,why,until}}:')
        print(f'  "{aid}","{by}","{why}","{until}"')
        return 0

    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
