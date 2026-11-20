"""languages — the project's tongue for the work; a client's tongue only where a client reads it.

project.yaml:
  languages:
    project: en            # code, identifiers, comments, commits, pull requests, documents
    client: [sv]           # what a client reads or hears
    client_paths: ["ui/**/words.*.json", "templates/mail/**"]
    files: report          # report | refuse — another tongue in a staged file outside client_paths

A commit message in another tongue is always refused. `language.allow` (repository root) declares the
legal exceptions, one per line: `<glob> | <class> | <reason>` with class fixture · detector · quotation ·
table · specimen. A line with no reason is itself a finding.

What it cannot see, stated so nobody assumes it does: one foreign word inside an English sentence, a
transliteration, or whether a translation is faithful. It raises the floor; the rule is the standard.
"""
from __future__ import annotations

import fnmatch
import re
import subprocess
from pathlib import Path

# the function words and letters that mark a tongue; a line is judged only when it reads like prose
TONGUES = {
    "en": ("", "the and is of to in that it for with on this are be not you we was have from by"),
    "sv": ("åäö", "och att det är inte för med som på en ett jag vi du har kan ska till av om men eller den detta här nu så också bara från vara blir finns"),
    "de": ("äöüß", "und nicht der die das ist mit ein eine zu auf für sich auch werden ich wir sie wird oder aber dass nach bei"),
    "fr": ("àâçéèêëîïôûùœ", "le la les et est une des pour pas que qui dans avec sur nous vous il elle ce sont mais ou du au"),
    "es": ("ñáéíóú¿¡", "el los las y es una para con por que del como pero está son muy más su al lo"),
    "fi": ("äö", "ja on ei se että kun mutta tai olen ovat tämä hän me te ne jos niin myös"),
    "nl": ("", "het een niet van en dat zijn voor met ook maar wordt naar bij deze worden ik je we"),
    "da": ("æøå", "og ikke det er jeg til på med som har en af men kan skal også være der"),
    "no": ("æøå", "og ikke det er jeg til på med som har en av men kan skal også være der"),
}
_WORDS = {k: set(v[1].split()) for k, v in TONGUES.items()}
_TOKEN = re.compile(r"[^\W\d_]+", re.UNICODE)
_CODE = re.compile(r"[{};=<>]|::|=>|->|\(\)")


def tongue_of(line: str, prose_only: bool = True) -> str | None:
    """The tongue a line is written in, when it is clearly not unknown; None for code, names or short lines."""
    if prose_only and _CODE.search(line):
        return None
    words = [w.lower() for w in _TOKEN.findall(line)]
    if len(words) < 3:
        return None
    scores = {}
    for k, (letters, _) in TONGUES.items():
        hits = sum(1 for w in words if w in _WORDS[k])
        marks = len({c for c in line.lower() if c in letters}) if letters else 0
        scores[k] = hits + 2 * marks
    best = max(scores, key=lambda k: scores[k])
    if best == "en" or scores[best] < 3 or scores[best] <= scores["en"]:
        return None
    return best


# the detector itself carries the words it recognises: matching data, not prose (class: detector)
_SELF = ["scripts/kitlib/languages.py", "bin/collab/kit/scripts/kitlib/languages.py"]


def _allowed(root: Path) -> tuple[list[str], list[str]]:
    globs, faults = list(_SELF), []
    f = root / "language.allow"
    if f.is_file():
        for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = [p.strip() for p in line.split("|")]
            if len(parts) < 3 or not parts[2]:
                faults.append(f"language.allow line {n}: an exception needs a class and a reason")
                continue
            globs.append(parts[0])
    return globs, faults


def _match(path: str, globs: list[str]) -> bool:
    for g in globs:
        if fnmatch.fnmatch(path, g) or fnmatch.fnmatch(path, g.replace("**/", "")):
            return True
    return False


def check_message(cfg, text: str) -> list[str]:
    project = cfg["languages"]["project"]
    out = []
    for n, line in enumerate(text.splitlines(), 1):
        s = line.strip()
        if not s or s.startswith("#") or s.startswith(">"):
            continue  # git's comments, and a quotation kept as it was said
        t = tongue_of(s, prose_only=False)
        if t and t != project:
            out.append(f"line {n} reads as '{t}', and commits are written in '{project}': {s[:80]}")
    return out


def check_lines(cfg, root: Path, items: list[tuple[str, int, str]]) -> tuple[list[str], list[str]]:
    """items: (path, line number, text). Returns (findings, faults)."""
    project = cfg["languages"]["project"]
    client = set(cfg["languages"].get("client") or [])
    client_paths = cfg["languages"].get("client_paths") or []
    allow, faults = _allowed(root)
    findings = []
    for path, n, text in items:
        if _match(path, allow):
            continue
        t = tongue_of(text)
        if not t or t == project:
            continue
        if t in client and _match(path, client_paths):
            continue
        where = "a client tongue outside the client paths" if t in client else "a tongue this project does not use"
        findings.append(f"{path}:{n} reads as '{t}' — {where}: {text.strip()[:80]}")
    return findings, faults


def staged_lines(root: Path) -> list[tuple[str, int, str]]:
    r = subprocess.run(["git", "diff", "--cached", "-U0", "--diff-filter=AM", "--no-color"], cwd=str(root),
                       text=True, capture_output=True, errors="replace")
    items, path, n = [], None, 0
    for line in r.stdout.splitlines():
        if line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else None
        elif line.startswith("@@"):
            m = re.search(r"\+(\d+)", line)
            n = int(m.group(1)) if m else 0
        elif line.startswith("+") and path:
            items.append((path, n, line[1:]))
            n += 1
    return items
