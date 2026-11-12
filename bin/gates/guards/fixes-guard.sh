#!/usr/bin/env bash
# fixes-guard.sh — the delivery gate reads, and it checks the RECORD.
#
# What it replaces, and why: `changelog-guard` passed if a push range merely
# *touched* CHANGELOG.md — a stray line satisfied it, so it never verified that
# anything was recorded. And the hook in front of it FOLDED fragments into the
# monolith, mutating the tree mid-push and then demanding a commit for the edit it
# had just made.
#
# This gate only READS. A push must carry at least one new fix note
# (`docs/fixes/<component>/<version>-<slug>.md`), and it says which of the push's
# touched paths that note's component covers — a mismatch is reported, never
# silently accepted.
#
#   fixes-guard.sh --install     # seat it as the pre-push hook (replacing the old one)
#   fixes-guard.sh --check       # judge the current branch against its base, by hand
#   git push                     # the hook runs it with the refs on stdin
#
# Override, loudly: YMIR_SKIP_FIXES_GUARD=1
#
# Exit: 0 the record is there, 1 it is not, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
cd "$ROOT" || exit 1

[ "${YMIR_SKIP_FIXES_GUARD:-0}" = 1 ] && { printf 'fixes-guard[1]{gate,result}:\n  "push","skipped (YMIR_SKIP_FIXES_GUARD=1)"\n'; exit 0; }

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --install)
    # ONE HOME FOR THE HOOK TEXT (plan 243, 2026-11-11). This used to generate a SECOND hook
    # body here, and the two drifted: `.githooks/pre-push` ran the tree wards only, while this
    # copy ran the whole chain — so which gates a push met depended on whether the seat had set
    # `core.hooksPath`. Measured that day: the checkout doing the work had no hooksPath, so the
    # generated copy ran and the shipped one was dead text. The shipped file IS the hook; the
    # install copies it, and a missing file is a refusal rather than a silently different gate.
    H="$(git rev-parse --git-path hooks)/pre-push"
    case "$H" in /*) ;; *) H="$ROOT/$H" ;; esac
    mkdir -p "$(dirname "$H")" || exit 1
    SRC="$ROOT/.githooks/pre-push"
    if [ ! -r "$SRC" ]; then
      printf 'error: %s is missing\nhelp: the pre-push hook has one home and it is that file\n' "$SRC" >&2
      exit 1
    fi
    cp "$SRC" "$H" && chmod +x "$H" || exit 1
    # the NDA gate's two hooks (RULES/04, 2026-11-12) ride the same install
    for extra in pre-commit commit-msg; do
      [ -r "$ROOT/.githooks/$extra" ] && cp "$ROOT/.githooks/$extra" "$(dirname "$H")/$extra" && chmod +x "$(dirname "$H")/$extra"
    done
    printf 'fixes-guard[1]{gate,result}:\n  "hook","installed from .githooks/pre-push at %s"\n' "${H#"$ROOT"/}"
    exit 0 ;;
  --check) ;;
  "") ;;
  *) printf 'error: unknown flag %s\nhelp: bin/gates/guards/fixes-guard.sh [--install|--check]\n' "$1" >&2; exit 2 ;;
esac

# ── the judgement ────────────────────────────────────────────────────────────
# Judge each outgoing branch independently; a later ref cannot hide an earlier one.
judge_range() {
  local head_sha="${1:-}" remote_sha="${2:-}" require_record="${3:-0}" base="" range notes touched covered count n c f
[ -n "$head_sha" ] || head_sha="$(git rev-parse HEAD)"

base=""
if [ -n "$remote_sha" ] && [ "$remote_sha" != 0000000000000000000000000000000000000000 ]; then
  base="$remote_sha"
else
  for cand in origin/main main master; do
    git rev-parse --verify -q "$cand" >/dev/null 2>&1 || continue
    base="$(git merge-base "$head_sha" "$cand" 2>/dev/null || true)"
    [ -n "$base" ] && break
  done
fi
if [ -z "$base" ] && [ "$require_record" = 1 ]; then
  base="$(git hash-object -t tree --stdin </dev/null)" || return 1
fi
[ -n "$base" ] || { printf 'fixes-guard[1]{gate,result}:\n  "push","no base to compare — first push of a branch is judged on its own"\n'; return 0; }

range="${base}..${head_sha}"
# The note's name is <version>-<slug>.md, and a version is whatever bin/gates/fixes.sh was
# TOLD it is: `--version=unversioned` is legitimate, and 158 of the repo's notes use
# it. Accepting only a digit-first version made the gate blind to those notes and
# refused every push that carried one (2026-09-25) — the guard demanded a format its
# own writer does not require. A note the gate cannot SEE is a note it cannot judge.
# A MERGE IS NOT A CHANGE: `git diff remote..HEAD` on a branch that merged main drags
# every path main brought into the range, so a correct note could never cover the push
# (measured 2026-11-03 on PR #493). Judge OUR OWN non-merge commits instead.
notes="$(git log --no-merges --diff-filter=A --name-only --format= "$range" 2>/dev/null | grep -E '^docs/fixes/[a-z]+/([0-9]|unversioned-)[^/]*\.md$' || true)"
touched="$(git log --no-merges --name-only --format= "$range" 2>/dev/null | sed '/^$/d' | sort -u | grep -v '^docs/fixes/' | grep -v '^CHANGELOG' || true)"

if [ -z "$notes" ]; then
  # THE DOCUMENT ROAD (RULES/08, appended 2026-11-12): a range that changes documents
  # only, by branch-guard's exact set, owes no fix note — UNLESS it changes a rule. A rule
  # is law, and a change of law keeps its record. branch-guard owns the set; this gate
  # asks it, and with no branch-guard beside it the gate stays strict.
  bg="$SCRIPT_DIR/branch-guard.sh"
  if [ -r "$bg" ] && bash "$bg" --documents "$base" "$head_sha" >/dev/null 2>&1; then
    if git diff --no-renames --name-only "$base" "$head_sha" | grep -q '^RULES/'; then
      printf 'fixes-guard[1]{gate,result}:\n  "push","refused — documents only, but a rule changed and a rule change keeps its fix note"\n' >&2
      printf 'help: bin/gates/fixes.sh record --component=rules --version=unversioned --title="what the rule now says"\n' >&2
      return 1
    fi
    printf 'fixes-guard[1]{gate,result}:\n  "push","ok — documents only; no fix note owed (RULES/08, 2026-11-12)"\n'
    return 0
  fi
  printf 'fixes-guard[1]{gate,result}:\n  "push","refused — no fix note in this range"\n' >&2
  printf 'help: bin/gates/fixes.sh record --component=<%s> --version=<v> --title="what changed"\n' \
    "install|runtime|snotra|skills|agents|hlidskjalf|odrerir|sessrumnir|smidja|hoard|gate" >&2
  printf 'note: a note is a file under docs/fixes/<component>/ — write one, commit it, push again.\n' >&2
  return 1
fi

# The record is there: now say whether it speaks to what the push changed.
# WHAT A PATH IS, so the note that describes it can be recognised.
#
# Until 2026-10-01 this matcher only knew three shapes: a path containing the component's own
# name, a short list of files that happen to spell one, and `.agents/skills/*`. So a note under
# `runtime/` describing `bin/seat/verify-seat.sh` counted as covering NOTHING — and every push that
# carried a correct note still had to be pushed with the loud YMIR_SKIP_FIXES_GUARD=1 override.
# **A gate that must be routinely overridden is a gate nobody trusts**, so the map is explicit now
# rather than clever: a path that names no component is mapped by WHAT IT IS.
path_component() {  # <path> -> the component it belongs to, or empty
  case "$1" in
    systems/snotra/*) echo snotra ;;
    src/ymir_runtime/*|bin/mimir*|bin/records/mimir.sh|bin/seat/verify-seat.sh|bin/time/saga-wake-drain.sh) echo runtime ;;
    tools/mcp-gateway/*|bin/bridge/mcp-gateway.sh|bin/records/journal-*.sh) echo runtime ;;
    bin/bridge/a2a-mcp.sh|bin/bridge/ratatoskr.sh) echo runtime ;;
    bin/engine/ymir-install.sh|bin/agents/groa-update.sh|bin/seat/valknut-load.sh|bin/engine/ymir-migrate.sh) echo install ;;
    .pi/*|.agents/skills/*|bin/agents/skill-find.sh|bin/gates/fixes.sh|bin/gates/guards/fixes-guard.sh) echo agents ;;
    bin/gates/capabilities.sh|bin/gates/inventory.sh|bin/gates/registers.sh|bin/gates/registers-*|bin/gates/queue.sh|bin/gates/ci-verify.sh|bin/gates/checks/*|bin/gates/guards.sh|bin/gates/guards/*|bin/gates/tests/*|bin/no-delete-guard.sh) echo gate ;;
    # The woven catalogue (Þættir) and the derived registers belong to the gate suite:
    # a fix to them is a gate fix (2026-11-03 — they mapped to nothing and a correct
    # note could not cover the push; the same class the 2026-10-12 StartLimit mend found).
    FEATURES.md|docs/features/*) echo gate ;;
    bin/README.md|bin/INDEX.md|bin/*/INDEX.md) echo gate ;;
    .agents/backend/README.md|.agents/assets/agents/capabilities.md|.agents/assets/agents/capabilities/*) echo gate ;;
    # The unit templates and the renderer that seats them: the seat's services, so a fix
    # here is a runtime fix. Before this row tools/{mill,web}/systemd/* mapped to NO
    # component — a correct runtime note covered nothing and the gate passed on a
    # technicality while saying it could not tell. Same defect as the bin/skuld/* row
    # above, found again on 2026-10-12 by the StartLimit mend.
    tools/mill/systemd/*|tools/web/systemd/*|bin/fleet/fleet-ensure.sh|bin/engine/autoboot-lib.sh) echo runtime ;;
    # The registry readers: a fix here is a runtime fix, and before this row
    # bin/skuld/* mapped to NO component — so a correct note under runtime/ covered
    # nothing and the gate passed on a technicality while saying it could not tell.
    bin/skuld/*|bin/agents/project-git.sh) echo runtime ;;
    .agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md|apps/hlidskjalf/*) echo hlidskjalf ;;
    .agents/skills/galdr-ymirsystem/assets/smidja.md|.agents/skills/smidja-factory/*) echo smidja ;;
    .agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md|bin/snotra*|tools/snotra/*) echo snotra ;;
    tools/tickets-mcp/*|bin/desktop/odrerir*|apps/odrerir/*) echo odrerir ;;
    # The forge: worktrees, the sandbox, and now boxes. Before this row bin/forge/* mapped
    # to NO component, so a correct forge note could never cover a forge path and the gate
    # could only warn (2026-11-06, found while shipping the Utgard boxes).
    bin/forge/*|.agents/sandbox/*) echo forge ;;
    # The ward: the hound, its senses and its switch. Before this row bin/ward/* mapped to
    # NO component, so a correct ward note could never cover a ward path — the same defect
    # the forge and bin/skuld rows above fixed (found 2026-11-09 while shipping the switch).
    bin/ward/*|.agents/tests/garmr.test.sh) echo ward ;;
  esac
}
covered=0
for n in $notes; do
  c="$(printf '%s' "${n#docs/fixes/}" | cut -d/ -f1)"
  case "$touched" in
    *"$c"*) covered=$((covered+1)) ;;
    *bin/fixes*|*install*) [ "$c" = install ] && covered=$((covered+1)) ;;
    *bin/ymir*|*bin/sessrumnir*|*bin/smidja*|*bin/npm-publish*|*.agents/skills/*) covered=$((covered+1)) ;;
  esac
  # and: does the note's component own any path this push touched?
  while IFS= read -r f; do
    [ "$(path_component "$f")" = "$c" ] && covered=$((covered+1))
  done <<EOF2
$(printf '%s\n' "$touched" | grep -v '^docs/fixes/')
EOF2
done

count="$(printf '%s\n' "$notes" | grep -c . || true)"
if [ "$covered" -gt 0 ]; then
  printf 'fixes-guard[1]{gate,result}:\n  "push","ok — %s note(s), and the record speaks to the change"\n' "$count"
else
  printf 'fixes-guard[1]{gate,result}:\n  "push","ok — %s note(s); none names a path this range touched"\n' "$count"
  printf 'note: a note for another component is still a record — but say what THIS push changed.\n' >&2
  printf '      components touched: %s\n' "$(printf '%s' "$touched" | head -4 | tr '\n' ' ')" >&2
fi
return 0
}

# Manual --check keeps its original branch/base judgment, even for published tips.
if [ "${1-}" = --check ]; then judge_range "" ""; exit $?; fi
refs="$(cat 2>/dev/null || true)"
if [ -z "$refs" ]; then judge_range "" ""; exit $?; fi
failed=0
while read -r _local local_sha remote_ref remote_sha; do
  [ -n "${local_sha:-}" ] || continue
  case "$remote_ref" in refs/tags/*)
    printf 'fixes-guard: ok — tag pointer %s carries no branch content\n' "$remote_ref"; continue ;;
  esac
  case "$local_sha" in 000000*)
    printf 'fixes-guard: ok — deletion %s carries no content\n' "$remote_ref"; continue ;;
  esac
  # Public commits may be named by another branch without inventing a new fix note.
  # Only already-fetched origin refs establish publication; outgoing siblings do not.
  if unpublished="$(git rev-list -n1 "$local_sha" --not --remotes=origin 2>/dev/null)"; then
    if [ -z "$unpublished" ]; then
      printf 'fixes-guard: ok — %s names only already published commits\n' "$remote_ref"
      continue
    fi
  else
    printf 'fixes-guard: refused — cannot inspect outgoing ref %s\n' "$remote_ref" >&2
    failed=1; continue
  fi
  printf 'fixes-guard: judging outgoing branch %s\n' "$remote_ref"
  judge_range "$local_sha" "${remote_sha:-}" 1 || failed=1
done <<<"$refs"
exit "$failed"
