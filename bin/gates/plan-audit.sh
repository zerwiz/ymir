#!/usr/bin/env bash
# plan-audit.sh — the plan CONTRACT, as a check over the ledger shelf.
#
# WHY (2026-10-24): the ledger was audited by hand and the hand lied about one measure —
# *"plans carrying explicit 'Phase N' headings: 10 of 62"* — because it counted a WORD where
# the plans carry numbered sections (`## 1 ·`, `## 2 ·`). That is how an audit lies: it reads
# the spelling and calls it the structure. So this check reads the OUTLINE.
#
# The contract (the audit's own §"What would make the ledger correct"). A plan is correct
# when it carries:
#   1 · his words      — the instruction that caused it, quoted, with a date
#   2 · a measured     — a section of numbers or commands another hand can re-run
#   3 · phases + proof — structural steps, each ending in something observable
#   4 · a refusal      — the failure it exists to prevent
#   5 · questions      — the ones that are genuinely his, numbered
#   6 · a number       — unique on the shelf (or disambiguated `NN · suffix` in the index)
#   7 · an index row   — a README row that names the plan AND carries a status
#
#   bin/gates/plan-audit.sh                # report every plan on the shelf
#   bin/gates/plan-audit.sh --check        # exit nonzero on a NEW gap (wired into ci-verify)
#   bin/gates/plan-audit.sh --baseline     # accept the shelf AS IT STANDS: record its gaps
#                                          # once, so the gate then guards the next plan only
#   bin/gates/plan-audit.sh --rows         # the proposed README rows, oldest number first
#   bin/gates/plan-audit.sh --json         # the same verdicts, machine-readable
#   bin/gates/plan-audit.sh --shelf DIR    # audit another shelf (what --self-test uses)
#   bin/gates/plan-audit.sh --self-test    # prove the check BITES: a gap must fail, an
#                                          # outline must pass where the word-count failed
#
# It is a READ-ONLY gate. It never writes the shelf, never renumbers a plan, never edits a
# row: it reports, and a human (or Brokk, by PR) applies the patch. Rule 06 is why.
#
# A shelf that is absent is a SKIP, exit 0 — the ledger lives in the operator's private home
# and CI has none. A gate that fails for a missing input reads as "the repo is broken".
# Exit: 0 clean (or SKIP) · 1 a gap · 2 usage.
set -uo pipefail

VERSION="1.0.0"

_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}
ROOT="$(_root)"

usage() { sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'error: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf 'help: %s\n' "$2" >&2; exit 2; }

# The shelf is the HOME's, resolved by the one resolver — never a literal $HOME path
# (Rule 07; defaults-guard refuses exactly that). Same resolution as bin/gates/queue.sh.
shelf_default() {
  [ -n "${YMIR_PLAN_DIR:-}" ] && { printf '%s' "$YMIR_PLAN_DIR"; return 0; }
  local h="${YMIR_HOME:-}"
  if [ -z "$h" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
    . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
    command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root h
  fi
  [ -n "$h" ] || h="$(bash "$ROOT/bin/vault/hodd.sh" path 2>/dev/null || true)"
  [ -n "$h" ] || return 1
  printf '%s' "$h/svartalfaheim/whynotproductions/projects/ymir/plans"
}

MODE="report"; SHELF=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check|--report|--rows|--json|--baseline) MODE="${1#--}"; shift ;;
    --shelf) SHELF="${2-}"; [ -n "$SHELF" ] || die "--shelf needs a directory"; shift 2 ;;
    --self-test) MODE="self-test"; shift ;;
    -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help|help) usage; exit 0 ;;
    *) die "unknown argument: $1" "see --help" ;;
  esac
done
[ "$MODE" = "report" ] && MODE="report"
[ -n "$SHELF" ] || SHELF="$(shelf_default)" || die "cannot resolve the home" "set YMIR_HOME or name a shelf with --shelf"

# ---------------------------------------------------------------- the self-test shelf
# A tiny shelf built from three plans whose STRUCTURE differs from their spelling:
#   *perfect*  — a quote with a date, a measured section, numbered sections `## 1 ·` each
#                with a proof, a refusal, questions, one number, one row with a status.
#                It uses NO "Phase N" heading: the word-count audit would score it zero.
#   *bare*     — prose only. Every one of the seven must fail.
#   *twin-a/b* — the same number twice, no suffixed index rows: the unique-number check must
#                fail; then suffixed rows are added and it must pass.
if [ "$MODE" = "self-test" ]; then
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  shelf="$tmp/plans"; mkdir -p "$shelf"

  cat >"$shelf/10-perfect.md" <<'MD'
# Plan 10 — The perfect plan

**Status:** opened · **Date:** 2026-10-24

**His words, 2026-10-24:** *"make the thing and prove the thing."*

## 1 · The measured state

```
measured on this box: 3 doors, 1 answering
```

## 2 · The work

The first step. Proof: `bin/gates/demo.sh --check` exits 0.

## 3 · The second step

The second step. Verified by a smoke run that names the failing row.

## What it refuses

It refuses to answer zero when it cannot read the shelf.

## Questions for the Allfather

1. Is the shelf the right one?
2. Does the suffix read well?
MD
  cat >"$shelf/11-bare.md" <<'MD'
# Plan 11 — A plan with none of it

Notes, in prose, about a thing that might be done one day. No numbers, no steps,
no refusal, no questions, no index row.
MD
  cat >"$shelf/20-twin-a.md" <<'MD'
# Plan 20 — Twin A

**Status:** opened · **Date:** 2026-10-24
**His words, 2026-10-24:** *"two plans, one number, and the index must say which."*

## 1 · The measured state

```
two files share the number 20
```

## 2 · The work

Done. Proof: the gate exits 0.

## What it refuses

It refuses a citation that names two things.

## Questions for the Allfather

1. Which suffix?
MD
  cat >"$shelf/20-twin-b.md" <<'MD'
# Plan 20 — Twin B

**Status:** opened · **Date:** 2026-10-24
**His words, 2026-10-24:** *"two plans, one number, and the index must say which."*

## 1 · The measured state

```
two files share the number 20
```

## 2 · The work

Done. Proof: the gate exits 0.

## What it refuses

It refuses a citation that names two things.

## Questions for the Allfather

1. Which suffix?
MD
  cat >"$shelf/12-rowless.md" <<'MD'
# Plan 12 — The plan with no row

**Status:** proposed · **Date:** 2026-10-24
**His words, 2026-10-24:** *"a plan the index cannot find is a plan nobody reads."*

## 1 · The measured state

```
zero rows name this plan
```

## 2 · The work

Append the row. Proof: the gate exits 0.

## What it refuses

It refuses to be found only by grep.

## Questions for the Allfather

1. Append it where?
MD
  cat >"$shelf/README.md" <<'MD'
# Index

| # | Plan | Path |
|---|------|------|
| 10 | [The perfect plan](10-perfect.md) | opened |
| 11 | [A plan with none of it](11-bare.md) | opened |
MD
  rc=0; say() { printf '%s\n' "$*"; }

  out="$(bash "${BASH_SOURCE[0]}" --check --shelf "$shelf" 2>&1)" && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then say "  check a shelf with a GAP:               FAIL (it passed a bare plan)"; rc=1
  else say "  check a shelf with a GAP:               ok (it bit)"; rc=0; fi

  # the perfect plan: numbered sections, no "Phase N" anywhere — the outline must be read
  if grep -q '"10".*"ok"' <<<"$out"; then say "  numbered sections read as phases:      ok"; else
    say "  numbered sections read as phases:      FAIL (the word-count audit's own blind spot)"; rc=1; fi
  # the bare plan: nothing
  if grep -qE '^\s+"11",' <<<"$out" && grep -q '"gap"' <<<"$out"; then say "  a prose-only plan is a gap:           ok"; else
    say "  a prose-only plan is a gap:           FAIL (it read prose as structure)"; rc=1; fi
  # the twins: duplicate numbers must be refused while no suffixed row exists
  if grep -q 'dup' <<<"$out"; then say "  two files on one number:               ok (named)"; else
    say "  two files on one number:               FAIL (a reuse went unseen)"; rc=1; fi

  # now disambiguate IN THE INDEX ONLY — files untouched — and the number rule must pass
  cp "$shelf/README.md" "$tmp/readme.bak"
  cat >>"$shelf/README.md" <<'MD'
| 20 · twin a | [Twin A](20-twin-a.md) | opened |
| 20 · twin b | [Twin B](20-twin-b.md) | opened |
MD
  out2="$(bash "${BASH_SOURCE[0]}" --json --shelf "$shelf" 2>&1)"
  twins_ok="$(python3 - "$out2" <<'PY'
import json,sys
j=json.loads(sys.argv[1])
twins=[p for p in j['rows'] if p['file'] in ('20-twin-a.md','20-twin-b.md')]
print('ok' if len(twins)==2 and all(t['status']['number'] for t in twins) else 'FAIL')
PY
)"
  if [ "$twins_ok" = ok ]; then
    say "  a suffixed index row frees the number:  ok (files never renumbered)"; else
    say "  a suffixed index row frees the number:  FAIL"; rc=1; fi
  cp "$tmp/readme.bak" "$shelf/README.md"

  # --rows must emit a row for the rowless plan, and every word must come from the plan.
  # This runs BEFORE the row is appended below, or there is no rowless plan left to test.
  rowout="$(bash "${BASH_SOURCE[0]}" --rows --shelf "$shelf" 2>&1)"
  if grep -q '12-rowless.md' <<<"$rowout" && grep -q 'The plan with no row' <<<"$rowout"; then
    say "  --rows proposes a row for a rowless plan: ok (sentence verbatim)"; else
    say "  --rows proposes a row for a rowless plan: FAIL"; rc=1; fi

  # a row that names the plan with no status is a gap: the contract says row AND status
  printf '| 11 | A plan | `11-bare.md` |\n' >>"$shelf/README.md"
  if bash "${BASH_SOURCE[0]}" --check --shelf "$shelf" >/dev/null 2>&1; then
    say "  a row with no status:                   FAIL (it passed a stateless row)"; rc=1
  else say "  a row with no status:                   ok (it bit)"; fi

  # the RATCHET: a recorded gap must stop failing, and a NEW one must still bite
  if YMIR_STATE_DIR="$tmp/state" bash "${BASH_SOURCE[0]}" --baseline --shelf "$shelf" >/dev/null 2>&1; then
    if YMIR_STATE_DIR="$tmp/state" bash "${BASH_SOURCE[0]}" --check --shelf "$shelf" >/dev/null 2>&1; then
      say "  a recorded baseline stops it failing:    ok (known gaps do not block)"
    else
      say "  a recorded baseline stops it failing:    FAIL"; rc=1
    fi
    printf '\n# Plan 13 — a new plan with nothing\n\nprose only.\n' >"$shelf/13-new.md"
    if YMIR_STATE_DIR="$tmp/state" bash "${BASH_SOURCE[0]}" --check --shelf "$shelf" >/dev/null 2>&1; then
      say "  a NEW gap still bites:                   FAIL (the ratchet let it through)"; rc=1
    else
      say "  a NEW gap still bites:                   ok (the next plan cannot slip)"
    fi
    rm -f "$shelf/13-new.md"
  else
    say "  --baseline writes the machine state:     FAIL"; rc=1
  fi

  # a missing shelf is a SKIP, not a failure (CI has no vault)
  skip="$(bash "${BASH_SOURCE[0]}" --check --shelf "$tmp/nowhere" 2>&1)" && s=0 || s=$?
  if [ "$s" -eq 0 ] && grep -q 'SKIP' <<<"$skip"; then say "  an absent shelf SKIPs loudly:           ok"; else
    say "  an absent shelf SKIPs loudly:           FAIL"; rc=1; fi

  if [ "$rc" -eq 0 ]; then printf '\nplan-audit self-test: PASS\n'; exit 0; fi
  printf '\nplan-audit self-test: FAIL\n' >&2; exit 1
fi

# ---------------------------------------------------------------- the audit
[ -d "$SHELF" ] || {
  printf 'plan_audit[1]{verdict,why}:\n  "SKIP","no ledger shelf at %s — it lives in the operator home and CI has none. Nothing was checked."\n' "$SHELF"
  exit 0
}

# The baseline is MACHINE state, not repo state: every seat holds its own copy of the ledger, so a
# baseline committed to the tree would be another machine's gaps. Rule 07 — one resolver.
_state="${YMIR_STATE_DIR:-}"
if [ -z "$_state" ]; then
  _h="${YMIR_HOME:-}"
  command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root _h
  [ -n "$_h" ] || _h="$(bash "$ROOT/bin/vault/hodd.sh" path 2>/dev/null || true)"
  _state="$_h/state"
fi

exec python3 - "$SHELF" "$MODE" "$_state" <<'PY'
import os, re, sys, json

shelf, mode = sys.argv[1], sys.argv[2]
state_dir = sys.argv[3] if len(sys.argv) > 3 else ""
BASELINE = os.path.join(state_dir, "plan-audit-baseline.json") if state_dir else ""

# The curated suffixes for a number that is used twice. The task's own examples
# (`72 · the vault`, `72 · snotra live tail`) are the shape: short, human, and IN THE
# INDEX ONLY. A file is never renamed — every citation to it would break.
SUFFIX = {
    "72-hnitbjorg-encrypted-vault.md": "the vault",
    "72-snotra-live-tail.md": "snotra live tail",
    "86-heart-in-the-fleet.md": "the heart",
    "86-switch-games-backup-to-svartmagi.md": "switch games",
    "93-snotra-in-hlidskjalf.md": "snotra in the gate",
    "93-the-thread-a-real-terminal-in-the-high-seat.md": "the thread",
    "94-retiring-the-old-worktrees.md": "old worktrees",
    "94-snotra-patent-grade-evidence.md": "patent evidence",
}

STATUS_WORDS = """opened open proposed built active in progress in-progress pending approved ready
briefed dispatched draft scaffold paused blocked done shipped live merged superseded folded
retired sealed in shaping forging""".split()

RE_H1      = re.compile(r'^#\s+(?P<t>.+?)\s*$')
RE_HEADING = re.compile(r'^(?P<h>#{2,6})\s+(?P<t>.+?)\s*$')
RE_QUOTE   = re.compile(r'^\s*>')
RE_DATE    = re.compile(r'\b20\d\d-\d\d-\d\d\b')
RE_ATTRIB  = re.compile(r'allfather|his words?|his voice|his charge|his question|the ask|asked by|asked 20', re.I)
RE_MEASURE = re.compile(r'measur|the numbers|audit|evidence|survey|what we (have|already|do)|what exists|'
                        r'counted|found|diagnos|recon|baseline|inventory|what it costs|the state', re.I)
RE_PROOF   = re.compile(r'proof|prove[sn]?|provable|verified|verif(y|ied)|observable|smoke|test|gauge|'
                        r'exit(s)? [0-9]|demonstrat|assert|check that|the check', re.I)
RE_PROOF_H = re.compile(r'acceptance|the proof|proofs?\b|verification|how we know|the gate that|'
                        r'what makes it pass|evidence', re.I)
RE_PHASE_H = re.compile(r'^\s*(phases?|steps?|stages?|parts?)\s*$', re.I)
RE_ITEM    = re.compile(r'^\s*(?:[-*]|\d+\.|\|)\s*\S')
RE_REFUSE  = re.compile(r'\brefus|what it (does not|will not)|non-goal|out of scope|not doing|'
                        r'will never|never (does|will|ships)|limits?\b|why not|the refusal', re.I)
RE_QUEST   = re.compile(r'questions?\b|asks? of|for the allfather|decisions? (needed|to make)|'
                        r'open questions|to decide|unsealed', re.I)
RE_STEP_H  = re.compile(r'^\s*(?:phase|step|stage|part)\b[^a-z]{0,3}\s*[0-9ivx]|^\s*P\d+\b', re.I)
RE_NUM_H   = re.compile(r'^(\d+)\s*[·.:)\-–—]')
RE_FENCE   = re.compile(r'^\s*```')
RE_STATUS  = re.compile(r'\*\*status\b[:\*]*\s*(?P<s>[^*\n·|]+)', re.I)
RE_STATUS2 = re.compile(r'^\s*status\s*:\s*(?P<s>.+)$', re.I)
RE_TABLEROW= re.compile(r'^\s*[-]?\s*\|')
RE_LINK    = re.compile(r'\[[^\]]*\]\((?P<p>[^)]+)\)')
RE_TICKED  = re.compile(r'`(?P<p>[^`]+\.md)`')
# The house states its contracts as TOON blocks (`asks[3]{question,why}:`, `refuses[2]{…}:`).
# An outline reader must accept that vocabulary, or it reports a gap where the plan answered.
RE_TOON     = re.compile(r'^\s*(?P<name>[a-z][a-z0-9_]*)\[(?P<n>\d+)\]\{(?P<cols>[^}]*)\}\s*:?\s*$')
RE_TOON_ROW = re.compile(r'^\s*"')
# A prohibition stated in prose or a bullet is a refusal too — the audit accepts a refusal
# living inside a phase, so the test must not demand a heading with the word in it.
RE_PROHIBIT = re.compile(r'\brefus(e|es|ed|ing)\b|\bmust not\b|\bwill not\b|\bis forbidden\b|'
                         r'\bnever (conflate|ship|do|read|leak|send|auto|write|touch|delete|reuse)\b', re.I)

def norm(s):
    return re.sub(r'\s+', ' ', s).strip()

def read(p):
    try:
        return open(p, encoding='utf-8').read()
    except UnicodeDecodeError:
        return open(p, encoding='utf-8', errors='replace').read()

def sections(text):
    """The OUTLINE: (h1, [(level, title, [body lines])]) — the spine every check reads.

    Some plans use a single `#` for their SECTIONS (`# 1 · the proof …`) and only the first
    one is the title. Reading the last `# ` line as the H1 made plan 94 look like "plan 4" —
    the same class of mistake as counting the word 'Phase', so the H1 is the FIRST such line
    and every later one is a level-1 section."""
    lines = text.splitlines()
    h1, seen_h1 = "", False
    out, cur = [], None
    for ln in lines:
        m = RE_HEADING.match(ln)
        if m and ln.startswith('##'):
            if cur: out.append(cur)
            cur = (len(m.group('h')), norm(m.group('t')), [])
            continue
        m1 = RE_H1.match(ln)
        if m1:
            if not seen_h1:
                h1 = norm(m1.group('t')); seen_h1 = True
                continue
            if cur: out.append(cur)
            cur = (1, norm(m1.group('t')), [])
            continue
        if cur is None:
            cur = (0, '', [])
        cur[2].append(ln)
    if cur: out.append(cur)
    return h1, out

def plan_status(text, lines):
    for ln in lines[:60]:
        m = RE_STATUS.search(ln)
        if m and m.group('s').strip():
            return norm(m.group('s')).strip(' *_·|')
        m = RE_STATUS2.match(ln)
        if m and m.group('s').strip():
            return norm(m.group('s')).strip(' *_·|')
    return ""

def strip_quotes(text):
    return "\n".join(l for l in text.splitlines() if not RE_QUOTE.match(l))

def has_words(text, lines):
    """1 · his words, quoted, with a date. A quote is a long span in a blockquote or in
    italics/quotes; the attribution may be the blockquote's own header line."""
    head = "\n".join(lines[:70])
    quoted = [l for l in lines if RE_QUOTE.match(l) and len(norm(l)) >= 30]
    inline = re.findall(r'[*_]{0,2}"([^"]{30,})"[*_]{0,2}', text)
    if not (quoted or inline):
        return False, "no quoted passage"
    if not RE_DATE.search(text):
        return False, "a quote with no date"
    if quoted and RE_ATTRIB.search("\n".join(lines[:80])):
        return True, ""
    if inline and RE_ATTRIB.search(head):
        return True, ""
    if quoted:
        # his words are quoted somewhere in a doc that names him somewhere: fair
        if RE_ATTRIB.search(text):
            return True, ""
        return False, "a quote, but nobody named as its source"
    return False, "an inline quote with no attribution"

def toon_blocks(text):
    """[(name, cols, rows)] — the house's own structured blocks, so a contract stated as
    TOON counts as stated. Reading only prose headings is the spelling mistake again."""
    blocks, cur = [], None
    for ln in text.splitlines():
        m = RE_TOON.match(ln)
        if m:
            if cur: blocks.append(cur)
            cur = (m.group('name'), m.group('cols'), [])
            continue
        if cur is not None:
            if RE_TOON_ROW.match(ln) or ln.strip() == '':
                if RE_TOON_ROW.match(ln): cur[2].append(ln)
            else:
                blocks.append(cur); cur = None
    if cur: blocks.append(cur)
    return blocks

def has_measured(text, secs):
    """2 · a measured section — a heading that says so, or a fence of commands/numbers, or
    a numeric table. Read from the outline, not from a keyword in prose."""
    for lvl, t, body in secs:
        if t and RE_MEASURE.search(t):
            b = "\n".join(body)
            if '```' in b or re.search(r'\d', b):
                return True, ""
    fences, cur = [], None
    for ln in text.splitlines():
        if RE_FENCE.match(ln):
            if cur is None: cur = []
            else: fences.append("\n".join(cur)); cur = None
        elif cur is not None:
            cur.append(ln)
    for f in fences:
        if re.search(r'\b\w[\w./-]*\.(sh|py|mjs)\b|^\s*\$|^\s*[a-z]+ [a-z-]+ --', f, re.M):
            return True, ""
        if len(re.findall(r'\d', f)) >= 6:
            return True, ""
    rows = [l for l in text.splitlines() if RE_TABLEROW.match(l)]
    if len(rows) >= 2 and sum(1 for r in rows if len(re.findall(r'\d', r)) >= 2) >= 2:
        return True, ""
    return False, "no measured section (no numbers, no command, no numeric table)"

def steps_and_proof(text, secs):
    """3 · phases with a proof, read from the OUTLINE.

    A phase is DECLARED — a `Phase N`/`Step N` heading, a `phases[]` TOON block, or the items
    of a `## Phases` section (a table or bullets; plans 69 and 75 do it that way), or, when
    nothing is declared, the numbered sections `## N ·`. A plan with none of these has no
    phases, and saying so is the point.

    The proof may live IN the phases or in a dedicated acceptance/proof section, because that
    is how several plans state 'each ending in something observable' — plan 69's acceptance
    table is the proof for its four phases. Demanding the word in every row would be the
    word-count mistake wearing a different hat."""
    items = []
    for lvl, t, b in secs:
        if t and RE_STEP_H.search(t):
            items.append((t, "\n".join(b)))
    for name, cols, rows in toon_blocks(text):
        if re.search(r'^(phases?|steps?|stages?)$', name, re.I) and rows:
            items += [(name, r) for r in rows]
    # The richest DECLARED set wins, and a thin hit must not pre-empt a fuller one: a single
    # `### Status of P1` heading once swallowed a plan's whole numbered outline because
    # `if not items` stopped looking (found by running the gate on the real shelf).
    if len(items) < 2:
        listed = []
        for lvl, t, b in secs:
            if t and RE_PHASE_H.match(t):
                listed += [(t, x) for x in b if RE_ITEM.match(x)]
        if len(listed) > len(items): items = listed
    if len(items) < 2:
        numbered = [(t, "\n".join(b)) for lvl, t, b in secs if t and RE_NUM_H.match(t)]
        if len(numbered) > len(items): items = numbered
    if len(items) < 2:
        return False, "no phases in the outline (no `Phase N`, no `phases[]`, no `## Phases`, no numbered sections)"

    proven = [i for i in items if RE_PROOF.search(i[1])]
    proof_section = False
    for lvl, t, b in secs:
        if t and RE_PROOF_H.search(t):
            checkrows = [x for x in b if RE_ITEM.match(x) and ('|' in x or RE_PROOF.search(x))]
            if len(checkrows) >= 2:
                proof_section = True; break
    # PHASED and OBSERVABLE — the two halves of 'each ending in something observable'. The
    # proof may sit in the phases or in an acceptance section; the older plans put it there,
    # and the audit itself grants that slack. What a plan may NOT do is sequence work with no
    # way at all to know a step is done.
    if len(proven) >= 2 or proof_section:
        return True, ""
    return False, (f"{len(items)} phases, none proven and no acceptance section "
                   "(a step must end in something observable)")

def has_refusal(secs, text):
    for lvl, t, body in secs:
        if t and RE_REFUSE.search(t):
            return True, ""
    for ln in text.splitlines():
        if re.match(r'^\s*[-*]?\s*\*\*(refus|not doing|out of scope|non-goal)', ln, re.I):
            return True, ""
    if any(re.search(r'refus|non_goal|out_of_scope', b[0], re.I) and b[2] for b in toon_blocks(text)):
        return True, ""
    for ln in text.splitlines():
        if RE_PROHIBIT.search(ln) and not ln.strip().startswith('|'):
            return True, ""
    return False, "no refusal section (nothing it states it will not do)"

def has_questions(secs, text):
    for lvl, t, body in secs:
        if not t or not RE_QUEST.search(t): continue
        b = "\n".join(body)
        if '?' in b or re.search(r'^\s*\d+\.', b, re.M) or re.search(r'^\s*[-*]\s*\*\*Q', b, re.M):
            return True, ""
    if re.search(r'^\s*\*\*Questions?\b', text, re.I | re.M):
        return True, ""
    for name, cols, rows in toon_blocks(text):
        if re.search(r'question|asks?', name, re.I) and rows:
            return True, ""
    return False, "no section of questions that are his"

def opening_sentence(lines):
    """ONE factual sentence, VERBATIM from the plan's own opening — never invented.

    Worked at PARAGRAPH level, not line level: metadata wraps (`**Builds on:** Plan 34 …
    the local voice agent, and the / YouTube latency work behind it.`), so dropping only the
    first line leaves its tail and the row begins mid-thought. A paragraph is skipped when
    it is his quoted words, a heading, a fence, a metadata label, a table, or a task list."""
    META = re.compile(r'^\s*(?:[-*]\s*)?\*{0,2}(status|author|realm|owner|date|opened|ledger|source|'
                      r'law|builds on|relation|lineage|why now|dispatched|context|access record)\b', re.I)
    paras, cur, fence = [], [], False
    for ln in lines[1:90]:
        t = ln.rstrip()
        if t.strip().startswith('```'):
            if cur: paras.append(cur); cur = []
            fence = not fence; continue
        if fence: continue
        if not t.strip():
            if cur: paras.append(cur); cur = []
            continue
        cur.append(t)
    if cur: paras.append(cur)
    for para in paras:
        first = para[0].strip()
        if first.startswith('#') or first.startswith('>') or first.startswith('|'): continue
        if re.match(r'^[-*_]\s*$|^[-*_]{3,}$', first): continue
        if re.match(r'^\s*(?:[-*]\s*\[[ xX]\]|[-*]\s+|\d+\.\s+)', first): continue
        if META.match(first): continue
        p = norm(' '.join(para))
        p = re.sub(r'\*\*|__', '', p)
        p = re.sub(r'`([^`]*)`', r'\1', p)
        p = p.replace('|', '/')
        if len(p) < 40: continue
        m = re.search(r'^(.{40,240}?[.!?])(?:\s|$)', p)
        sent = (m.group(1) if m else p[:200]).strip()
        # a sentence cut inside his quotation leaves a dangling marker; a row must not end on '*\''
        sent = re.sub(r"[\s*'\"\u2018\u2019\u201c\u201d\u2014:,]+$", "", sent)
        return sent
    return "(no prose opening — the plan opens with a quote, a heading or a list)"

def rows_of(readme_lines):
    """Every index row-ish line, with the plan it names and its status token."""
    out = []
    for i, l in enumerate(readme_lines):
        if not (RE_TABLEROW.match(l) or l.startswith('- **')): continue
        names = []
        m = RE_LINK.search(l)
        if m: names.append(os.path.basename(m.group('p').strip()))
        for t in RE_TICKED.findall(l):
            names.append(os.path.basename(t.strip()))
        cells = [c.strip() for c in l.strip().strip('|').split('|')]
        numcell = cells[0].strip('* ') if cells else ''
        status = ''
        for c in cells:
            plain = c.strip('* ').lower()
            for w in STATUS_WORDS:
                if plain == w or plain.startswith(w + ' ') or plain.startswith(w + '—') or plain.startswith(w + ' -'):
                    status = w; break
            if status: break
        if not status:
            # a status may be a parenthetical in the title cell, e.g. "(paused mid-flight)"
            joined = ' '.join(cells).lower()
            mm = re.search(r'\(([^)]{3,80})\)', joined)
            if mm:
                for w in STATUS_WORDS:
                    if re.search(r'\b' + re.escape(w) + r'\b', mm.group(1)):
                        status = w; break
        out.append(dict(line=i + 1, text=l, names=names, numcell=numcell, status=status))
    return out

# ---------------------------------------------------------------- walk the shelf
plans = []
for f in sorted(os.listdir(shelf)):
    if not re.match(r'^\d+.*\.md$', f): continue
    num = int(re.match(r'^(\d+)', f).group(1))
    text = read(os.path.join(shelf, f))
    h1, secs = sections(text)
    plans.append(dict(file=f, num=num, text=text, h1=h1, secs=secs, lines=text.splitlines(),
                      status=plan_status(text, text.splitlines())))

by_num = {}
for p in plans: by_num.setdefault(p['num'], []).append(p)

readme_path = os.path.join(shelf, 'README.md')
readme_lines = read(readme_path).splitlines() if os.path.exists(readme_path) else []
rows = rows_of(readme_lines)

def row_for(p):
    """The row that names this plan. A number-cell match is only evidence when the number is
    NOT shared: with `86` used twice, the switch-games row is not heart's row, and saying so
    would hide the real fault (heart has no row at all)."""
    for r in rows:
        if p['file'] in r['names']: return r
    if len(by_num[p['num']]) == 1:
        for r in rows:
            if r['numcell'] == str(p['num']): return r
    return None

def suffixed_row(p):
    for r in rows:
        if p['file'] in r['names'] and '·' in r['numcell']: return r
    return None

gaps_total = 0
report = []
for p in plans:
    checks = {}
    ok, why = has_words(p['text'], p['lines']);          checks['words'] = (ok, why)
    ok, why = has_measured(p['text'], p['secs']);        checks['measured'] = (ok, why)
    ok, why = steps_and_proof(p['text'], p['secs']);     checks['phases'] = (ok, why)
    ok, why = has_refusal(p['secs'], p['text']);         checks['refuses'] = (ok, why)
    ok, why = has_questions(p['secs'], p['text']);       checks['questions'] = (ok, why)

    # 6 · the number: unique on the shelf, or every twin carries a distinct suffixed row
    twins = by_num[p['num']]
    if len(twins) == 1:
        checks['number'] = (True, "")
    else:
        suffixed = [t for t in twins if suffixed_row(t)]
        distinct = len({suffixed_row(t)['numcell'] for t in suffixed}) == len(suffixed)
        if len(suffixed) == len(twins) and distinct:
            checks['number'] = (True, "")
        else:
            checks['number'] = (False, f"number {p['num']} is used by {len(twins)} files and the index "
                                       f"does not disambiguate them (`{p['num']} · suffix`)")

    # 7 · an index row with a status
    r = row_for(p)
    if r is None:
        checks['row'] = (False, "no README row names this plan")
    elif not r['status']:
        hint = f" (the plan's own header says `{p['status']}`)" if p['status'] else ""
        checks['row'] = (False, f"row at README:{r['line']} carries no status{hint}")
    else:
        checks['row'] = (True, "")

    # an H1 that declares a number must agree with the filename
    m = re.match(r'(?:plan\s+)?(\d+)', p['h1'], re.I)
    if m and int(m.group(1)) != p['num']:
        checks['number'] = (False, f"H1 says plan {m.group(1)}, the filename says {p['num']}")

    bad = [k for k, v in checks.items() if not v[0]]
    gaps_total += len(bad)
    report.append(dict(p, checks=checks, bad=bad))

def tok(ok): return "ok" if ok else "gap"

# ---------------------------------------------------------------- the baseline (a ratchet)
# WHY: the shelf carries 142 historical gaps, so a gate that fails on every one of them would be
# red from the day it lands — and a gate that is red on arrival gets commented out. The audit
# asked for "a check that stops the NEXT 62 from slipping", which is a ratchet: record the shelf
# as it stands once, then fail only when a gap is NEW (or a clean plan goes bad).
gap_map = {}
for r in report:
    for k in r['bad']:
        gap_map.setdefault(r['file'], []).append(k)

def load_baseline():
    if not BASELINE or not os.path.exists(BASELINE): return None
    try:
        return json.load(open(BASELINE, encoding='utf-8'))
    except Exception:
        return None

if mode == 'baseline':
    if not BASELINE:
        print('error: cannot resolve a state directory for the baseline', file=sys.stderr); sys.exit(2)
    os.makedirs(os.path.dirname(BASELINE), exist_ok=True)
    json.dump(dict(shelf=shelf, gaps=gap_map, plans=len(plans), gaps_total=gaps_total),
              open(BASELINE, 'w', encoding='utf-8'), indent=1, sort_keys=True)
    print('plan_audit_baseline[3]{file,plans,gaps}:')
    print('  "%s",%d,%d' % (BASELINE, len(plans), gaps_total))
    print('  "recorded","the shelf as it stands","from here only a NEW gap fails --check"')
    sys.exit(0)

base = load_baseline()
new_gaps = []
if base is None:
    new_gaps = sorted(gap_map)
elif base.get('shelf') != shelf:
    # A baseline is only meaningful for the shelf it was taken on. A DIFFERENT shelf is judged on
    # its own merits (no baseline); --shelf is how the self-test uses a synthetic ledger.
    print('plan_audit[1]{verdict,why}:', file=sys.stderr)
    print('  "NOTE","the recorded baseline belongs to another shelf (%s) — judged without it"'
          % base.get('shelf'), file=sys.stderr)
    base = None
    new_gaps = sorted(gap_map)
else:
    for f, items in gap_map.items():
        old = set(base.get('gaps', {}).get(f, []))
        fresh = [i for i in items if i not in old]
        if fresh: new_gaps.append((f, fresh))

if mode == 'json':
    print(json.dumps(dict(shelf=shelf, plans=len(plans), gaps=gaps_total,
                          baseline=BASELINE if base is not None else None,
                          new_gaps=len(new_gaps), new=new_gaps,
                          rows=[dict(file=r['file'], num=r['num'],
                                     status={k: v[0] for k, v in r['checks'].items()},
                                     why={k: v[1] for k, v in r['checks'].items() if v[1]})
                                for r in report]), indent=1))
    sys.exit(0)

# ---------------------------------------------------------------- --rows: the proposal
if mode == 'rows':
    # A NEW row is only lawful where NO row exists. A row that exists but carries no status is
    # a different fault with a different remedy (it would need a status appended to an existing
    # line), and Rule 06 forbids that being done by guess: report it, do not paper over it.
    rowless = [r for r in report if r['checks']['row'][1].startswith('no README row')]
    print("proposed_rows[%d]{number,plan,row}:" % len(rowless))
    n = 0
    for r in sorted(report, key=lambda x: (x['num'], x['file'])):
        if not r['checks']['row'][1].startswith('no README row'): continue
        numcell = str(r['num'])
        if len(by_num[r['num']]) > 1:
            numcell = f"{r['num']} · {SUFFIX.get(r['file'], re.sub(r'^\\d+-', '', r['file'])[:-3].replace('-', ' ')[:28])}"
        title = re.sub(r'^(PLAN|Plan)\s+\d+\s*[—–-]\s*', '', r['h1']) or r['file']
        title = title.strip()
        sent = opening_sentence(r['lines'])
        raw = re.sub(r'[*_`]', '', r['status']).strip()
        status = re.split(r'\s+[—–-]\s+|\s*·\s*|,', raw)[0].strip().lower()
        status = re.sub(r'\s+', ' ', status)
        if not status or not re.match(r'^[a-z][a-z -]{0,30}$', status): status = 'opened'
        print('  "%s","%s","| %s | [%s](%s) | %s | %s |"' % (numcell, title[:60].replace('"', "'"),
              numcell, title.replace('"', "'"), r['file'], sent.replace('"', "'"), status))
        n += 1
    if n == 0: print('  "—","none","every plan on the shelf carries an index row"')
    sys.exit(0)

# ---------------------------------------------------------------- report / check
print("plan_audit[4]{shelf,plans,gaps,duplicates}:")
dups = sorted(n for n, v in by_num.items() if len(v) > 1)
print('  "%s",%d,%d,"%s"' % (shelf, len(plans), gaps_total,
                            ' · '.join(str(d) for d in dups) if dups else '—'))
print()
print("plans[%d]{num,unique,words,measured,phases,refuses,questions,row}:" % len(report))
for r in sorted(report, key=lambda x: (x['num'], x['file'])):
    c = r['checks']
    print('  "%s",%s,"%s","%s","%s","%s","%s",%s' % (
        r['num'], tok(c['number'][0]), tok(c['words'][0]), tok(c['measured'][0]),
        tok(c['phases'][0]), tok(c['refuses'][0]), tok(c['questions'][0]), tok(c['row'][0])))
print()

if gaps_total:
    print("gaps[%d]{plan,what,detail}:" % gaps_total)
    for r in sorted(report, key=lambda x: (x['num'], x['file'])):
        for k in ('words', 'measured', 'phases', 'refuses', 'questions', 'number', 'row'):
            ok, why = r['checks'][k]
            if ok: continue
            print('  "%s","%s","%s"' % (r['file'], k, why.replace('"', "'")[:150]))
else:
    print('verdict[1]{state}: "every plan on the shelf carries all seven"')

if base is None:
    print()
    print('plan-audit: %d gap(s), and no baseline recorded' % gaps_total)
    print('help: bin/gates/plan-audit.sh --baseline   # accept the shelf as it stands, once')
    print('      then only a NEW gap fails; --rows gives the rows to append (never rewrite one — Rule 06)')
    sys.exit(1 if mode == 'check' else 0)

if new_gaps:
    print()
    print('new_gaps[%d]{plan,what}:' % sum(len(v) if isinstance(v, list) else 1 for _, v in new_gaps))
    for f, items in new_gaps:
        for i in items:
            print('  "%s","%s"' % (f, i))
    print()
    print('plan-audit: %d NEW gap(s) — the ledger went backwards (baseline: %s)'
          % (len(new_gaps), BASELINE))
    sys.exit(1 if mode == 'check' else 0)

print()
print('verdict[3]{state,known_gaps,baseline}:')
print('  "clean","%d known (baseline)","%s"' % (gaps_total, BASELINE))
sys.exit(0)
PY
