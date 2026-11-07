#!/usr/bin/env bash
# advantage-audit.sh — is every claim we make backed by evidence, or only by confidence?
#
#   advantage-audit.sh <doc.md>              audit sections that carry an Evidence line
#   advantage-audit.sh --strict <doc.md>     audit every section (a client-facing page)
#   advantage-audit.sh --check [--strict] …  exit 1 if any claim is unsupported
#   advantage-audit.sh --json  …             machine-readable, for a board or a report
#   advantage-audit.sh --skip "Title" …      a section that is not a claim
#
# A CLAIM is a section that states what we are better at. Its EVIDENCE is the line
# inside it that starts with `**Evidence:**` (or `Evidence:` / `**The evidence:**`),
# and it counts as present only when something checkable follows: a date, a number, a
# link, a named record, a named signature. A placeholder is not evidence — ⟨…⟩, <…>,
# TBD, TODO, ____, "to be measured", "n/a".
#
# WHY: an advantage with no evidence line competes on adjectives, and adjectives lose
# to whoever is cheaper. The rule this enforces is the house rule: a claim with an
# empty evidence line is deleted, never softened.
#
# Exit: 0 every claim supported · 1 at least one unsupported (with --check) · 2 usage.
set -uo pipefail

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

mode=report; strict=0; doc=""; skip_names=(); want_skip=0
for a in "$@"; do
  if [ "$want_skip" = 1 ]; then skip_names+=("$a"); want_skip=0; continue; fi
  case "$a" in
    --check) mode=check ;;
    --json)  mode=json ;;
    --strict) strict=1 ;;
    --skip)  want_skip=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) printf 'advantage-audit: unknown option %s\n' "$a" >&2; exit 2 ;;
    *)  doc="$a" ;;
  esac
done
[ -n "$doc" ] || { usage >&2; exit 2; }
[ -f "$doc" ] || { printf 'advantage-audit: no such document: %s\n' "$doc" >&2; exit 2; }

python3 - "$doc" "$mode" "$strict" "${skip_names[*]:-}" <<'PY'
import json, re, sys

path, mode, strict, extra = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4]
lines = open(path, encoding="utf-8").read().splitlines()

headings = [(i, len(m.group(1)), m.group(2).strip())
            for i, line in enumerate(lines)
            for m in [re.match(r'^(#{2,4})\s+(.*\S)\s*$', line)]
            if m]

# Framing sections are not claims about the business, in either mode.
SKIP = {"change log", "contents", "appendix", "sources", "the documents",
        "how to use this", "keeping this playbook true", "status", "sign-off",
        "what we will not claim", "how to test any of this",
        "the one-sentence version", "where we are honestly not advantaged",
        "what makes it durable, in order", "the rule for anything client-facing"}
skip_extra = {s.strip().lower() for s in extra.split("  ") if s.strip()}

PLACEHOLDER = re.compile(
    r'(\u27e8|\u27e9|<[^>]*>|_{2,}|\bTBD\b|\bTODO\b|\bto be measured\b'
    r'|\bto be filled\b|\bn/?a\b|\bpending\b|\bplaceholder\b|\(empty\))', re.I)
EVID = re.compile(r'^\s*\*{0,2}(the\s+)?evidence:?\*{0,2}\s*(.*)$', re.I)

def body_of(index, level):
    """The section's own lines: stop at the NEXT heading of any level."""
    for i, _, _ in headings:
        if i > index:
            return lines[index + 1:i]
    return lines[index + 1:]

claims, skipped = [], 0
for i, level, title in headings:
    key = title.lower().strip(' .:—-"')
    if key in SKIP or key in skip_extra:
        skipped += 1
        continue
    body = body_of(i, level)
    prose = [l for l in body if l.strip() and not l.strip().startswith(("#", "-", "*", "|", ">", "```"))]
    if len(prose) < 1:
        skipped += 1          # a heading that only introduces children is not a claim
        continue
    evidence_at, evidence = None, ""
    for j, line in enumerate(body):
        m = EVID.match(line)
        if not m:
            continue
        evidence_at, evidence = i + 1 + j, (m.group(2) or "").strip()
        if not evidence:                      # an evidence line whose content wraps
            for k in range(j + 1, len(body)):
                nxt = body[k]
                if not nxt.strip() or re.match(r'^(\s*[-*|>#]|```)', nxt) or EVID.match(nxt):
                    break
                evidence = (evidence + " " + nxt.strip()).strip()
                break
        break
    if evidence_at is None and not strict:
        skipped += 1          # not marked as a claim, and not strict: leave it alone
        continue
    claims.append({"title": title, "line": i + 1,
                   "evidence_line": (evidence_at + 1) if evidence_at is not None else None,
                   "evidence": evidence})

def verdict(c):
    ev = c["evidence"]
    if not ev:
        return "NO-EVIDENCE", "state the measurement, record, link or signature that proves it"
    if PLACEHOLDER.search(ev):
        return "PLACEHOLDER", "a placeholder is not evidence: fill it or delete the claim"
    if len(ev) < 12:
        return "THIN", "too short to be checkable: a date, a number, a link or a named record"
    return "OK", ""

results = [(c, *verdict(c)) for c in claims]
bad = [(c, v, why) for c, v, why in results if v != "OK"]

if mode == "json":
    print(json.dumps({"document": path,
                      "claims": [{"title": c["title"], "line": c["line"], "evidence": c["evidence"],
                                  "evidence_line": c["evidence_line"], "verdict": v, "fix": why}
                                 for c, v, why in results],
                      "unsupported": len(bad), "total": len(results)}, indent=2))
    sys.exit(1 if (bad and mode == "check") else 0)

print("advantage-audit · %s%s" % (path, "  (strict)" if strict else ""))
print("  claims: %d   supported: %d   unsupported: %d" %
      (len(results), len(results) - len(bad), len(bad)))
for c, v, why in results:
    if v == "OK":
        print("  OK         %-56s line %d" % (c["title"][:56], c["line"]))
    else:
        print("  %-10s %-56s line %d" % (v, c["title"][:56], c["line"]))
        print("             evidence line: %s" % (c["evidence_line"] or "—"))
        print("             %s" % why)
if skipped:
    print("  (%d section(s) not treated as claims)" % skipped)
if bad:
    print("\nA claim with no evidence competes on adjectives. Fill it or delete it.")
sys.exit(1 if (bad and mode == "check") else 0)
PY
