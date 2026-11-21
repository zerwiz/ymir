"""figure_card — every seat opens with its figure's card, on every harness.

Measured 2026-11-21: `.agents/agents/forseti-reviewer.md`, `sindri-developer.md` and the other
cards existed, and no seat ever handed one to its agent. The judge and the coder were given a
brief and a profile but never told who they were, what their charter keeps, or what their door
is. The card is the figure's own word; the seat's first turn now begins with it.

A card is a Markdown file with a YAML permission header and a body. The header is for harnesses
that read it (opencode); the BODY is what every harness can be told, so that is what this prints.

The one table that maps a role to its figure lives here; a caller may also name a figure
directly (`forseti`), which wins over the role.

CLI (bin/seat/figure-card.sh is its door):
  figure_card.py card <tree> <role-or-figure>     -> the card text, front matter stripped
  figure_card.py figure <role-or-figure>          -> the figure's name
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROLE_FIGURE = {"judge": "forseti", "coder": "sindri", "scout": "kvasir", "helm": "brokk"}
_NAME = re.compile(r"^[a-z][a-z0-9_-]*$")
CARDS = Path(".agents") / "agents"


def figure_of(role_or_figure: str | None) -> str:
    """The figure for a role (judge -> forseti) or a figure named directly; '' when none."""
    name = (role_or_figure or "").strip().lower()
    if not name or not _NAME.match(name):
        return ""
    return ROLE_FIGURE.get(name, name)


def card_path(tree: str | Path, role_or_figure: str | None) -> Path | None:
    figure = figure_of(role_or_figure)
    if not figure:
        return None
    base = Path(tree) / CARDS
    exact = base / f"{figure}.md"
    if exact.is_file():
        return exact
    for path in sorted(base.glob(f"{figure}-*.md")):
        return path
    return None


def body(text: str) -> str:
    """The card without its `---` YAML header."""
    if text.startswith("---\n"):
        end = text.find("\n---", 4)
        if end != -1:
            return text[end + 4 :].lstrip("\n")
    return text


def card_for(tree: str | Path, role_or_figure: str | None) -> str:
    """The card's body headed by whose it is; '' when the figure has no card (a raw role)."""
    path = card_path(tree, role_or_figure)
    if path is None:
        return ""
    text = body(path.read_text(encoding="utf-8")).strip()
    if not text:
        return ""
    return f"# Your card — {figure_of(role_or_figure)} ({path.name})\n\n{text}\n"


def with_card(tree: str | Path, role_or_figure: str | None, prompt: str) -> str:
    """The prompt opened by the card; unchanged when there is no card or it is already there."""
    card = card_for(tree, role_or_figure)
    if not card or "# Your card — " in prompt:
        return prompt
    return card + "\n---\n\n" + prompt


def main(argv: list[str]) -> int:
    if len(argv) == 3 and argv[0] == "card":
        sys.stdout.write(card_for(argv[1], argv[2]))
        return 0
    if len(argv) == 2 and argv[0] == "figure":
        print(figure_of(argv[1]))
        return 0
    print("usage: figure_card.py card <tree> <role-or-figure> | figure <role-or-figure>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
