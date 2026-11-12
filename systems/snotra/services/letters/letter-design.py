#!/usr/bin/env python3
"""letter-design.py — every outgoing letter, designed: one set of blocks, many themes, a dozen letter types (plan 250 §7).

A letter is written as plain words with a few markers; this renders it into email-safe HTML (tables, inline styles,
no images, fonts with safe fallbacks). The words are never changed — only placed.

  letter-design.py LETTER.md                 render to stdout (the theme comes from the letter's header)
  letter-design.py LETTER.md --theme ymir    override the theme
  letter-design.py --themes                  list the themes
  letter-design.py --types                   list the letter types (templates/house/types/)
  letter-design.py --gallery DIR             render every type in every theme into DIR, with an index.html
  letter-design.py --self-test               the proofs

The letter's header (first lines, between --- and ---):
  theme: ymir | ymir-light | plain | any theme the home defines (hodd/identity/letters/themes.yaml)
  kicker: a small line above the title      title: the big line      subtitle: the line under it
  preheader: the inbox preview text         footer: the small print at the bottom
  use: what this letter type is for (shown by --types)
  made_by: the line under the footer naming who prepared the letter — default "Made with Ymir by <the
           seat's agent>" (the name from ~/.pi/agent/extensions/.ymir-seat, never a machine name); "off" removes it.
           "Ymir" links to Ymir's homepage, and the address is shown beside it
  made_by_url: the homepage the made-by line links to (default YMIR_HOMEPAGE_URL, else https://ymir.zerwiz.org)

The blocks (separated by a blank line):
  ## heading                                 a section title
  plain lines                                a paragraph; **bold**, `code`, [text](url) and bare URLs work
  - item                                     a list
  1. **title** — detail                      numbered rows (decisions, steps)
  | a | b | c |                              a table; a |---| line under the first row makes it the header
  > words                                    a quote
  ::: callout                                a highlighted box            (end each ::: block with :::)
  ::: note Title                             an information box
  ::: warning Title                          a warning box
  ::: card 1 | Owner | Title                 a card with a number and an owner badge
  ::: button Label | https://…               one call to action (a single line, no closing :::)
  ::: stats                                  a figures bar: one "value | label" per line
"""

from __future__ import annotations

import argparse
import hashlib
import html
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = next((p for p in [HERE, *HERE.parents] if (p / "RULES").is_dir() and (p / "midgard").is_dir()), HERE.parents[3])
TOKENS = ROOT / "midgard/design-system/tokens.css"
TYPES = HERE / "templates/house/types"

E = html.escape
SANS = "-apple-system,'Segoe UI',Helvetica,Arial,sans-serif"


def ymir_tokens() -> dict:
    """The house colours, read from the design system Hlidskjalf uses — one source, never copied by hand."""
    vals = {}
    if TOKENS.exists():
        for name, val in re.findall(r"--(ymir-[a-z0-9-]+):\s*([^;]+);", TOKENS.read_text(encoding="utf-8")):
            vals[name] = val.split("/*")[0].strip()
    g = lambda k, d: vals.get(k, d) if vals.get(k, "").startswith("#") else d  # noqa: E731
    return {"stone": g("ymir-bg-0", "#0e0c09"), "panel": g("ymir-bg-1", "#151209"), "panel2": g("ymir-bg-2", "#1a1610"),
            "well": g("ymir-bg-3", "#221d14"), "bronze": g("ymir-cyan-1", "#c9973f"), "bronze2": g("ymir-cyan-2", "#7d5f2a"),
            "steel": g("ymir-violet-1", "#96a0a8"), "steel2": g("ymir-violet-2", "#5f686e"), "line": g("ymir-steel-1", "#2b241a"),
            "bone": g("ymir-text-0", "#cfc3a9"), "bonedim": g("ymir-text-2", "#9a8f75"), "bonefaint": g("ymir-text-3", "#6b6250"),
            "danger": g("ymir-danger", "#c2584a")}


def home_dir() -> Path | None:
    import os
    h = Path(os.environ.get("YMIR_HOME") or os.path.expanduser("~/Documents/ymirhome"))
    return h if h.is_dir() else None


def home_themes(base: dict) -> dict:
    """Company themes live in the HOME, never in this public repository (RULES/04):
    hodd/identity/letters/themes.yaml — one block per theme, `extends:` a shipped theme, then the keys it changes.

      acme:
        extends: ymir-light
        label: Acme
        band: "#57411a"
    """
    h = home_dir()
    f = (h / "hodd/identity/letters/themes.yaml") if h else None
    if not f or not f.exists():
        return {}
    out, cur, name = {}, None, None
    for raw in f.read_text(encoding="utf-8").splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if not raw.startswith(" ") and raw.rstrip().endswith(":"):
            name = raw.strip()[:-1]
            cur = out[name] = {}
        elif cur is not None and ":" in raw:
            k, _, v = raw.strip().partition(":")
            cur[k.strip()] = v.strip().strip("\"'")
    resolved = {}
    for name, keys in out.items():
        parent = dict(base.get(keys.pop("extends", "ymir-light"), base["ymir-light"]))
        if "dark" in keys:
            keys["dark"] = keys["dark"].lower() == "true"
        parent.update(keys)
        resolved[name] = parent
    return resolved


def themes() -> dict:
    shipped = shipped_themes()
    return {**shipped, **home_themes(shipped)}


def shipped_themes() -> dict:
    y = ymir_tokens()
    serif_head = "'Cormorant Garamond',Cormorant,Georgia,'Times New Roman',serif"
    serif_body = "Newsreader,Georgia,'Times New Roman',serif"
    mono = "'IBM Plex Mono',ui-monospace,Menlo,Consolas,monospace"
    base_light = dict(page="#f4efe6", sheet="#fffdf8", card="#ffffff", line="#e3d9c6", ink="#1e1a12", muted="#6b6250",
                      head=serif_head, body=serif_body, mono=mono, code_bg="#f1ebdf",
                      warn="#a8432f", warn_bg="#fbeee8", warn_line="#efc6b8",
                      note_bg="#f3f1ec", note_line="#d9d2c3")
    return {
        "ymir": dict(label="Ymir", page=y["stone"], sheet=y["panel"], card=y["panel2"], line=y["line"], ink=y["bone"],
                     muted=y["bonedim"], accent=y["bronze"], accent2=y["bronze2"], band=y["stone"], band_ink=y["bone"],
                     band_kicker=y["bronze"], band_rule=y["bronze"], callout_bg=y["well"], code_bg=y["well"],
                     warn=y["danger"], warn_bg="#2a1512", warn_line="#5a2a22", note_bg=y["well"], note_line=y["line"],
                     button_ink=y["stone"], head=serif_head, body=serif_body, mono=mono, dark=True),
        "ymir-light": dict(base_light, label="Ymir", accent=y["bronze2"], accent2=y["bronze"], band=y["stone"],
                           band_ink=y["bone"], band_kicker=y["bronze"], band_rule=y["bronze"], callout_bg="#f7efdf",
                           button_ink="#ffffff", dark=False),
        "plain": dict(base_light, label="", page="#f2f3f4", sheet="#ffffff", line="#e1e4e6", ink="#1f2326",
                      muted="#5f686e", accent="#3a4146", accent2="#96a0a8", band="#3a4146", band_ink="#ffffff",
                      band_kicker="#c9d0d5", band_rule="#96a0a8", callout_bg="#f1f3f4", code_bg="#eef0f1",
                      button_ink="#ffffff", dark=False),
    }


BADGES = ["#6b6250", "#7d5f2a", "#2f7d5b", "#a0522d", "#8a6d1f", "#5b6b7a", "#9c3d5f", "#3f6f6a"]


def badge(name: str, t: dict) -> str:
    if not name.strip():
        return ""
    if name.strip().lower() in ("all", "everyone", "team"):
        color = t["muted"]
    else:
        color = BADGES[int(hashlib.sha1(name.strip().lower().encode()).hexdigest(), 16) % len(BADGES)]
    return (f'<span style="display:inline-block;padding:2px 10px;border-radius:999px;background:{color};color:#ffffff;'
            f'font-family:{SANS};font-size:12px;font-weight:600;letter-spacing:.2px;">{E(name.strip())}</span>')


def inline(text: str, t: dict) -> str:
    out = E(text)
    out = re.sub(r"`([^`]+)`", lambda m: f'<code style="font-family:{t["mono"]};font-size:13px;background:{t["code_bg"]};'
                 f'padding:1px 5px;border-radius:4px;">{m.group(1)}</code>', out)
    out = re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)", lambda m: f'<a href="{m.group(2)}" style="color:{t["accent"]};">{m.group(1)}</a>', out)
    out = re.sub(r'(?<!href=")(?<!">)(https?://[^\s<>()"]+[^\s<>().,;:"])',
                 lambda m: f'<a href="{m.group(1)}" style="color:{t["accent"]};">{m.group(1)}</a>', out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    return out


def row(inner: str, pad: str = "8px 32px") -> str:
    return f'<tr><td style="padding:{pad};">{inner}</td></tr>'


def text_cell(html_: str, t: dict, size: int = 15) -> str:
    return f'<div style="font-family:{t["body"]};font-size:{size}px;line-height:1.65;color:{t["ink"]};">{html_}</div>'


def box(inner: str, bg: str, border: str, t: dict) -> str:
    return row(f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{bg};{border}'
               f'border-radius:10px;"><tr><td style="padding:14px 18px;font-family:{t["body"]};font-size:15px;line-height:1.6;'
               f'color:{t["ink"]};">{inner}</td></tr></table>')


def para_lines(lines: list[str], t: dict) -> str:
    return "<br>".join(inline(l, t) for l in lines)


def render_block(kind: str, arg: str, lines: list[str], t: dict) -> str:
    if kind == "callout":
        return box(para_lines(lines, t), t["callout_bg"], f"border-left:4px solid {t['accent']};", t)
    if kind in ("note", "warning"):
        color = t["warn"] if kind == "warning" else t["accent"]
        bg, line = (t["warn_bg"], t["warn_line"]) if kind == "warning" else (t["note_bg"], t["note_line"])
        head = (f'<div style="font-family:{SANS};font-size:12px;font-weight:700;letter-spacing:.7px;text-transform:uppercase;'
                f'color:{color};margin-bottom:4px;">{E(arg)}</div>') if arg else ""
        return box(head + para_lines(lines, t), bg, f"border:1px solid {line};", t)
    if kind == "card":
        parts = [p.strip() for p in arg.split("|")] + ["", "", ""]
        num, owner, title = parts[0], parts[1], parts[2]
        top = (f'<div style="font-family:{SANS};font-size:12px;color:{t["muted"]};margin-bottom:6px;">'
               f'{E(num)}{" &nbsp; " if num else ""}{badge(owner, t)}</div>') if (num or owner) else ""
        ttl = f'<div style="font-family:{t["head"]};font-size:18px;font-weight:700;margin-bottom:6px;">{inline(title, t)}</div>' if title else ""
        body = render_inner(lines, t)
        return box(top + ttl + body, t["card"], f"border:1px solid {t['line']};", t)
    if kind == "stats":
        cells = []
        for l in lines:
            v, _, lab = l.partition("|")
            cells.append(f'<td align="center" style="padding:14px 6px;border-right:1px solid {t["line"]};">'
                         f'<div style="font-family:{t["head"]};font-size:26px;font-weight:700;color:{t["accent"]};">{E(v.strip())}</div>'
                         f'<div style="font-family:{SANS};font-size:12px;color:{t["muted"]};margin-top:2px;">{E(lab.strip())}</div></td>')
        return row(f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{t["card"]};'
                   f'border:1px solid {t["line"]};border-radius:10px;"><tr>{"".join(cells)}</tr></table>')
    if kind == "button":
        label, _, url = arg.partition("|")
        return row(f'<table role="presentation" cellpadding="0" cellspacing="0"><tr><td style="background:{t["accent"]};border-radius:8px;">'
                   f'<a href="{E(url.strip())}" style="display:inline-block;padding:12px 22px;font-family:{SANS};font-size:15px;'
                   f'font-weight:700;color:{t["button_ink"]};text-decoration:none;">{E(label.strip())}</a></td></tr></table>', "14px 32px")
    return render_inner(lines, t)


def render_inner(lines: list[str], t: dict) -> str:
    """Lists, numbered rows, tables and paragraphs — used for top-level blocks and inside cards."""
    if not lines:
        return ""
    if all(re.match(r"^\s*[-*]\s+", l) for l in lines):
        items = "".join(f'<li style="margin:3px 0;">{inline(re.sub(r"^\s*[-*]\s+", "", l), t)}</li>' for l in lines)
        return text_cell(f'<ul style="margin:6px 0 6px 20px;padding:0;">{items}</ul>', t)
    if all(re.match(r"^\s*\d+[.)]\s+", l) for l in lines):
        rows = ""
        for l in lines:
            n, rest = re.match(r"^\s*(\d+)[.)]\s+(.*)$", l).groups()
            title, sep, detail = rest.partition(" — ")
            rows += (f'<tr><td valign="top" style="padding:9px 12px 9px 0;font-family:{SANS};font-size:13px;font-weight:700;'
                     f'color:{t["accent"]};width:22px;">{n}</td><td style="padding:9px 0;border-bottom:1px solid {t["line"]};'
                     f'font-family:{t["body"]};font-size:15px;line-height:1.55;color:{t["ink"]};">{inline(title, t)}'
                     + (f'<br><span style="color:{t["muted"]};font-size:14px;">{inline(detail, t)}</span>' if sep else "")
                     + "</td></tr>")
        return f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0">{rows}</table>'
    if all(l.strip().startswith("|") for l in lines):
        cells = [[c.strip() for c in l.strip().strip("|").split("|")] for l in lines]
        header = None
        if len(cells) > 1 and all(re.match(r"^:?-{2,}:?$", c) for c in cells[1]):
            header, cells = cells[0], cells[2:]
        out = ""
        if header:
            out += "<tr>" + "".join(f'<th align="left" style="padding:8px 10px 8px 0;border-bottom:2px solid {t["accent"]};'
                                    f'font-family:{SANS};font-size:12px;letter-spacing:.5px;text-transform:uppercase;'
                                    f'color:{t["muted"]};">{inline(h, t)}</th>' for h in header) + "</tr>"
        for r in cells:
            out += "<tr>" + "".join(f'<td valign="top" style="padding:9px 10px 9px 0;border-bottom:1px solid {t["line"]};'
                                    f'font-family:{t["body"]};font-size:14px;line-height:1.5;color:{t["ink"] if i else t["ink"]};'
                                    f'{"font-weight:700;white-space:nowrap;" if i == 0 and not header else ""}">{inline(c, t)}</td>'
                                    for i, c in enumerate(r)) + "</tr>"
        return f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0">{out}</table>'
    if all(l.startswith(">") for l in lines):
        q = "<br>".join(inline(l.lstrip("> ").rstrip(), t) for l in lines)
        return (f'<div style="border-left:3px solid {t["accent2"]};padding:4px 0 4px 14px;font-family:{t["body"]};'
                f'font-style:italic;font-size:16px;line-height:1.6;color:{t["muted"]};">{q}</div>')
    return text_cell(para_lines(lines, t), t)


def parse(text: str) -> tuple[dict, list]:
    meta: dict = {}
    lines = text.replace("\r\n", "\n").split("\n")
    if lines and lines[0].strip() == "---":
        end = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
        if end:
            for l in lines[1:end]:
                k, _, v = l.partition(":")
                if k.strip():
                    meta[k.strip().lower()] = v.strip()
            lines = lines[end + 1:]
    blocks, i = [], 0
    while i < len(lines):
        l = lines[i]
        m = re.match(r"^:::\s*(callout|note|warning|card|stats|button)\b\s*(.*)$", l.strip())
        if m:
            kind, arg = m.group(1), m.group(2).strip()
            if kind == "button":
                blocks.append((kind, arg, []))
                i += 1
                continue
            body, i = [], i + 1
            while i < len(lines) and lines[i].strip() != ":::":
                body.append(lines[i].rstrip())
                i += 1
            blocks.append((kind, arg, [b for b in body if b.strip()]))
            i += 1
            continue
        if l.startswith("## ") or l.startswith("# "):
            blocks.append(("heading", l.lstrip("# ").strip(), []))
            i += 1
            continue
        if not l.strip():
            i += 1
            continue
        para = []
        while i < len(lines) and lines[i].strip() and not lines[i].strip().startswith(":::") and not lines[i].startswith("#"):
            para.append(lines[i].rstrip())
            i += 1
        blocks.append(("text", "", para))
    return meta, blocks


def render(text: str, theme: str | None = None) -> str:
    meta, blocks = parse(text)
    all_t = themes()
    name = (theme or meta.get("theme") or "ymir-light").lower()
    if name not in all_t:
        raise SystemExit(f"letter-design: unknown theme {name!r} — one of {', '.join(all_t)}")
    t = all_t[name]
    kicker = meta.get("kicker") or t["label"]
    title, subtitle = meta.get("title", ""), meta.get("subtitle", "")
    pre = meta.get("preheader", subtitle or title)
    out = []
    if title or kicker:
        out.append(
            f'<tr><td style="background:{t["band"]};padding:30px 32px 26px;border-bottom:3px solid {t["band_rule"]};">'
            + (f'<div style="font-family:{SANS};font-size:12px;letter-spacing:1.8px;text-transform:uppercase;color:{t["band_kicker"]};">{E(kicker)}</div>' if kicker else "")
            + (f'<div style="font-family:{t["head"]};font-size:28px;font-weight:700;line-height:1.2;color:{t["band_ink"]};margin-top:6px;">{inline(title, t)}</div>' if title else "")
            + (f'<div style="font-family:{t["body"]};font-size:15px;color:{t["band_kicker"]};margin-top:8px;">{inline(subtitle, t)}</div>' if subtitle else "")
            + "</td></tr>")
    first = True
    for kind, arg, lines in blocks:
        if kind == "heading":
            out.append(row(f'<div style="font-family:{t["head"]};font-size:22px;font-weight:700;color:{t["ink"]};'
                           f'border-bottom:1px solid {t["line"]};padding-bottom:6px;">{inline(arg, t)}</div>', "26px 32px 6px"))
        elif kind == "text":
            out.append(row(render_inner(lines, t), "22px 32px 6px" if first else "8px 32px"))
        else:
            out.append(render_block(kind, arg, lines, t))
        first = False
    footer = meta.get("footer", "")
    out.append(f'<tr><td style="padding:22px 32px;border-top:1px solid {t["line"]};font-family:{SANS};font-size:12px;'
               f'line-height:1.5;color:{t["muted"]};">{inline(footer, t) if footer else E(t["label"])}'
               + (f'<div style="margin-top:6px;font-size:11px;letter-spacing:0.3px;">{made_by_html(made, meta, t)}</div>'
                  if (made := made_by_line(meta)) else "")
               + '</td></tr>')
    fonts = ('<link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@600;700&family=Newsreader:'
             'opsz,wght@6..72,400;6..72,600&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">')
    return (f'<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<meta name="color-scheme" content="{"dark" if t["dark"] else "light"}"><title>{E(title or kicker)}</title>{fonts}</head>'
            f'<body style="margin:0;padding:0;background:{t["page"]};">'
            f'<div style="display:none;max-height:0;overflow:hidden;opacity:0;">{E(pre)}</div>'
            f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="{t["page"]}" style="background:{t["page"]};">'
            f'<tr><td align="center" style="padding:24px 12px;"><table role="presentation" width="600" cellpadding="0" cellspacing="0" '
            f'bgcolor="{t["sheet"]}" style="max-width:600px;width:100%;background:{t["sheet"]};border-radius:14px;overflow:hidden;'
            f'border:1px solid {t["line"]};">{"".join(out)}</table></td></tr></table></body></html>')


YMIR_HOMEPAGE = "https://ymir.zerwiz.org"   # Ymir's public homepage, the one default (Rule 07)


def made_by_html(made: str, meta: dict, t: dict) -> str:
    """The made-by line with "Ymir" linked to Ymir's homepage, and the address shown after it — a reader whose
    mail program strips links can still find the page. A replaced line that does not name Ymir keeps only the link
    at its end."""
    url = (meta.get("made_by_url", "").strip() or os.environ.get("YMIR_HOMEPAGE_URL", "").strip() or YMIR_HOMEPAGE)
    a = f'style="color:{t["muted"]};text-decoration:underline;"'
    shown = re.sub(r"^https?://", "", url).rstrip("/")
    text = E(made)
    if "Ymir" in text:
        text = text.replace("Ymir", f'<a href="{E(url)}" {a}>Ymir</a>', 1)
    return f'{text} · <a href="{E(url)}" {a}>{E(shown)}</a>'


def made_by_line(meta: dict) -> str:
    """The line that says the letter was prepared with Ymir, and by which agent (Rule 44: an agent says whose it is).

    The agent's name is the seat's sealed `primary=` from ~/.pi/agent/extensions/.ymir-seat (or YMIR_AGENT_NAME).
    The machine is never named (Rule 39). `made_by: off` in the header removes the line; any other value replaces it.
    """
    want = meta.get("made_by", "").strip()
    if want.lower() in ("off", "no", "none", "false"):
        return ""
    if want:
        return want
    agent = os.environ.get("YMIR_AGENT_NAME", "").strip()
    if not agent:
        seat = Path(os.path.expanduser("~/.pi/agent/extensions/.ymir-seat"))
        try:
            fields = dict(l.split("=", 1) for l in seat.read_text(encoding="utf-8").splitlines() if "=" in l)
        except OSError:
            fields = {}
        # Rule 44: an unsealed name is rendered as unnamed, never invented — so only a sealed seat signs.
        if fields.get("status", "").strip() == "sealed":
            agent = fields.get("primary", "").strip()
    return f"Made with Ymir by {agent}" if agent else "Made with Ymir"


def type_files() -> list[Path]:
    """The shipped letter types, then the home's own (hodd/identity/letters/types/) — a private type shadows a shipped one."""
    found = {f.stem: f for f in sorted(TYPES.glob("*.md"))}
    h = home_dir()
    if h and (h / "hodd/identity/letters/types").is_dir():
        found.update({f.stem: f for f in sorted((h / "hodd/identity/letters/types").glob("*.md"))})
    return [found[k] for k in sorted(found)]


def gallery(dest: Path) -> int:
    dest.mkdir(parents=True, exist_ok=True)
    links = []
    for f in type_files():
        for name in themes():
            out = dest / f"{f.stem}--{name}.html"
            out.write_text(render(f.read_text(encoding="utf-8"), name), encoding="utf-8")
            links.append(f'<li><a href="{out.name}">{E(f.stem)} — {E(name)}</a></li>')
    (dest / "index.html").write_text("<!doctype html><meta charset='utf-8'><title>Letter gallery</title>"
                                     f"<h1>Letter gallery</h1><ul>{''.join(links)}</ul>", encoding="utf-8")
    print(f"letter-design: {len(links)} letters rendered into {dest}/index.html")
    return 0


def self_test() -> int:
    failures = []
    for f in type_files():
        src = f.read_text(encoding="utf-8")
        meta, blocks = parse(src)
        for name in themes():
            h = render(src, name)
            if "<img" in h.lower():
                failures.append(f"{f.name}/{name}: an image")
            if "<script" in h.lower():
                failures.append(f"{f.name}/{name}: a script")
            for kind, arg, lines in blocks:
                for l in lines:
                    word = re.sub(r"[^A-Za-z]{1,}", " ", l).split()
                    if word and E(max(word, key=len)) not in h:
                        failures.append(f"{f.name}/{name}: lost words from {l[:40]!r}")
    if len(type_files()) < 10:
        failures.append(f"expected at least 10 letter types, found {len(type_files())}")
    h = render("---\ntheme: ymir\ntitle: <b>x</b>\n---\nA & B <i>", None)
    if "<b>x</b>" in h or "<i>" in h:
        failures.append("markup in the words is not escaped")
    os.environ["YMIR_AGENT_NAME"] = "TestAgent"
    made = render("---\ntheme: plain\ntitle: t\n---\nHi", None)
    if "</a> by TestAgent" not in made or ">Ymir</a>" not in made:
        failures.append("the made-by line does not name Ymir and the agent")
    if 'href="https://ymir.zerwiz.org"' not in made or ">ymir.zerwiz.org</a>" not in made:
        failures.append("the made-by line does not link Ymir's homepage")
    if 'href="https://example.org/y"' not in render("---\ntheme: plain\ntitle: t\nmade_by_url: https://example.org/y\n---\nHi", None):
        failures.append("made_by_url does not change the link")
    if "Made with Ymir" in render("---\ntheme: plain\ntitle: t\nmade_by: off\n---\nHi", None):
        failures.append("made_by: off does not remove the line")
    del os.environ["YMIR_AGENT_NAME"]
    y = themes()["ymir"]
    if y["accent"].lower() != ymir_tokens()["bronze"].lower():
        failures.append("the ymir theme does not read its bronze from the design tokens")
    for msg in failures:
        print("FAIL", msg)
    print(f"letter-design self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'} "
          f"({len(type_files())} types × {len(themes())} themes)")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="letter-design.py", description=__doc__.split("\n")[0])
    ap.add_argument("letter", nargs="?", help="the letter file, or - for stdin")
    ap.add_argument("--theme")
    ap.add_argument("--themes", action="store_true")
    ap.add_argument("--types", action="store_true")
    ap.add_argument("--gallery")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args(argv)
    if a.self_test:
        return self_test()
    if a.themes:
        for k, v in themes().items():
            print(f"{k:<11} {v['label'] or '(no name)':<9} band {v['band']}  accent {v['accent']}  {'dark' if v['dark'] else 'light'}")
        return 0
    if a.types:
        for f in type_files():
            meta, _ = parse(f.read_text(encoding="utf-8"))
            print(f"{f.stem:<20} {meta.get('theme', ''):<11} {meta.get('use', '')}")
        return 0
    if a.gallery:
        return gallery(Path(a.gallery))
    if not a.letter:
        ap.print_help()
        return 2
    src = sys.stdin.read() if a.letter == "-" else Path(a.letter).read_text(encoding="utf-8")
    sys.stdout.write(render(src, a.theme))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
