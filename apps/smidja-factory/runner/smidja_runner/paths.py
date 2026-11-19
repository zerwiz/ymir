"""Where the smithy's parts are, on THIS machine — probed, never assumed (RULES/25).

Every door (the `smidja` command, the MCP, a remote call) resolves through here,
so two doors can never disagree about which engine, config or trace they mean.

Resolution, first hit wins:
  factory   SMIDJA_FACTORY_DIR · the folder this package ships in
  project   --project-dir · SMIDJA_PROJECT_DIR · the git toplevel of the cwd · the cwd
  engine    SMIDJA_ENGINE_DIR · <project>/smidja · <project>/apps/smidja · <factory>/engine (the installed
            app's own) · the engine beside the factory (Ymir's tree before the split)
  config    SMIDJA_CONFIG · <engine>/smidja_smidja_config/smidja.config.yaml
  db        SMIDJA_DB · CMD_DB (the viewer's own variable) · $YMIR_HOME/smidja/smidja.db
            (when the home exists) · ${XDG_STATE_HOME:-~/.local/state}/smidja/smidja.db
  data      the folder the db sits in: <db dir>/sessions/<id>/ — the viewer reads the same
  viewer    SMIDJA_VIEWER_URL · http://127.0.0.1:${SMIDJA_VIZ_API_PORT:-8437}
"""

from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

FACTORY = Path(__file__).resolve().parents[2]


def _git_top(start: Path) -> Path | None:
    try:
        out = subprocess.run(["git", "-C", str(start), "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return Path(out.stdout.strip()) if out.returncode == 0 and out.stdout.strip() else None


def _is_engine(path: Path) -> bool:
    return path.is_dir() and (path / "smidja_modules").is_dir() and any(path.glob("smidja_*.py"))


def factory_dir() -> Path:
    env = os.environ.get("SMIDJA_FACTORY_DIR")
    return Path(env).expanduser().resolve() if env else FACTORY


def project_dir(explicit: str | None = None) -> Path:
    for value in (explicit, os.environ.get("SMIDJA_PROJECT_DIR")):
        if value:
            return Path(value).expanduser().resolve()
    cwd = Path.cwd()
    return _git_top(cwd) or cwd


def engine_dir(project: Path) -> tuple[Path | None, str]:
    """(engine, where it was found). The road is named so `doctor` can say it."""
    env = os.environ.get("SMIDJA_ENGINE_DIR")
    if env:
        p = Path(env).expanduser().resolve()
        return (p if _is_engine(p) else None), "SMIDJA_ENGINE_DIR"
    for rel, road in (("smidja", "project"), ("apps/smidja", "project")):
        if _is_engine(project / rel):
            return project / rel, road
    own = factory_dir() / "engine"
    if _is_engine(own):
        return own, "the installed smithy's own engine"
    beside = factory_dir().parent / "smidja"
    if _is_engine(beside):
        return beside, "beside the factory"
    return None, "missing"


def engine_root(engine: Path) -> Path:
    """The folder the config's relative paths are written from.

    A stamped project keeps the engine at `<root>/smidja`; Ymir's tree at
    `<root>/apps/smidja`. The config names `smidja/…` or `apps/smidja/…`
    accordingly, so the root is whichever parent makes those paths real.
    """
    if engine.parent.name == "apps":
        return engine.parent.parent
    return engine.parent


def config_path(engine: Path | None) -> Path | None:
    env = os.environ.get("SMIDJA_CONFIG")
    if env:
        return Path(env).expanduser().resolve()
    if engine is None:
        return None
    return engine / "smidja_smidja_config" / "smidja.config.yaml"


def db_path() -> tuple[Path, str]:
    for var in ("SMIDJA_DB", "CMD_DB"):
        if os.environ.get(var):
            return Path(os.environ[var]).expanduser(), var
    home = os.environ.get("YMIR_HOME") or str(Path.home() / "Documents" / "ymirhome")
    if Path(home).is_dir():
        return Path(home) / "smidja" / "smidja.db", "the Ymir home"
    state = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(state) / "smidja" / "smidja.db", "XDG state"


def data_dir() -> Path:
    return db_path()[0].parent


def kill_switch() -> Path:
    return data_dir() / ".smidja-emergency"


def viewer_url() -> str:
    url = os.environ.get("SMIDJA_VIEWER_URL")
    if url:
        return url.rstrip("/")
    return f"http://127.0.0.1:{os.environ.get('SMIDJA_VIZ_API_PORT', '8437')}"


def ymir_root() -> Path | None:
    """Ymir's tree, when this machine has one — used only to BORROW (the catalog,
    the MCP seating door), and every borrow says so."""
    for value in (os.environ.get("YMIR_ROOT"), os.environ.get("YMIR_RUNTIME_DIR")):
        if value and (Path(value) / "bin").is_dir():
            return Path(value)
    top = _git_top(factory_dir())
    if top and (top / "bin" / "model").is_dir():
        return top
    pin = Path.home() / "ymir-runtime"
    return pin if (pin / "bin").is_dir() else None


@dataclass
class Where:
    project: Path
    engine: Path | None
    engine_road: str
    root: Path | None
    config: Path | None
    db: Path
    db_road: str
    data: Path
    viewer: str
    notes: list[str] = field(default_factory=list)


def where(project: str | None = None) -> Where:
    proj = project_dir(project)
    engine, road = engine_dir(proj)
    db, db_road = db_path()
    return Where(project=proj, engine=engine, engine_road=road,
                 root=engine_root(engine) if engine else None,
                 config=config_path(engine), db=db, db_road=db_road,
                 data=db.parent, viewer=viewer_url())


def run_env(w: Where) -> dict[str, str]:
    """The environment a chain is launched with: the ONE db and data dir the
    viewer reads, so a run can never land in a second trace."""
    env = os.environ.copy()
    env["SMIDJA_DB"] = str(w.db)
    env["SMIDJA_DATA_DIR"] = str(w.data)
    env.setdefault("PYTHONUNBUFFERED", "1")
    return env
