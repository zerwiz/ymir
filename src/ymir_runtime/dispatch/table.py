"""`dispatch/table.py` — the decision table, read as DATA.

`.agents/roles.yaml` is the canonical wiring (shipped by #223): WHICH role
summons WHICH figure, what the role's craft is, the words that summon it, and
the tools the figure holds at hand. This module declares no role and hardcodes
no name — it reads the YAML and refuses loudly when the data cannot be trusted.

Two rules the data itself states, and this module enforces:

  * `model_from: hoard` — a table that claims its models come from anywhere else
    is refused, because the tree must never carry a model value (Rule 04);
  * every `figure` must be a rostered figure under `.agents/agents/` (the same
    semantic check the config layer runs for an agent name). A role naming a
    figure nobody rostered summons nothing, so it is a refusal, not a warning.

An unknown role or figure is `TableRefusal`, naming the term and the names the
table does know — the config layer's voice, in this package.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence

from ..errors import EngineError

ROLES_RELATIVE = Path(".agents") / "roles.yaml"
AGENTS_RELATIVE = Path(".agents") / "agents"

# The chooser's smith of first resort when no craft word matches — the same
# fallback `bin/agents/eindri-role.sh` uses, so the two choosers cannot disagree.
DEFAULT_ROLE = "developer"

_STOPWORDS = frozenset({"of", "the", "and", "a", "to"})


class TableRefusal(EngineError):
    """The roles table cannot be trusted, or the term is not in it."""

    def __init__(self, message: str, *, key: str = "", remedy: str = "") -> None:
        super().__init__(message)
        self.message = message
        self.key = key
        self.remedy = remedy

    def __str__(self) -> str:  # pragma: no cover - trivial
        where = f" (key {self.key})" if self.key else ""
        tail = f" (remedy: {self.remedy})" if self.remedy else ""
        return f"{self.message}{where}{tail}"


@dataclass(frozen=True)
class Role:
    """One row of the table: a role, its figure, its craft, its tools."""

    name: str
    figure: str
    craft: str
    tools: tuple[str, ...]
    keywords: tuple[str, ...]
    skills: tuple[str, ...]
    dispatch: bool


@dataclass(frozen=True)
class Table:
    """The whole table, in file order — the order is the chooser's tie-break."""

    path: Path
    version: int
    model_from: str
    roles: tuple[Role, ...]

    # ── lookups ──────────────────────────────────────────────────────────────

    def get(self, name: str) -> Role:
        """A role by its key — or a refusal naming every key the table knows."""
        for role in self.roles:
            if role.name == name:
                return role
        raise TableRefusal(
            f"unknown role '{name}'",
            key="roles",
            remedy=f"known roles: {', '.join(self.names())}",
        )

    def by_figure(self, figure: str) -> Role:
        """A role by its figure — the other name a caller may speak."""
        for role in self.roles:
            if role.figure == figure:
                return role
        raise TableRefusal(
            f"unknown figure '{figure}'",
            key="roles",
            remedy=f"known figures: {', '.join(self.figures())}",
        )

    def find(self, term: str) -> Role:
        """A role by its key, else by its figure — as `bin/agents/eindri-role.sh for` does."""
        try:
            return self.get(term)
        except TableRefusal:
            pass
        try:
            return self.by_figure(term)
        except TableRefusal:
            raise TableRefusal(
                f"unknown role or figure '{term}'",
                key="roles",
                remedy=(
                    f"known roles: {', '.join(self.names())} · "
                    f"known figures: {', '.join(self.figures())}"
                ),
            ) from None

    def chooser(self) -> tuple[Role, ...]:
        """The dispatch rows, in chooser order — the roles a smith may be chosen from."""
        return tuple(role for role in self.roles if role.dispatch)

    def choose(self, text: str) -> tuple[Role, int]:
        """The dispatch role whose craft fits `text`, and its score.

        The keywords are the DATA; this is the small decision over them. Scoring
        is word-boundary matched and stable, so the table's own order breaks a
        tie, and a task matching nothing falls to `DEFAULT_ROLE` with score 0.
        """
        lowered = (text or "").lower()
        best: Role | None = None
        best_score = 0
        for role in self.chooser():
            score = 0
            for word in role.keywords:
                if not word or word in _STOPWORDS:
                    continue
                if re.search(r"(?<![A-Za-z0-9_])" + re.escape(word) + r"(?![A-Za-z0-9_])", lowered):
                    score += 1
            if score > best_score:
                best, best_score = role, score
        if best is None:
            for role in self.chooser():
                if role.name == DEFAULT_ROLE:
                    return role, 0
            return self.chooser()[0], 0
        return best, best_score

    def names(self) -> tuple[str, ...]:
        return tuple(role.name for role in self.roles)

    def figures(self) -> tuple[str, ...]:
        return tuple(role.figure for role in self.roles)


# ── reading the data ─────────────────────────────────────────────────────────


def _load_yaml(path: Path) -> Any:
    try:
        import yaml
    except Exception as exc:  # pragma: no cover - PyYAML is a declared dependency
        raise TableRefusal(
            "PyYAML is required to read the roles table and is not installed",
            remedy="bin/engine/ymir-engine-ensure.sh ensure (installs the declared dependencies)",
        ) from exc
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise TableRefusal(f"{path}: the roles table is not valid YAML: {exc}") from exc


def _figure_is_rostered(figure: str, root: Path) -> bool:
    """`.agents/agents/<figure>.md` or `<figure>-*.md` is canonical."""
    roster = root / AGENTS_RELATIVE
    if not roster.is_dir():
        return True  # a config-only context has no roster to judge against
    if (roster / f"{figure}.md").is_file():
        return True
    return any(roster.glob(f"{figure}-*.md"))


def _role_from(name: str, spec: Mapping[str, Any], *, root: Path, source: Path) -> Role:
    figure = str(spec.get("figure") or "").strip()
    if not figure:
        raise TableRefusal(
            f"{source}: role '{name}' names no figure — a role that summons nothing is a refusal",
            key=f"roles.{name}.figure",
        )
    if not _figure_is_rostered(figure, root):
        raise TableRefusal(
            f"{source}: role '{name}' names figure '{figure}', which is not rostered "
            f"(.agents/agents/{figure}.md or {figure}-*.md is canonical)",
            key=f"roles.{name}.figure",
            remedy=f"roster the figure, or point the role at one of: {', '.join(_rostered(root))}",
        )
    def _tokens(key: str) -> tuple[str, ...]:
        raw = spec.get(key) or []
        if isinstance(raw, str):
            raw = [raw]
        return tuple(str(item) for item in raw if str(item).strip())

    return Role(
        name=name,
        figure=figure,
        craft=str(spec.get("craft") or "").strip(),
        tools=_tokens("tools"),
        keywords=_tokens("keywords"),
        skills=_tokens("skills"),
        dispatch=bool(spec.get("dispatch")),
    )


def _rostered(root: Path) -> tuple[str, ...]:
    roster = root / AGENTS_RELATIVE
    if not roster.is_dir():
        return ()
    figures: set[str] = set()
    for entry in roster.glob("*.md"):
        stem = entry.stem
        figures.add(stem.split("-", 1)[0])
    return tuple(sorted(figures))


def read(path: str | Path | None = None, *, root: str | Path | None = None) -> Table:
    """Read, validate and return the roles table — or refuse loudly.

    `path` overrides the canonical location; `root` is the CODE tree that holds
    `.agents/` (tests point it at a fixture).
    """
    code_root = Path(root).expanduser() if root else _default_root()
    source = Path(path).expanduser() if path else code_root / ROLES_RELATIVE
    if not source.is_file():
        raise TableRefusal(
            f"the decision table is absent: {source}",
            remedy="it is canonical at .agents/roles.yaml; restore it or pass --roles",
        )
    document = _load_yaml(source)
    if not isinstance(document, Mapping):
        raise TableRefusal(f"{source}: the table must be a mapping, got {type(document).__name__}")
    roles_raw = document.get("roles")
    if not isinstance(roles_raw, Mapping) or not roles_raw:
        raise TableRefusal(
            f"{source}: the table names no roles",
            key="roles",
            remedy="each role is a mapping with at least a `figure`",
        )
    model_from = str(document.get("model_from") or "hoard")
    if model_from != "hoard":
        raise TableRefusal(
            f"{source}: model_from is '{model_from}', but models must resolve from the hoard",
            key="model_from",
            remedy="set `model_from: hoard` — the tree ships no model value (Rule 04)",
        )
    roles: list[Role] = []
    for name, spec in roles_raw.items():
        if not isinstance(spec, Mapping):
            raise TableRefusal(f"{source}: role '{name}' must be a mapping, got {type(spec).__name__}", key=f"roles.{name}")
        roles.append(_role_from(str(name), spec, root=code_root, source=source))
    return Table(
        path=source,
        version=int(document.get("version") or 1),
        model_from=model_from,
        roles=tuple(roles),
    )


def _default_root() -> Path:
    from .. import paths

    return paths.resolve().root
