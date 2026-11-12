#!/usr/bin/env python3
"""house-colour-guard.py — the engine behind house-colour-guard.sh (RULES/54).

The house wears stone, bone, bronze, steel and blood (midgard/design-system/tokens.css).
Blue and purple are not in the cloth. This engine reads text files and names every colour
whose HUE falls in the cool band:

  hue 185°–330°, HSL saturation >= 15 %, lightness between 6 % and 94 %

so steel (#96a0a8, saturation 9 %) passes, a navy ground (#0b1220) does not, and pure grey,
near-black and near-white are never judged. It reads four spellings of a colour:

  hex        #36f · #3366ff · #3366ffcc. An all-digit short hex ("#636", "#4568") is
             usually an issue number, so it is judged only in a stylesheet or on a line
             that speaks of colour.
  functions  rgb() / rgba() / hsl() / hsla(), with commas or spaces, numbers or percentages.
  tailwind   a class in the blue, indigo, violet, purple, sky or fuchsia families (bg-sky-500).
  css names  blue, navy, indigo, purple, violet, magenta … after a colour property.

Paths named in house-colour.allow (repo root) are HELD or SPECIMENS: a finding there is
printed, counted, and never fails. Everything else fails.

THE MAP. `--map COLOUR` prints the house colour a cool colour becomes, and `--fix FILE…`
rewrites the cool colours in those files (alpha kept, spelling kept). The map never lands on
another cool colour:

  dark (lightness < 20 %)          -> the stone ladder   #0e0c09 #151209 #1a1610 #221d14 #2b241a
  greyish (saturation < 35 %)      -> the bone ladder    #2b241a #6b6250 #9a8f75 #cfc3a9 #f0e6cd
  blue, sky, indigo (185°–250°)    -> the bronze ramp    #57411a #7d5f2a #c9973f #eca654 #f0e6cd
  violet, purple (250°–290°)       -> the steel ramp     #2b241a #5f686e #96a0a8 #cfc3a9 #f0e6cd
  fuchsia, magenta (290°–330°)     -> the blood ramp     #7c3a30 #c2584a #cfc3a9 #f0e6cd

and the nearest step by lightness is taken. Tailwind: blue/sky/indigo -> amber, violet/purple
-> stone, fuchsia -> red, shade kept.

Usage: house-colour-guard.py check ROOT [file ...]   (no files: every tracked text file)
       house-colour-guard.py --map COLOUR
       house-colour-guard.py --fix ROOT file ...
Exit:  0 clean · 1 a finding outside the allow list · 2 usage
"""
import colorsys
import fnmatch
import os
import re
import subprocess
import sys

HUE_LO, HUE_HI = 185.0, 330.0
SAT_MIN = 0.15
L_MIN, L_MAX = 0.06, 0.94

SKIP_EXT = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".icns", ".pdf", ".woff", ".woff2",
    ".ttf", ".otf", ".eot", ".mp3", ".mp4", ".wav", ".ogg", ".webm", ".zip", ".gz", ".tgz",
    ".gguf", ".onnx", ".bin", ".so", ".dylib", ".exe", ".dll", ".lock",
}
SKIP_NAMES = {"package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lockb", "Cargo.lock"}
STYLE_EXT = {".css", ".scss", ".less", ".svg"}

HEX_RE = re.compile(r"(?<![\w&/#.%{$-])#([0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{4}|[0-9a-fA-F]{3})(?![\w-])")
FUNC_RE = re.compile(r"\b(rgba?|hsla?)\(\s*([^()]{3,80}?)\)", re.I)
TW_RE = re.compile(r"(?<![\w-])((?:[a-z0-9-]+:)*[a-z-]*-?)(blue|indigo|violet|purple|sky|fuchsia)-(50|[1-9]00|950)((?:/\d+)?)(?![\w-])")
COLOUR_WORD = re.compile(r"\b(?:colou?rs?|fill|stroke|background(?:-color)?|bg|border(?:-color)?|accent|palette|tint|gradient)\b", re.I)

NAMED = {
    # cool CSS names -> the house colour they become
    "blue": "#c9973f", "mediumblue": "#c9973f", "royalblue": "#c9973f", "dodgerblue": "#c9973f",
    "deepskyblue": "#c9973f", "cornflowerblue": "#c9973f", "steelblue": "#7d5f2a",
    "cadetblue": "#7d5f2a", "darkturquoise": "#c9973f",
    "darkblue": "#1a1610", "navy": "#151209", "midnightblue": "#151209",
    "indigo": "#5f686e", "darkslateblue": "#5f686e", "slateblue": "#96a0a8",
    "mediumslateblue": "#96a0a8", "mediumpurple": "#96a0a8", "blueviolet": "#96a0a8",
    "purple": "#5f686e", "rebeccapurple": "#5f686e", "darkviolet": "#5f686e",
    "violet": "#96a0a8", "darkorchid": "#7c3a30", "orchid": "#c2584a", "mediumorchid": "#c2584a",
    "magenta": "#c2584a", "fuchsia": "#c2584a", "darkmagenta": "#7c3a30",
    "lightblue": "#cfc3a9", "skyblue": "#cfc3a9", "lightskyblue": "#cfc3a9",
    "powderblue": "#cfc3a9", "lavender": "#f0e6cd", "plum": "#cfc3a9", "thistle": "#cfc3a9",
}
NAME_RE = re.compile(
    r"((?<![\w-])(?:color|background(?:-color)?|fill|stroke|border(?:-[a-z]+)?-color|outline-color|"
    r"stop-color|accent-color|caret-color)\s*[:=]\s*[\"']?|(?<![\w-])(?:fill|stroke)=[\"'])"
    r"(" + "|".join(sorted(NAMED, key=len, reverse=True)) + r")\b",
    re.I,
)
TW_FAMILY = {"blue": "amber", "sky": "amber", "indigo": "amber", "violet": "stone",
             "purple": "stone", "fuchsia": "red"}

# Each ramp step carries the lightness it ANSWERS for (not its own measured lightness), so a
# mid blue lands on the primary bronze rather than on the ember one shade brighter.
STONE = [("#0e0c09", 0.04), ("#151209", 0.07), ("#1a1610", 0.10), ("#221d14", 0.13), ("#2b241a", 0.17)]
BONE = [("#2b241a", 0.20), ("#6b6250", 0.38), ("#9a8f75", 0.58), ("#cfc3a9", 0.78), ("#f0e6cd", 0.90)]
BRONZE = [("#57411a", 0.22), ("#7d5f2a", 0.36), ("#c9973f", 0.55), ("#eca654", 0.72), ("#f0e6cd", 0.86)]
STEEL = [("#2b241a", 0.20), ("#5f686e", 0.38), ("#96a0a8", 0.58), ("#cfc3a9", 0.78), ("#f0e6cd", 0.90)]
BLOOD = [("#7c3a30", 0.33), ("#c2584a", 0.58), ("#cfc3a9", 0.80), ("#f0e6cd", 0.90)]


def _rgb(hx):
    hx = hx.lstrip("#")
    return tuple(int(hx[i:i + 2], 16) for i in (0, 2, 4))


def house_for(r, g, b):
    """The house colour (as #rrggbb) a cool sRGB triple (0..255) becomes."""
    h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
    hue = h * 360.0
    if l < 0.20:
        ramp = STONE
    elif s < 0.35:
        ramp = BONE
    elif hue < 250:
        ramp = BRONZE
    elif hue < 290:
        ramp = STEEL
    else:
        ramp = BLOOD
    return min(ramp, key=lambda step: abs(step[1] - l))[0]


def is_cool_hsl(h, s, l):
    if l < L_MIN or l > L_MAX or s < SAT_MIN:
        return False
    return HUE_LO <= (h % 360.0) <= HUE_HI


def cool(r, g, b):
    h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
    return is_cool_hsl(h * 360.0, s, l)


def _hex_rgb(hx):
    if len(hx) in (3, 4):
        hx = "".join(c * 2 for c in hx)
    return _rgb(hx[:6]), (hx[6:8] if len(hx) == 8 else "")


def _num(tok, scale):
    tok = tok.strip()
    if tok.endswith("%"):
        return float(tok[:-1]) / 100.0 * 255.0 if scale == 255.0 else float(tok[:-1]) / 100.0
    return float(tok) * (1.0 if scale == 255.0 else 1.0 / scale)


def _func_rgb(kind, args):
    """(r,g,b) 0..255 and the alpha token (or None) of an rgb()/hsl() argument string."""
    if "$" in args or "var(" in args or "{" in args:
        return None
    alpha = None
    if "/" in args:
        args, alpha = args.split("/", 1)
        alpha = alpha.strip()
    parts = [p for p in re.split(r"[\s,]+", args.strip()) if p]
    if len(parts) == 4 and alpha is None:
        alpha = parts[3]
    if len(parts) < 3:
        return None
    try:
        if kind.lower().startswith("rgb"):
            rgb = tuple(_num(p, 255.0) for p in parts[:3])
            if max(rgb) > 255.01 or min(rgb) < 0:
                return None
        else:
            hue = float(parts[0].lower().replace("deg", ""))
            s = float(parts[1].rstrip("%")) / 100.0
            l = float(parts[2].rstrip("%")) / 100.0
            rr, gg, bb = colorsys.hls_to_rgb((hue % 360.0) / 360.0, l, s)
            rgb = (rr * 255.0, gg * 255.0, bb * 255.0)
    except ValueError:
        return None
    return tuple(int(round(c)) for c in rgb), alpha


def findings(line, style=False):
    """Every cool colour on a line: (start, end, text, replacement)."""
    out = []
    for m in HEX_RE.finditer(line):
        hx = m.group(1)
        if hx.isdigit() and len(hx) in (3, 4) and not style:
            # An all-digit short hex is usually an issue or PR number ("#636", "#4568"). Outside
            # a stylesheet it is judged only as a value — after ':' or '=' — on a line that
            # speaks of colour.
            lead = line[:m.start()].rstrip().rstrip("\"'").rstrip()
            if not (lead.endswith((":", "=")) and COLOUR_WORD.search(line)):
                continue
        rgb, alpha = _hex_rgb(hx)
        if not cool(*rgb):
            continue
        new = house_for(*rgb)
        if len(hx) == 4:
            alpha = hx[3] * 2
        new = new + alpha
        if hx.upper() == hx and any(c.isalpha() for c in hx):
            new = new.upper()
        out.append((m.start(), m.end(), m.group(0), new))
    for m in FUNC_RE.finditer(line):
        got = _func_rgb(m.group(1), m.group(2))
        if not got:
            continue
        rgb, alpha = got
        if not cool(*rgb):
            continue
        r, g, b = _rgb(house_for(*rgb))
        if alpha is not None:
            new = "rgba(%d, %d, %d, %s)" % (r, g, b, alpha)
        else:
            new = "rgb(%d, %d, %d)" % (r, g, b)
        out.append((m.start(), m.end(), m.group(0), new))
    for m in TW_RE.finditer(line):
        new = m.group(1) + TW_FAMILY[m.group(2)] + "-" + m.group(3) + m.group(4)
        out.append((m.start(), m.end(), m.group(0), new))
    for m in NAME_RE.finditer(line):
        out.append((m.start(2), m.end(2), m.group(2), NAMED[m.group(2).lower()]))
    return out


def load_allow(root):
    """[(glob, class, reason)] from house-colour.allow ('path | class | reason' lines)."""
    rules = []
    try:
        with open(os.path.join(root, "house-colour.allow"), encoding="utf-8") as fh:
            for raw in fh:
                raw = raw.strip()
                if not raw or raw.startswith("#"):
                    continue
                bits = [b.strip() for b in raw.split("|", 2)]
                if len(bits) == 3 and bits[1] in ("held", "fixture", "specimen"):
                    rules.append((bits[0], bits[1], bits[2]))
    except OSError:
        pass
    return rules


def _match(rel, glob):
    g = glob.rstrip("/")
    if g.endswith("/**"):
        return rel.startswith(g[:-3] + "/")
    return rel == g or fnmatch.fnmatch(rel, g)


def allowed(rel, rules):
    for glob, kind, reason in rules:
        if _match(rel, glob):
            return kind, reason
    return None


def tracked(root):
    try:
        out = subprocess.run(["git", "-C", root, "ls-files", "-z"], capture_output=True, check=True)
        return [p for p in out.stdout.decode("utf-8", "replace").split("\0") if p]
    except (OSError, subprocess.CalledProcessError):
        files = []
        for d, dirs, fs in os.walk(root):
            dirs[:] = [x for x in dirs if x not in (".git", "node_modules")]
            files += [os.path.relpath(os.path.join(d, f), root) for f in fs]
        return files


def read_text(root, rel):
    name = os.path.basename(rel)
    if name in SKIP_NAMES or os.path.splitext(name)[1].lower() in SKIP_EXT:
        return None
    full = os.path.join(root, rel)
    if not os.path.isfile(full) or os.path.islink(full):
        return None
    try:
        with open(full, "rb") as fh:
            data = fh.read()
    except OSError:
        return None
    if b"\0" in data[:8192] or len(data) > 4_000_000:
        return None
    return data.decode("utf-8", "replace")


def scan(root, files):
    rules = load_allow(root)
    hard, soft = [], {}
    for rel in files:
        rel = rel.strip()
        if not rel:
            continue
        text = read_text(root, rel)
        if text is None:
            continue
        verdict = allowed(rel, rules)
        style = os.path.splitext(rel)[1].lower() in STYLE_EXT
        for n, line in enumerate(text.splitlines(), 1):
            for _s, _e, colour, new in findings(line[:4000], style):
                if verdict:
                    key = (verdict[0], rel, verdict[1])
                    soft[key] = soft.get(key, 0) + 1
                else:
                    hard.append((rel, n, colour, new))
    return hard, soft


def fix(root, files):
    changed = 0
    for rel in files:
        text = read_text(root, rel)
        if text is None:
            continue
        style = os.path.splitext(rel)[1].lower() in STYLE_EXT
        lines = text.split("\n")
        for i, line in enumerate(lines):
            if len(line) > 4000:
                continue
            for s, e, _old, new in sorted(findings(line, style), reverse=True):
                line = line[:s] + new + line[e:]
                changed += 1
            lines[i] = line
        new_text = "\n".join(lines)
        if new_text != text:
            with open(os.path.join(root, rel), "w", encoding="utf-8") as fh:
                fh.write(new_text)
    print("house-colour-guard: %d colour(s) mapped into the cloth" % changed)
    return 0


def main(argv):
    if len(argv) >= 3 and argv[1] == "--map":
        hits = findings(" ".join(argv[2:]), style=True)
        if not hits:
            print("%s: not blue or purple — no change" % " ".join(argv[2:]))
        for _s, _e, old, new in hits:
            print("%s -> %s" % (old, new))
        return 0
    if len(argv) >= 4 and argv[1] == "--fix":
        return fix(argv[2], argv[3:])
    if len(argv) < 3 or argv[1] != "check":
        print(__doc__.split("Usage:")[1].strip(), file=sys.stderr)
        return 2
    root = argv[2]
    files = argv[3:] or tracked(root)
    hard, soft = scan(root, files)
    rotten = []
    if not argv[3:]:
        every = tracked(root)
        rotten = [g for g, _k, _r in load_allow(root) if not any(_match(f, g) for f in every)]
    for g in rotten:
        hard.append(("house-colour.allow", 0, g, "a rotten allow line — it matches no tracked file; remove it"))
    if soft:
        print("house-colour-guard held[%d]{kind,file,colours,reason}:" % len(soft))
        for (kind, rel, reason), count in sorted(soft.items()):
            print('  "%s","%s",%d,"%s"' % (kind, rel, count, reason.replace('"', "'")))
    if hard:
        print("house-colour-guard findings[%d]{file,line,colour,house}:" % len(hard))
        for rel, n, colour, new in hard:
            print('  "%s",%d,"%s","%s"' % (rel, n, colour.replace('"', "'"), new))
        print("house-colour-guard: %d blue/purple colour(s) in %d file(s) — the house colour each "
              "becomes is named beside it (--fix FILE applies it); RULES/54"
              % (len(hard), len({h[0] for h in hard})), file=sys.stderr)
        return 1
    print("house-colour-guard: clean — no blue or purple outside house-colour.allow "
          "(%d held or specimen colour(s) named above)" % sum(soft.values()))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
