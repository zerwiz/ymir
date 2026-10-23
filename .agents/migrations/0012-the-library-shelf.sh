#!/usr/bin/env bash
# 0012-the-library-shelf — give an existing home the library's research shelf.
#
# Plan 115 / RULES/35. The door (`bin/records/library.sh research`) creates the shelf on its
# first `keep`, but a home that has never kept anything would show the library as absent —
# and an absent shelf is indistinguishable from an unbuilt feature. So: one shelf, one README
# that says what belongs there and what does not, and the generated INDEX.
#
# Idempotent: nothing is overwritten, nothing is invented, no existing file is touched.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# The home, through the ONE resolver (Rule 07) — never a guessed path.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  # shellcheck source=bin/vault/hoard-lib.sh
  . "$ROOT/bin/vault/hoard-lib.sh"
  YMIR_HOARD_LIB_LOADED=1
fi
HOME_DIR="${YMIR_HOME:-}"
[ -n "$HOME_DIR" ] || ymir_home_root HOME_DIR
if [ -z "$HOME_DIR" ]; then
  echo "0012: no home to seat — nothing touched"
  exit 0
fi

SHELF="$HOME_DIR/hodd/library/research"
mkdir -p "$SHELF"

README="$HOME_DIR/hodd/library/README.md"
if [ ! -f "$README" ]; then
  cat > "$README" <<'MD'
---
kind: index
status: live
verified: 2026-10-23
verified_by: .agents/migrations/0012-the-library-shelf.sh
supersedes:
superseded_by:
grade: unmeasured
aliases: research library · the library of records
canonical: false
origin: plan 115 · RULES/34 · RULES/35
used_by: bin/records/library.sh
sensitivity: internal
owner: brokk
tags: library, research, records
sources:
---

# The library — the corpus and its shelves

One corpus, one contract, one door (plan 115). Every document here carries the header of
`RULES/34`: `kind · status · verified · owner · tags · sources`. Indexes are **rendered**, never
hand-appended.

```
library[1]{shelf,what,rule}:
  "research","what was learned OUTSIDE this house: one episode per question, the finding in our
   own words, every source behind it, filed by date","RULES/35"
```

**Ask it, do not browse it:**

```bash
bin/records/library.sh research list          # what we have learned
bin/records/library.sh research find <words>  # what do we know about X
bin/records/library.sh ask "<words>"          # across doors, features, law, skills, research
```

**What does not belong here:** anything from the vault or an NDA surface (Rule 15 wins), meeting
audio or transcripts (Rule 30), or a page pasted in full — a library of pasted pages is a cache.
MD
fi

# The index is DERIVED: let the door render it (it exits 0 on an empty shelf).
if [ -x "$ROOT/bin/records/library.sh" ]; then
  YMIR_RESEARCH_ROOT="$SHELF" bash "$ROOT/bin/records/library.sh" research index >/dev/null 2>&1 || true
fi

echo "0012: library shelf seated at ${SHELF#"$HOME_DIR"/} ($(find "$SHELF" -name 'note.md' 2>/dev/null | wc -l) episode(s))"
