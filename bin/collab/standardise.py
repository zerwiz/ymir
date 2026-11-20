#!/usr/bin/env python3
"""standardise.py — put the collaboration kit into a repository, upgrade an older one, or say what is missing.

  standardise.sh --check <repo> [--profile P] [--register plain|house] [--languages en:sv,de]
  standardise.sh --apply <repo> [same options]
  standardise.sh --uninstall <repo>          # put the hooks back as they were; files stay

What it decides for each file the kit carries:
  missing   not in the repository                                    → installed by --apply
  same      byte for byte the kit's                                  → nothing
  older     a version an earlier kit shipped, never changed locally  → upgraded by --apply
  local     changed by the repository for itself                     → reported, never replaced
A renamed piece whose old copy is unchanged is moved; a changed old copy is kept and the new one is not installed.

project.yaml is rendered from a stack profile when missing and never replaced when present. The hooks are seated
by the kit's chaining installer: the repository's own hooks keep running after the kit's. Idempotent.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
KIT = HERE / "kit"
VERSION = "2.0.0"
PROFILES = HERE / "profiles"
REGISTERS = HERE / "registers"
HOUSE_NAMES = {"worktrees": ".yggdrasil", "branch_prefix": "yggdrasil"}
PLAIN_NAMES = {"worktrees": ".worktrees", "branch_prefix": "work"}
RENAMED = {  # new path -> old path
    ".agents/skills/the-workbench/SKILL.md": ".agents/skills/smidr-the-workbench/SKILL.md",
    ".agents/skills/the-workbench/assets/why-small.md": ".agents/skills/smidr-the-workbench/assets/why-small.md",
    "scripts/notify.sh": "scripts/notify-arm.sh",
    "docs/templates/project/architecture.md": "docs/templates/house/architecture.md",
    "docs/templates/project/plan.md": "docs/templates/house/plan.md",
    "docs/templates/project/research.md": "docs/templates/house/research.md",
    "docs/templates/project/rule.md": "docs/templates/house/rule.md",
}
CLIENT_PATHS_DEFAULT = {
    "monorepo-bun-uv-mix": '"ui/**/words.*.json", "ui/**/i18n/**", "web/**/i18n/**", "server/**/templates/mail/**", "library/**", ".agents/skills/swedish-*/**"',
    "elixir-umbrella": '"apps/*/priv/gettext/**", "apps/*/lib/**/templates/**", "assets/**/i18n/**"',
}
# the words of one team's own naming that must never reach a plain repository
HOUSE_WORDS = re.compile(r"\b(Ymir|Yggdrasil|Allfather|batons?|Vingólf|Smíðr|Gimlé|Snotra|Eindri|Hœnir|Brokk|Bragi|"
                         r"Galdr|Sága|Mímir|Bifrost|Utgard|ymirhome)\b|\bthe house\b|\.yggdrasil\b", re.IGNORECASE)
PLAIN_EXCEPTIONS = {  # a file shared byte for byte with the maintainers' own guard; it names env keys, not people
    "scripts/gates/maker-names.py": "the maker matcher is one file shared with its maintainers' guard (byte-identical test)",
}


def blob(data: bytes) -> str:
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def history() -> dict[str, set[str]]:
    out: dict[str, set[str]] = {}
    f = HERE / "kit-history.tsv"
    if f.is_file():
        for line in f.read_text().splitlines():
            if line.startswith("#") or "\t" not in line:
                continue
            p, b = line.split("\t", 1)
            out.setdefault(p, set()).add(b.strip())
    return out


def kit_files() -> list[str]:
    files = []
    for p in sorted(KIT.rglob("*")):
        if not p.is_file() or "__pycache__" in p.parts:
            continue
        rel = p.relative_to(KIT).as_posix()
        if p.name == "README.md" and not rel.startswith("plans/tickets/"):
            continue
        files.append(rel)
    return files


def house_map() -> list[tuple[str, str]]:
    pairs = []
    for line in (REGISTERS / "house.tsv").read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or "\t" not in line:
            continue
        a, b = line.split("\t", 1)
        pairs.append((a, b))
    return pairs


def render(rel: str, data: bytes, register: str) -> bytes:
    if register != "house" or not rel.endswith(".md"):
        return data
    text = data.decode("utf-8")
    for a, b in house_map():
        text = text.replace(a, b)
    return text.encode("utf-8")


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], text=True, capture_output=True)


def detect_profile(repo: Path) -> str:
    has = lambda p: (repo / p).exists()  # noqa: E731
    if has("mix.exs") and has("apps"):
        return "elixir-umbrella"
    if has("web/package.json") and (has("server/pyproject.toml") or has("base/pyproject.toml")):
        return "monorepo-bun-uv-mix"
    if has("mix.exs"):
        return "elixir"
    if has("pyproject.toml") and not has("package.json"):
        return "python"
    if has("package.json"):
        return "node"
    return "monorepo"


def render_project(repo: Path, profile: str, register: str, langs: str) -> str:
    text = (PROFILES / f"{profile}.yaml").read_text(encoding="utf-8")
    project, *client = [x for x in re.split(r"[:,]", langs) if x] or ["en"]
    names = HOUSE_NAMES if register == "house" else PLAIN_NAMES
    main = Path(git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir").stdout.strip()).parent
    values = {"kit": VERSION, "project": main.name, "register": register, "worktrees": names["worktrees"],
              "branch_prefix": names["branch_prefix"], "lang_project": project, "lang_client": ", ".join(client),
              "client_paths": CLIENT_PATHS_DEFAULT.get(profile, "") if client else ""}
    for k, v in values.items():
        text = text.replace("{{" + k + "}}", v)
    return text


def plain_findings(repo: Path, rels: list[str]) -> list[str]:
    out = []
    for rel in rels:
        if rel in PLAIN_EXCEPTIONS:
            continue
        p = repo / rel
        if not p.is_file() or p.suffix in (".png", ".jpg", ".pdf"):
            continue
        try:
            for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
                if HOUSE_WORDS.search(line):
                    out.append(f"{rel}:{n}: {line.strip()[:90]}")
        except UnicodeDecodeError:
            continue
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="standardise.sh")
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--uninstall", action="store_true")
    ap.add_argument("repo")
    ap.add_argument("--profile", choices=sorted(p.stem for p in PROFILES.glob("*.yaml")))
    ap.add_argument("--register", choices=["plain", "house"])
    ap.add_argument("--languages", default=None, help="project:client,client — e.g. en:sv")
    a = ap.parse_args(argv)
    repo = Path(a.repo).resolve()
    if not (repo / ".git").exists():
        print(f"not a git repository: {repo}", file=sys.stderr)
        return 2

    if a.uninstall:
        if not (repo / "scripts" / "kit.py").is_file():
            print("no kit.py in this repository — nothing to uninstall")
            return 1
        return subprocess.run([sys.executable, str(repo / "scripts" / "kit.py"), "--repo", str(repo), "hooks", "uninstall"]).returncode

    hist = history()
    existing_cfg = repo / "project.yaml"
    register = a.register
    if not register and existing_cfg.is_file():
        m = re.search(r"^register:\s*(\w+)", existing_cfg.read_text(), re.M)
        register = m.group(1) if m else "plain"
    register = register or "plain"
    profile = a.profile or detect_profile(repo)
    langs = a.languages or "en"

    rows = {"missing": [], "same": [], "older": [], "local": [], "renamed": [], "kept-old-name": []}
    plan: dict[str, bytes] = {}
    for rel in kit_files():
        data = render(rel, (KIT / rel).read_bytes(), register)
        target = repo / rel
        old = RENAMED.get(rel)
        if not target.exists() and old and (repo / old).exists():
            ob = blob((repo / old).read_bytes())
            if ob in hist.get(old, set()):
                rows["renamed"].append(f"{old} -> {rel}")
                plan[rel] = data
            else:
                rows["kept-old-name"].append(f"{old} (changed locally; {rel} not installed)")
            continue
        if not target.exists():
            rows["missing"].append(rel)
            plan[rel] = data
        elif target.read_bytes() == data:
            rows["same"].append(rel)
        elif blob(target.read_bytes()) in hist.get(rel, set()) or blob(target.read_bytes()) in _manifest_blobs(repo, rel):
            rows["older"].append(rel)
            plan[rel] = data
        else:
            rows["local"].append(rel)

    print(f"[{repo}] kit {VERSION} · register {register} · profile {profile}" + ("" if a.profile else " (detected)"))
    for k, label in [("same", "present"), ("missing", "missing"), ("older", "older kit files (upgraded by --apply)"),
                     ("renamed", "renamed pieces (moved by --apply)"),
                     ("local", "local (a local rule wins; it is reported, never replaced)"),
                     ("kept-old-name", "kept under the old name")]:
        print(f"  {label}: {len(rows[k])}")
        if k != "same":
            for r in rows[k]:
                print(f"    {r}")
    print(f"  project.yaml: {'present — kept as the repository wrote it' if existing_cfg.is_file() else 'missing — rendered from profile ' + profile + ' by --apply'}")
    hp = git(repo, "config", "--get", "core.hooksPath").stdout.strip()
    print(f"  hooks: core.hooksPath = {hp or '(unset)'}" + ("" if hp == ".githooks" else " — --apply seats .githooks and chains what was there"))

    dead = []
    for hook in sorted((repo / ".githooks").glob("*")) if (repo / ".githooks").is_dir() else []:
        lines = hook.read_text(errors="replace").splitlines() if hook.is_file() else []
        first = next((i for i, l in enumerate(lines) if re.match(r"^\s*exit 0", l)), None)
        if first is not None and any(re.match(r"^\s*(bash|npm|sh) ", l) for l in lines[first + 1:]):
            dead.append(hook.name)
    if dead:
        print(f"  DEAD GATES (a check written after an exit 0 — it never runs): {' '.join(dead)}")

    if a.check:
        if register == "plain":
            found = plain_findings(repo, [r for r in kit_files() if (repo / r).exists()])
            print(f"  plain register: {len(found)} line(s) of another register's naming in installed kit files")
            for f in found[:10]:
                print(f"    {f}")
        return 0

    # ---- apply -------------------------------------------------------------------------------------------
    for rel, data in plan.items():
        dst = repo / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes(data)
        src_mode = (KIT / rel).stat().st_mode
        if src_mode & 0o111:
            dst.chmod(dst.stat().st_mode | 0o755)
    for r in rows["renamed"]:
        old = r.split(" -> ")[0]
        (repo / old).unlink(missing_ok=True)
        d = (repo / old).parent
        while d != repo and d.is_dir() and not any(d.iterdir()):
            d.rmdir()
            d = d.parent
    if not existing_cfg.is_file():
        existing_cfg.write_text(render_project(repo, profile, register, langs), encoding="utf-8")
        print(f"  wrote project.yaml (profile {profile}, register {register}, languages {langs})")
    # the worktree folder is never committed
    wtdir = HOUSE_NAMES["worktrees"] if register == "house" else PLAIN_NAMES["worktrees"]
    sys.path.insert(0, str(KIT / "scripts"))
    from kitlib import miniyaml  # noqa: E402
    wtdir = ((miniyaml.load(str(existing_cfg)) or {}).get("names") or {}).get("worktrees") or wtdir
    if git(repo, "check-ignore", "-q", f"{wtdir}/x").returncode != 0:
        gi = repo / ".gitignore"
        text = gi.read_text() if gi.is_file() else ""
        gi.write_text(text + ("" if text.endswith("\n") or not text else "\n") +
                      f"\n# worktrees: one task, one checkout — never committed (collaboration kit, RULES/17)\n/{wtdir}/\n")
        print(f"  appended /{wtdir}/ to .gitignore")
    r = subprocess.run([sys.executable, str(repo / "scripts" / "kit.py"), "--repo", str(repo), "hooks", "install"],
                       text=True, capture_output=True)
    for line in (r.stdout + r.stderr).splitlines():
        print(f"  {line}")
    manifest = {"kit": VERSION, "applied": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "register": register,
                "profile": profile, "files": len(kit_files()), "installed_this_run": len(rows["missing"]),
                "upgraded_this_run": len(rows["older"]) + len(rows["renamed"]), "local": rows["local"],
                "blobs": {rel: blob((repo / rel).read_bytes()) for rel in kit_files() if (repo / rel).is_file()}}
    (repo / ".collab-kit.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"  applied: {len(rows['missing'])} installed, {len(rows['older'])} upgraded, {len(rows['renamed'])} renamed, "
          f"{len(rows['local'])} local kept")
    if register == "plain":
        found = plain_findings(repo, kit_files())
        print(f"  plain register: {len(found)} line(s) of another register's naming in installed kit files")
        for f in found[:10]:
            print(f"    {f}")
    if not (repo / "handoff" / "CURRENT.md").exists():
        print("  note: no handoff/CURRENT.md — `bin/collab/collab.sh init <repo>` installs the handoff shelf")
    return 0


def _manifest_blobs(repo: Path, rel: str) -> set[str]:
    f = repo / ".collab-kit.json"
    try:
        b = json.loads(f.read_text()).get("blobs", {}).get(rel)
        return {b} if b else set()
    except (OSError, ValueError):
        return set()


if __name__ == "__main__":
    sys.exit(main())
