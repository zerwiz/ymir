#!/usr/bin/env bash
# contract-coverage.sh — the contract may be slimmed, never emptied: prove nothing was lost (plan 369 item 7).
#
#   bin/seat/contract-coverage.sh               check (the default): coverage, the index, the core's length
#   bin/seat/contract-coverage.sh --missing     print only the tokens the live contract lost
#   bin/seat/contract-coverage.sh --index       print the topic index generated from each topic's first line
#   bin/seat/contract-coverage.sh --write-index rewrite the index block in AGENTS.md from the topic files
#
# WHY (RULES/06, appended 2026-11-24): the always-loaded contract is a living document. A correction is folded into
# its topic and the prior text is kept verbatim in docs/contract-history/. Folding is where facts get lost, so this
# check lists every command, path, rule number, port and plan number in the NEWEST history copy and fails when one
# appears nowhere in the live core (AGENTS.md) plus the topic files (.agents/assets/agents/contract/*.md).
# A deliberate retirement is named in .agents/assets/agents/contract/coverage-allow.txt as `<token><TAB><reason>`.
#
# It also checks the core is at most 150 lines (YMIR_CONTRACT_MAX_LINES) and that its topic index matches the files.
# Exit: 0 whole · 1 a token lost, the index stale or the core too long · 2 usage.
set -uo pipefail
_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}
ROOT="${YMIR_CONTRACT_ROOT:-$(_root)}"
CORE="$ROOT/AGENTS.md"
TOPICS="$ROOT/.agents/assets/agents/contract"
ALLOW="$TOPICS/coverage-allow.txt"
HIST="${YMIR_CONTRACT_HISTORY:-$(ls "$ROOT"/docs/contract-history/AGENTS-*.md 2>/dev/null | sort | tail -1)}"
MAX="${YMIR_CONTRACT_MAX_LINES:-150}"
mode="check"
case "${1:-}" in
  "") ;;
  --missing) mode="missing" ;;
  --index) mode="index" ;;
  --write-index) mode="write-index" ;;
  -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) printf 'error: unknown argument %s\nhelp: contract-coverage.sh [--missing|--index|--write-index]\n' "$1" >&2; exit 2 ;;
esac

index_lines() {  # one line per topic file, from its first line ("Read when: …")
  local f first
  for f in "$TOPICS"/*.md; do
    [ -f "$f" ] || continue
    first="$(sed -n '1s/^Read when: *//p' "$f")"
    printf -- '- `%s` — read when %s\n' "$(basename "$f")" "${first:-(no Read-when line — add one)}"
  done
}

case "$mode" in
  index) index_lines; exit 0 ;;
  write-index)
    python3 - "$CORE" "$(index_lines)" <<'PY'
import re, sys
p, block = sys.argv[1], sys.argv[2]
s = open(p, encoding="utf-8").read()
new = re.sub(r"(<!-- contract-index:begin -->\n).*?(<!-- contract-index:end -->)",
             lambda m: m.group(1) + block.rstrip("\n") + "\n" + m.group(2), s, flags=re.S)
if new != s:
    open(p, "w", encoding="utf-8").write(new)
    print("contract-coverage: the topic index in AGENTS.md was rewritten")
else:
    print("contract-coverage: the topic index in AGENTS.md is current")
PY
    exit 0 ;;
esac

[ -r "$HIST" ] || { printf 'contract-coverage: no history copy in docs/contract-history/ — nothing to measure against\n' >&2; exit 1; }
[ -r "$CORE" ] || { printf 'contract-coverage: no AGENTS.md at %s\n' "$CORE" >&2; exit 1; }

python3 - "$HIST" "$CORE" "$TOPICS" "$ALLOW" "$mode" "$MAX" "$(index_lines)" <<'PY'
import glob, os, re, sys
hist, core, topics, allow, mode, maxl, index = sys.argv[1:8]
old = open(hist, encoding="utf-8").read()
live_files = [core] + sorted(glob.glob(os.path.join(topics, "*.md")))
live = "\n".join(open(f, encoding="utf-8").read() for f in live_files)

allowed = {}
if os.path.exists(allow):
    for line in open(allow, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("#") or "\t" not in line:
            continue
        tok, why = line.split("\t", 1)
        allowed[tok.strip()] = why.strip()

ROOTS = r"(?:bin|RULES|docs|apps|config|scripts|src|tools|packages|systems|midgard|tests|\.agents|\.claude|\.pi|\.opencode|\.githooks|hodd|svartalfaheim|life|state)"
PATH = re.compile(r"(?<![\w./-])(" + ROOTS + r"/[A-Za-z0-9_.*/<>{}-]*[A-Za-z0-9_*>}])")
tokens = {}
def add(kind, tok):
    tokens.setdefault((kind, tok), None)
for m in PATH.finditer(old):
    tok = m.group(1).rstrip(".")
    if tok.endswith("*") and not tok.endswith("/**"):
        tok = tok.rstrip("*")          # a bold marker (**RULES/25**), not a glob
    if len(tok.split("/")) >= 2 and tok.split("/")[1]:
        add("path", tok)
for m in re.finditer(r"\b(?:RULES/|Rule\s+)(\d{2})\b", old):
    add("rule", m.group(1))
for m in re.finditer(r"(?<![\w.])`?:(\d{4,5})\b", old):
    add("port", m.group(1))
for m in re.finditer(r"\b[Pp]lans?\s+\**(\d{2,3})\b", old):
    add("plan", m.group(1))

def present(kind, tok):
    if kind == "path":
        return tok in live
    if kind == "rule":
        return re.search(r"\b(?:RULES/|Rule\s+)%s\b" % tok, live) is not None
    if kind == "port":
        return re.search(r"(?<![\d.])%s\b" % tok, live) is not None
    if kind == "plan":
        return re.search(r"\b[Pp]lans?\s+\**(?:\d+\s*(?:,|and|·)\s*)*%s\b" % tok, live) is not None
    return False

label = {"path": "{}", "rule": "RULES/{}", "port": ":{}", "plan": "plan {}"}
lost, waived = [], []
for (kind, tok) in sorted(tokens):
    name = label[kind].format(tok)
    if present(kind, tok):
        continue
    if name in allowed:
        waived.append((name, allowed[name]))
    else:
        lost.append(name)

bad = 0
if mode == "missing":
    for n in lost:
        print(n)
    raise SystemExit(1 if lost else 0)

n_core = sum(1 for _ in open(core, encoding="utf-8"))
print("contract_coverage[1]{history,tokens,kept,waived,lost,core_lines,core_max}:")
print('  "%s",%d,%d,%d,%d,%d,%s' % (os.path.relpath(hist, os.path.dirname(core)), len(tokens),
      len(tokens) - len(lost) - len(waived), len(waived), len(lost), n_core, maxl))
for n in lost:
    print("contract-coverage: LOST %s — it is in the history copy and nowhere in the core or a topic file" % n)
    bad = 1
if n_core > int(maxl):
    print("contract-coverage: the core is %d lines, over the %s-line budget" % (n_core, maxl))
    bad = 1
s = open(core, encoding="utf-8").read()
m = re.search(r"<!-- contract-index:begin -->\n(.*?)<!-- contract-index:end -->", s, flags=re.S)
if not m:
    print("contract-coverage: AGENTS.md has no contract-index block")
    bad = 1
elif m.group(1).rstrip("\n") != index.rstrip("\n"):
    print("contract-coverage: the topic index in AGENTS.md is stale — run bin/seat/contract-coverage.sh --write-index")
    bad = 1
if not bad:
    print("contract-coverage: whole — every token of the history copy is kept or waived by name")
raise SystemExit(bad)
PY
