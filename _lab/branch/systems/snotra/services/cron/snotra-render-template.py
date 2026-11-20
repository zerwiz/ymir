#!/usr/bin/env python3
"""snotra-render-template — render email templates with placeholder substitution.

WHY: Snotra needs to generate professional emails from templates. The templates
use {{placeholder}} syntax (Jinja2-compatible). This script renders them with
data from a meeting record or a JSON file.

WHAT IT DOES:
    render <template.md> --data <data.json> [--out <file>] [--format md|html]
    list   — list available templates
    preview <template.md> — show the template with placeholder descriptions

USAGE:
    snotra-render-template render midgard/email-templates/internal/followup-team-meeting.md \
        --data meeting-data.json --out followup-email.md
    snotra-render-template list
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

# Try Jinja2 first, fall back to simple string replacement
try:
    import jinja2
    HAS_JINJA = True
except ImportError:
    HAS_JINJA = False


def home_dir() -> Path:
    h = os.environ.get("YMIR_HOME")
    if h:
        return Path(h).expanduser()
    return Path(os.path.expanduser("~")) / "Documents" / "ymirhome"


def template_dirs() -> list[Path]:
    """Find all template directories."""
    dirs = []
    # midgard (public assets)
    midgard = Path(os.path.expanduser("~")) / "ymir" / "midgard" / "email-templates"
    if midgard.is_dir():
        dirs.append(midgard)
    # Also check relative to script
    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parents[3]
    midgard2 = repo_root / "midgard" / "email-templates"
    if midgard2.is_dir() and midgard2 != midgard:
        dirs.append(midgard2)
    return dirs


def list_templates() -> list[dict]:
    """List all available templates."""
    templates = []
    for d in template_dirs():
        for f in d.rglob("*.md"):
            if f.name == "README.md":
                continue
            rel = f.relative_to(d)
            templates.append({"name": str(rel), "path": str(f), "dir": str(d)})
        for f in d.rglob("*.html"):
            rel = f.relative_to(d)
            templates.append({"name": str(rel), "path": str(f), "dir": str(d)})
    return templates


def render_simple(template: str, data: dict) -> str:
    """Simple {{placeholder}} substitution (no Jinja2)."""
    result = template
    for key, value in data.items():
        result = result.replace("{{" + key + "}}", str(value))
        result = result.replace("{{ " + key + " }}", str(value))
    return result


def render_jinja(template: str, data: dict) -> str:
    """Render with Jinja2."""
    env = jinja2.Environment(loader=jinja2.BaseLoader(), autoescape=False)
    tmpl = env.from_string(template)
    return tmpl.render(**data)


def render(template_path: str, data: dict) -> str:
    """Render a template with data."""
    text = Path(template_path).read_text(encoding="utf-8")
    if HAS_JINJA:
        return render_jinja(text, data)
    return render_simple(text, data)


def cmd_list(argv: list[str]) -> int:
    templates = list_templates()
    if not templates:
        print("No templates found. Check midgard/email-templates/")
        return 1
    print(f"Available templates ({len(templates)}):")
    for t in sorted(templates, key=lambda x: x["name"]):
        print(f"  {t['name']}")
    return 0


def cmd_render(argv: list[str]) -> int:
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("template")
    parser.add_argument("--data", required=True)
    parser.add_argument("--out", default=None)
    parser.add_argument("--format", choices=["md", "html"], default=None)
    args = parser.parse_args(argv[2:])

    data = json.loads(Path(args.data).read_text(encoding="utf-8"))
    result = render(args.template, data)

    if args.out:
        Path(args.out).write_text(result, encoding="utf-8")
        print(f"rendered {args.template} -> {args.out}")
    else:
        print(result)
    return 0


def cmd_preview(argv: list[str]) -> int:
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("template")
    args = parser.parse_args(argv[2:])
    text = Path(args.template).read_text(encoding="utf-8")
    # Find all placeholders
    placeholders = set(re.findall(r'\{\{\s*(\w+)\s*\}\}', text))
    print(f"Template: {args.template}")
    print(f"Placeholders ({len(placeholders)}):")
    for p in sorted(placeholders):
        print(f"  {{{{{p}}}}}")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd = argv[1]
    if cmd == "list":
        return cmd_list(argv)
    if cmd == "render":
        return cmd_render(argv)
    if cmd == "preview":
        return cmd_preview(argv)
    print(f"unknown command: {cmd}")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
