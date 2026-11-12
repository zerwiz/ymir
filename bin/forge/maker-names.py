#!/usr/bin/env python3
"""maker-names.py — the ONE matcher for model, model-maker and agent-harness names in prose (RULES/53).

Every door shares this file: the commit-msg hook, the pre-push hook, the PR-opening
door and the CI ward all reach it through bin/gates/guards/maker-guard.sh or through
pr_pattern_match in bin/forge/pr-patterns.sh. There is no second word list.

Usage:  maker-names.py scan <file|-> [--git-message] [--allow FILE] [--words FILE]
Output: one line per refusal, `maker: line N: "<word>" — <the line>`; exit 1 when any, else 0.

What is judged is PROSE. A fenced code block and an `inline code span` are code, and code
names a harness functionally (`.claude/hooks/ymir-arm.sh`, `--harness claude`), so both
are skipped. Anything else that is allowed is listed, with a reason, in
bin/gates/maker-allow.txt (override: $YMIR_MAKER_ALLOW). The word list is
bin/gates/maker-words.txt (override: $YMIR_MAKER_WORDS), plus model ids from the catalog.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
AI_HINT = re.compile(r"claude|anthropic|openai|chatgpt|gpt|gemini|copilot|codex|cursor|grok|llm|(?<!\w)ai(?!\w)|bot(?!\w)", re.I)
COAUTHOR_RE = re.compile(r"^\s*co-authored-by\s*:", re.I)
GENERATED_RE = re.compile(r"^[\s\W]*generated with\b", re.I)
ROBOT = "\U0001F916"
SCISSORS = re.compile(r"^# -+ >8 -+$")


def load_rows(path):
    """Rows `word | kind | reason`; a row with no reason is no row."""
    rows = []
    if path and os.path.isfile(path):
        for raw in open(path, encoding="utf-8"):
            if not raw.strip() or raw.lstrip().startswith("#"):
                continue
            parts = [x.strip() for x in raw.split("|")]
            if len(parts) >= 3 and parts[0] and parts[2]:
                rows.append(parts[0])
    return rows


def catalog_ids():
    """Model ids from bin/model/catalog.sh, cached a day; a refresh runs in the background.
    Where there is no catalog (a client repo, a bare machine) this is a clean skip."""
    cat = os.path.join(HERE, "..", "model", "catalog.sh")
    cache = os.environ.get("YMIR_MAKER_CATALOG_CACHE") or os.path.join(
        os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "ymir", "maker-catalog.txt")
    if os.environ.get("YMIR_MAKER_CATALOG") == "0" or not os.path.isfile(cat):
        return []
    try:
        import time, subprocess
        age = time.time() - os.path.getmtime(cache) if os.path.isfile(cache) else None
        if age is None or age > 86400:
            os.makedirs(os.path.dirname(cache), exist_ok=True)
            sh = 'out=$(timeout 90 bash "%s" 2>/dev/null | sed -n \'s/^  "[^"]*","\\([^"]*\\)".*/\\1/p\') && [ -n "$out" ] && printf "%%s\\n" "$out" > "%s.tmp" && mv "%s.tmp" "%s"' % (cat, cache, cache, cache)
            subprocess.Popen(["bash", "-c", sh], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        if os.path.isfile(cache):
            return [l.strip() for l in open(cache) if len(l.strip()) >= 6 and re.search(r"[-._\d]", l)]
    except Exception:
        pass
    return []


def build_word_re(words_path):
    words = load_rows(words_path) + catalog_ids()
    words = sorted(set(w for w in words), key=len, reverse=True)
    if not words:
        return None
    return re.compile(r"(?<![\w-])(" + "|".join(re.escape(w) for w in words) + r")(?![\w-])", re.I)


def load_allow(path):
    phrases = []
    if not path or not os.path.isfile(path):
        return phrases
    for raw in open(path, encoding="utf-8"):
        raw = raw.rstrip("\n")
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        phrase, sep, reason = raw.partition("|")
        if sep and phrase.strip() and reason.strip():  # an exception without a reason is no exception
            phrases.append(phrase.strip())
    return phrases


def prose_lines(text, git_message):
    """Yield (lineno, original, prose) with code removed."""
    fence = None
    for n, line in enumerate(text.split("\n"), 1):
        if git_message:
            if SCISSORS.match(line):
                return
            if line.startswith("#"):
                continue
        m = re.match(r"^\s*(`{3,}|~{3,})", line)
        if m:
            mark = m.group(1)[0]
            if fence is None:
                fence = mark
            elif fence == mark:
                fence = None
            continue
        if fence is not None:
            continue
        prose = re.sub(r"(`+)[^`]*?\1", "", line)
        yield n, line, prose


def scan(text, git_message=False, allow=(), word_re=None):
    hits = []
    for n, line, prose in prose_lines(text, git_message):
        for ph in allow:
            prose = re.sub(re.escape(ph), "", prose, flags=re.I)
        found = None
        m = word_re.search(prose) if word_re else None
        if m:
            found = m.group(1)
        elif COAUTHOR_RE.match(prose) and AI_HINT.search(prose):
            found = "Co-Authored-By"
        elif GENERATED_RE.match(prose):
            found = "Generated with"
        elif ROBOT in prose:
            found = ROBOT
        if found:
            hits.append('maker: line %d: "%s" — %s' % (n, found, line.strip()[:160]))
    return hits


def main(argv):
    if len(argv) < 3 or argv[1] != "scan":
        sys.stderr.write(__doc__)
        return 2
    src, git_message, allow_path = argv[2], False, os.environ.get("YMIR_MAKER_ALLOW")
    words_path = os.environ.get("YMIR_MAKER_WORDS")
    rest = argv[3:]
    while rest:
        a = rest.pop(0)
        if a == "--git-message":
            git_message = True
        elif a == "--allow" and rest:
            allow_path = rest.pop(0)
        elif a == "--words" and rest:
            words_path = rest.pop(0)
    if not allow_path:
        allow_path = os.path.join(HERE, "..", "gates", "maker-allow.txt")
    if not words_path:
        words_path = os.path.join(HERE, "..", "gates", "maker-words.txt")
    text = sys.stdin.read() if src == "-" else open(src, encoding="utf-8", errors="replace").read()
    hits = scan(text, git_message, load_allow(allow_path), build_word_re(words_path))
    for h in hits:
        print(h)
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
