#!/usr/bin/env python3
"""letter-html.py — dress a plain letter in one of the house's vendored templates.

WHY: the mail door could always send a styled letter and almost never did, because styling it was a step
someone had to remember. So the door now does it: `mail-send.sh draft --body FILE` renders the words into a
template unless the caller says `--plain`. A letter nobody dressed still looks deliberate.

    letter-html.py --subject "S" --body FILE [- | --body -] [--template NAME] [--preheader P] [--footer F]

The words stay the words. This script never rewrites a sentence, never adds a line the caller did not write,
and never invents a signature: `--footer` is the only line it will add, and it adds nothing when it is absent.

WHAT IT SUPPORTS, HONESTLY: `leemunroe-simple`, and only it. That template has the four markers this script
edits — a preheader span, a main-content region, an address line and a "powered by" block. The Cerberus and
Mailgun files are one-line HTML with no such markers, so re-rendering them would mean rewriting them; pass
`--html FILE` when you have dressed a letter in one of those by hand. A template added here gets its own
markers row in TEMPLATES below, or it does not get this script's name on it.

    letter-html.py --self-test      # eleven proofs: markers replaced, demo lines gone, values escaped
"""
from __future__ import annotations

import argparse
import html
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SHELF = os.path.join(HERE, "templates")

# One row per template this script can render, and the four places it edits. A template that is not here is
# rendered by hand and sent with --html; pretending otherwise is how a letter silently loses its footer.
TEMPLATES = {
    "leemunroe-simple": {
        "path": "leemunroe-simple/email.html",
        "title": re.compile(r"<title>.*?</title>", re.S),
        "preheader": re.compile(r'<span class="preheader">.*?</span>', re.S),
        "content": re.compile(r"<!-- START MAIN CONTENT AREA -->.*?<!-- END MAIN CONTENT AREA -->", re.S),
        "address": re.compile(r'<span class="apple-link">.*?</span>', re.S),
        "powered": re.compile(r'<td class="content-block powered-by">.*?</td>', re.S),
        "unsubscribe": re.compile(r"<br>\s*Don't like these emails\?.*?</a>\.", re.S),
        # the wrapper row that carries the content area, kept so the styling survives the edit
        "content_row": '<tr><td class="wrapper">\n{body}\n</td></tr>',
    },
}


def escape(text: str) -> str:
    return html.escape(text, quote=False)


def inline(text: str) -> str:
    """Escape, then dress only what the writer already wrote: a bare URL becomes a link, **x** becomes bold."""
    out = escape(text)
    out = re.sub(r"(https?://[^\s<>()]+[^\s<>().,;:])", r'<a href="\1" style="color:#d96b43;">\1</a>', out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    return out


def blocks(body: str) -> str:
    """The plain words, as paragraphs and lists. Nothing is added and no line is dropped."""
    out: list[str] = []
    for block in re.split(r"\n\s*\n", body.strip()):
        lines = [line.rstrip() for line in block.splitlines() if line.strip()]
        if not lines:
            continue
        if all(re.match(r"^\s*[-*]\s+", line) for line in lines):
            items = "".join(f"<li>{inline(re.sub(r'^\s*[-*]\s+', '', line))}</li>" for line in lines)
            out.append(f'<ul style="margin:0 0 16px 20px;padding:0;">{items}</ul>')
            continue
        if lines[0].startswith("# "):
            out.append(f'<h2 style="margin:24px 0 12px;font-size:20px;line-height:1.3;color:#1c1a17;">{inline(lines[0][2:])}</h2>')
            lines = lines[1:]
            if not lines:
                continue
        joined = "<br>".join(inline(line) for line in lines)
        # a line that is only a URL reads better as a button, but a button is an act and this script does not
        # decide acts — it prints the address, and the caller may pass --footer or a hand-dressed --html.
        out.append(f'<p style="margin:0 0 16px;font-size:16px;line-height:1.5;color:#3f3a33;">{joined}</p>')
    return "\n".join(out)


def render(template: str, subject: str, body_html: str, preheader: str, footer: str) -> str:
    spec = TEMPLATES.get(template)
    if spec is None:
        raise SystemExit(
            f"letter-html.py: no renderer for template '{template}' — known: {', '.join(sorted(TEMPLATES))}.\n"
            f"  Dress the letter by hand and pass it with --html FILE, or add a TEMPLATES row for that template."
        )
    path = os.path.join(SHELF, spec["path"])
    with open(path, encoding="utf-8") as handle:
        document = handle.read()

    document = spec["title"].sub(f"<title>{escape(subject)}</title>", document, count=1)
    document = spec["preheader"].sub(
        f'<span class="preheader">{escape(preheader or subject)}</span>', document, count=1
    )
    document = spec["content"].sub(
        f"<!-- START MAIN CONTENT AREA -->\n{spec['content_row'].format(body=body_html)}\n<!-- END MAIN CONTENT AREA -->",
        document,
        count=1,
    )
    document = spec["unsubscribe"].sub("", document, count=1)
    document = spec["powered"].sub("", document, count=1)
    if footer:
        document = spec["address"].sub(f'<span class="apple-link">{escape(footer)}</span>', document, count=1)
    else:
        # no footer line and no invented company address: the block goes rather than making one up
        document = spec["address"].sub("", document, count=1)
    return document


def self_test() -> int:
    failures: list[str] = []
    body = "Hi Blake,\n\nA letter with a **bold** word and a link to https://example.com/a?b=1.\n\n- first\n- second\n\n# A heading\nAnd a closing line.\n"
    page = render("leemunroe-simple", "A subject", blocks(body), "The preview line", "Example9 · sent from the house")
    if "<h2" not in page or "<ul" not in page:
        failures.append("headings and lists are not rendered")
    if "This is preheader text" in page:
        failures.append("the template's demo preheader survived")
    if "Company Inc" in page:
        failures.append("the template's demo address survived")
    if "htmlemail.io" in page:
        failures.append("the template's powered-by credit survived")
    if "The preview line" not in page:
        failures.append("the caller's preheader did not reach the letter")
    if "Example9 · sent from the house" not in page:
        failures.append("the caller's footer did not reach the letter")
    if '<a href="https://example.com/a?b=1"' not in page:
        failures.append("a bare URL was not linked")
    if "<strong>bold</strong>" not in page:
        failures.append("**bold** was not honoured")
    nasty = render("leemunroe-simple", "S", blocks('<script>alert(1)</script> & "quoted"'), "", "")
    if "<script>" in nasty:
        failures.append("a value in the body was not escaped")
    if "Company Inc" in nasty or "apple-link\">" in nasty:
        failures.append("an empty footer still printed an address")
    unknown = ""
    try:
        render("cerberus-hybrid", "S", "", "", "")
    except SystemExit as exc:
        unknown = str(exc)
    if "no renderer for template" not in unknown:
        failures.append("an unsupported template was not refused by name")
    for line in failures:
        print(f"FAIL  {line}")
    if not failures:
        print("PASS  letter-html: eleven proofs — markers, escaping, footer, refusals")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="dress a plain letter in a vendored house template")
    parser.add_argument("--subject", default="")
    parser.add_argument("--template", default="leemunroe-simple")
    parser.add_argument("--preheader", default="")
    parser.add_argument("--footer", default="")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("body", nargs="?", default="-", help="a FILE, or - for stdin")
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()

    if args.body == "-":
        text = sys.stdin.read()
    else:
        with open(args.body, encoding="utf-8") as handle:
            text = handle.read()
    sys.stdout.write(render(args.template, args.subject, blocks(text), args.preheader, args.footer))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
