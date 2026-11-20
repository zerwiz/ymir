#!/usr/bin/env python3
"""voices.py — every Kokoro voice this machine holds, by id and by name (plan 326.1–326.5).

The voices are read from the engine's own list (`kokoro voices --json`, which reads `voices-v1.0.bin`), never
from a table kept here, so a new voices file brings its voices with it. Each id carries its language and its
gender in the first two letters (Kokoro's convention: `am_eric` is American English, male, "eric").

    voices.py list [--json]                 every voice: id, name, language, gender, lang code
    voices.py resolve <name|id>             one voice id (`eric` -> `am_eric`); refuses an ambiguous name
    voices.py catalogue [--write <path>]    the YAML catalogue (stdout, or written atomically to <path>)
    voices.py say <name|id> [text] [--to <file>]
                                            speak a sample in that voice; with --to, write the file and play nothing
    voices.py choose <context> <name|id>    keep a voice for a context (default, rodd, snotra, person.<name>)
    voices.py set <context> <name|id>       the same as choose
    voices.py engine                        where the engine listens (the one value, plan 326.0) and whether it answers
    voices.py for <context>                 the voice id a context speaks in (context -> default -> the engine's)
    voices.py choices                       every kept choice

A choice is kept in the home (`$YMIR_HOME/config/voices.yaml`, or VOICES_CHOICES), one `context: id` line each, and
is checked against the pack when it is made: an unknown name is refused by name, never quietly replaced.

The engine already takes the voice with each request (`kokoro-serve` reads `voice` from the body and falls
back to its configured default), so the default stays a default and never becomes the only voice.

Exit: 0 ok · 1 the engine could not answer · 2 usage · 3 an unknown or ambiguous name · 4 the desk is held.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Kokoro's first letter is the language, the second the gender. The lang code is the engine's `--lang`.
LANGS = {
    "a": ("American English", "en-us"),
    "b": ("British English", "en-gb"),
    "e": ("Spanish", "es"),
    "f": ("French", "fr-fr"),
    "h": ("Hindi", "hi"),
    "i": ("Italian", "it"),
    "j": ("Japanese", "ja"),
    "p": ("Brazilian Portuguese", "pt-br"),
    "z": ("Mandarin Chinese", "cmn"),
}
GENDERS = {"f": "female", "m": "male"}
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import kokoro_url  # noqa: E402  the one value: where the engine listens


class VoiceError(Exception):
    def __init__(self, message: str, code: int):
        super().__init__(message)
        self.code = code


def kokoro_bin() -> str:
    found = os.environ.get("KOKORO_BIN") or shutil.which("kokoro") or str(Path.home() / ".local" / "bin" / "kokoro")
    if not (found and Path(found).exists()):
        raise VoiceError("the Kokoro engine is not installed here (no `kokoro` on PATH; set KOKORO_BIN)", 1)
    return found


def voice_ids() -> list[str]:
    fixture = os.environ.get("VOICES_FIXTURE")   # tests name the list; the engine is never needed to test the door
    if fixture:
        return json.loads(Path(fixture).read_text(encoding="utf-8"))["voices"]
    cached = catalogue_ids()
    if cached:
        return cached
    try:
        out = subprocess.run([kokoro_bin(), "voices", "--json"], capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise VoiceError(f"the Kokoro engine did not list its voices: {exc}", 1) from exc
    if out.returncode != 0:
        raise VoiceError(f"`kokoro voices` failed (rc {out.returncode}): {out.stderr.strip()[:200]}", 1)
    return json.loads(out.stdout)["voices"]


def pack_path() -> Path:
    return Path(os.environ.get("KOKORO_VOICES") or (Path.home() / ".local" / "share" / "kokoro" / "models" / "voices-v1.0.bin"))


def catalogue_ids() -> list[str]:
    """The generated catalogue in the home, when it is at least as new as the pack (the engine takes ~5 s to list).

    A pack newer than the catalogue means a new voices file: then the engine is asked, never the stale list."""
    if os.environ.get("VOICES_NO_CACHE") == "1":
        return []
    home = os.environ.get("YMIR_HOME")
    if not home:
        return []
    cat = Path(home) / "hodd" / "identity" / "voices.yaml"
    try:
        if not cat.is_file() or (pack_path().is_file() and pack_path().stat().st_mtime > cat.stat().st_mtime):
            return []
        ids = [ln.split(":", 1)[1].strip() for ln in cat.read_text(encoding="utf-8").splitlines()
               if ln.strip().startswith("- id:")]
    except OSError:
        return []
    return ids


def describe(vid: str) -> dict:
    prefix, _, name = vid.partition("_")
    lang, code = LANGS.get(prefix[:1], ("unknown", "en-us"))
    return {
        "id": vid,
        "name": name or vid,
        "language": lang,
        "lang": code,
        "gender": GENDERS.get(prefix[1:2], "unknown"),
    }


def catalogue() -> list[dict]:
    return [describe(v) for v in sorted(voice_ids())]


def resolve(wanted: str, rows: list[dict] | None = None) -> dict:
    rows = rows if rows is not None else catalogue()
    key = (wanted or "").strip().lower()
    if not key:
        raise VoiceError("name a voice: an id (am_eric) or a name (eric)", 2)
    exact = [r for r in rows if r["id"] == key]
    if exact:
        return exact[0]
    named = [r for r in rows if r["name"] == key]
    if len(named) == 1:
        return named[0]
    if len(named) > 1:
        ids = ", ".join(r["id"] for r in named)
        raise VoiceError(f"'{wanted}' names {len(named)} voices ({ids}) — say the id", 3)
    raise VoiceError(f"no voice named '{wanted}' — `voices.sh list` names all {len(rows)}", 3)


def render_yaml(rows: list[dict]) -> str:
    lines = [
        "# The Kokoro voices this machine holds — generated by bin/voice/voices.sh catalogue, never hand-edited.",
        "# Source: the engine's own list (voices-v1.0.bin). Regenerate after a new voices file.",
        f"count: {len(rows)}",
        "voices:",
    ]
    for r in rows:
        lines.append(f"  - id: {r['id']}")
        lines.append(f"    name: {r['name']}")
        lines.append(f"    language: {r['language']}")
        lines.append(f"    lang: {r['lang']}")
        lines.append(f"    gender: {r['gender']}")
    return "\n".join(lines) + "\n"


def write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix="." + path.name + ".", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


CONTEXT_OK = __import__("re").compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")


def choices_path() -> Path:
    named = os.environ.get("VOICES_CHOICES")
    if named:
        return Path(named)
    home = os.environ.get("YMIR_HOME") or str(Path.home() / "Documents" / "ymirhome")  # allow-home-default: the one home
    return Path(home) / "config" / "voices.yaml"


def read_choices() -> dict:
    p = choices_path()
    out: dict = {}
    if not p.is_file():
        return out
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if ":" not in line:
            continue
        k, _, v = line.partition(":")
        k, v = k.strip(), v.strip().strip("'\"")
        if k and v:
            out[k] = v
    return out


def engine_default() -> str:
    """The engine's own configured voice (Kokoro's config.json) — a default, never the only voice."""
    data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")  # the XDG data home
    cfg = Path(os.environ.get("KOKORO_CONFIG") or data / "kokoro" / "config.json")
    try:
        return str(json.loads(cfg.read_text(encoding="utf-8")).get("voice") or "")
    except (OSError, ValueError):
        return ""


def choose(context: str, wanted: str) -> dict:
    ctx = (context or "").strip().lower()
    if not CONTEXT_OK.match(ctx):
        raise VoiceError(f"'{context}' is not a context name — default, rodd, snotra, person.<name>", 2)
    voice = resolve(wanted)
    kept = read_choices()
    kept[ctx] = voice["id"]
    head = ["# The voice each context speaks in — written by bin/voice/voices.sh choose; ids come from the pack.",
            "# A context with no line here speaks in `default`, and `default` falls back to the engine's own voice."]
    write_atomic(choices_path(), "\n".join(head + [f"{k}: {v}" for k, v in sorted(kept.items())]) + "\n")
    return {"context": ctx, **voice}


def voice_for(context: str) -> dict:
    ctx = (context or "default").strip().lower()
    kept = read_choices()
    chain = [ctx]
    if ctx.startswith("person."):
        chain.append("person")
    chain.append("default")
    for c in chain:
        if c in kept:
            return {"context": ctx, "from": c, **resolve(kept[c])}
    eng = engine_default()
    if eng:
        return {"context": ctx, "from": "engine", **resolve(eng)}
    raise VoiceError(f"no voice is kept for '{ctx}' and the engine names no default — voices.sh choose default <voice>", 3)


def desk_holder() -> str:
    door = HERE.parent / "desk" / "in-call.sh"
    if not door.exists():
        return ""
    try:
        out = subprocess.run(["bash", str(door), "holder"], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return out.stdout.strip()


def engine_health(base: str) -> dict:
    import urllib.request
    try:
        with urllib.request.urlopen(base + "/health", timeout=3) as r:
            return json.loads(r.read().decode("utf-8") or "{}")
    except (OSError, ValueError):
        return {}


def engine() -> dict:
    base = kokoro_url.base()
    health = engine_health(base)
    return {"url": base, "port": kokoro_url.port(), "answers": bool(health.get("ready")),
            "variant": health.get("variant", "")}


def ensure_engine(base: str) -> None:
    """The engine is idle-lowered on purpose; raise it and wait for the socket, never for 'active'."""
    if engine_health(base).get("ready"):
        return
    if os.environ.get("VOICES_NO_RAISE") != "1":
        subprocess.run(["systemctl", "--user", "start", "kokoro-serve.service"], capture_output=True, timeout=120)
    import time
    for _ in range(60):
        if engine_health(base).get("ready"):
            return
        time.sleep(1)
    raise VoiceError(f"the Kokoro engine does not answer at {base} — systemctl --user start kokoro-serve", 1)


def say(wanted: str, text: str, to: str | None) -> dict:
    voice = resolve(wanted)
    if not to:
        held = desk_holder()
        if held:
            raise VoiceError(f"the desk is held ({held}) — no sound now; write it with --to <file> instead", 4)
    text = text or f"This is {voice['name']}, one of the house's voices."
    base = kokoro_url.base()
    ensure_engine(base)
    # the resident engine at the one URL, never a cold embedded model behind the house's back
    cmd = [kokoro_bin(), "speak", text, "-v", voice["id"], "--lang", voice["lang"],
           "--service", "required", "--service-url", base]
    target = Path(to) if to else None
    if target:
        cmd += ["-o", str(target)]
    else:
        cmd += ["--play"]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    if out.returncode != 0:
        raise VoiceError(f"`kokoro speak` failed (rc {out.returncode}): {out.stderr.strip()[:200]}", 1)
    result = dict(voice)
    result["said"] = text
    result["engine"] = base
    if target:
        result["file"] = str(target)
        result["bytes"] = target.stat().st_size if target.exists() else 0
    return result


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if argv else 2
    verb, rest = argv[0], argv[1:]
    try:
        if verb == "list":
            rows = catalogue()
            if "--json" in rest:
                print(json.dumps({"count": len(rows), "voices": rows}, ensure_ascii=False))
            else:
                print(f"voices[{len(rows)}]{{id,name,language,gender,lang}}:")
                for r in rows:
                    print(f'  "{r["id"]}","{r["name"]}","{r["language"]}","{r["gender"]}","{r["lang"]}"')
            return 0
        if verb == "resolve":
            if not rest:
                raise VoiceError("usage: voices.sh resolve <name|id>", 2)
            print(resolve(rest[0])["id"])
            return 0
        if verb == "catalogue":
            text = render_yaml(catalogue())
            if "--write" in rest:
                i = rest.index("--write")
                if i + 1 >= len(rest):
                    raise VoiceError("usage: voices.sh catalogue --write <path>", 2)
                write_atomic(Path(rest[i + 1]), text)
                print(f"catalogue: {text.splitlines()[2]} written to {rest[i + 1]}")
            else:
                sys.stdout.write(text)
            return 0
        if verb == "say":
            to = None
            if "--to" in rest:
                i = rest.index("--to")
                if i + 1 >= len(rest):
                    raise VoiceError("usage: voices.sh say <name|id> [text] [--to <file>]", 2)
                to = rest[i + 1]
                rest = rest[:i] + rest[i + 2:]
            if not rest:
                raise VoiceError("usage: voices.sh say <name|id> [text] [--to <file>]", 2)
            print(json.dumps(say(rest[0], " ".join(rest[1:]), to), ensure_ascii=False))
            return 0
        if verb == "engine":
            print(json.dumps(engine(), ensure_ascii=False))
            return 0
        if verb in ("choose", "set"):
            if len(rest) < 2:
                raise VoiceError("usage: voices.sh choose <context> <name|id>", 2)
            print(json.dumps(choose(rest[0], rest[1]), ensure_ascii=False))
            return 0
        if verb == "for":
            print(voice_for(rest[0] if rest else "default")["id"])
            return 0
        if verb == "choices":
            for k, v in sorted(read_choices().items()):
                print(f"{k}: {v}")
            return 0
        raise VoiceError(f"unknown verb '{verb}' — list · resolve · catalogue · say · choose|set · for · choices · engine", 2)
    except VoiceError as exc:
        print(f"voices: {exc}", file=sys.stderr)
        return exc.code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
