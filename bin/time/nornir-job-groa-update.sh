#!/usr/bin/env bash
# nornir-job-groa-update.sh — every installation keeps itself current, and it decides HOW from its own home.
#
# THE ASK (the Allfather, 2026-11-08): *"add so all ymir installations runs an auto update nornir job on
# running groa to update latest from main"* — and then the correction that makes it right: *"the update
# needs to spawn an pi agent to run the updates so its beeing made in the way the users need based on
# information they have in ymir home"*.
#
# So this job is a SPAWNER, not a scripted fetch. It:
#   1. reads the home's own facts — this machine's role, its registered Eindri-homes, its branch and
#      dirty state, its opt-out — and writes them into a GENERATED BRIEF (never hand-written, so a fact
#      can never drift from the brief that tells an agent what to do);
#   2. spawns a pi agent headless with that brief as its system prompt and one order;
#   3. the agent decides the road this machine needs — fast-forward the checkout and the homes that are
#      behind, or report a dirty tree, or check only on a branch — by running Gróa, who is still the one
#      door that moves anything;
#   4. the agent's one line is injected into the arm holder's chat and a rune is written when something
#      actually moved.
#
# IF NO AGENT CAN RUN the job falls back to Gróa directly and says which road it took: a machine that
# could not start a brain must still be able to move forward. A silent fallback would hide a broken pi.
#
# LAWS: never force, never reset, never stash, never clean, never merge (Gróa enforces these; the agent
# is told them in its brief). A clean skip is a PASS. YMIR_AUTO_UPDATE=0 disables it on a machine.
#
# Usage: nornir-job-groa-update.sh [--dry] [--no-agent]
# Exit: 0 ran (including every honest skip) · 1 a hard failure · 3 disabled by this machine
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)}"
STATE_DIR="${YMIR_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}"
mkdir -p "$STATE_DIR" 2>/dev/null || true

dry=0; no_agent=0
for a in "$@"; do case "$a" in --dry) dry=1 ;; --no-agent) no_agent=1 ;; esac; done

if [ "${YMIR_AUTO_UPDATE:-1}" = "0" ]; then
  printf 'nornir-groa: disabled on this machine (YMIR_AUTO_UPDATE=0)\n'
  exit 3
fi
GROA="$ROOT/bin/agents/groa-update.sh"
[ -x "$GROA" ] || { printf 'nornir-groa: no updater at %s\n' "$GROA" >&2; exit 1; }

# ── 1 · the facts this machine has, read from its own home ──────────────────────────────────────────
hoard="$(bash -c '. "$1/bin/vault/hoard-lib.sh" >/dev/null 2>&1; ymir_home_root out; printf %s "$out"' _ "$ROOT" 2>/dev/null || true)"
role="$(cd "$ROOT" && timeout 20 bin/skuld/role.sh resolve 2>/dev/null | head -1 || true)"
branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
head_sha="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
dirty="$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
homes="$(grep -cE '^\s*[-*] ' "$hoard/hodd/data/eindri-homes.md" 2>/dev/null || echo 0)"
behind="$(git -C "$ROOT" fetch --quiet origin 2>/dev/null; git -C "$ROOT" rev-list --count HEAD..origin/main 2>/dev/null || echo '?')"
brief="$STATE_DIR/groa-update.brief.md"

# WHICH MODEL: the home's own choice, exactly as the Allfather asked ("in the way the users need based on
# information they have in ymir home"). YMIR_UPDATE_MODEL wins; else the roster's model for `brokk`; else
# nothing, and then the agent road is SKIPPED BY NAME rather than left to a 403 from whatever the harness
# defaults to (measured 2026-11-08: the default provider answered "Key limit exceeded" and the job looked
# like an agent that never started).
model="${YMIR_UPDATE_MODEL:-}"
if [ -z "$model" ] && [ -x "$ROOT/bin/fleet/agents-config.sh" ]; then
  model="$(cd "$ROOT" && timeout 30 bin/fleet/agents-config.sh get brokk model 2>/dev/null | head -1 | tr -d '\r')"
fi
[ -n "$model" ] && ! (cd "$ROOT" && timeout 30 bin/model/catalog.sh --has "$model" >/dev/null 2>&1) && model=""

cat > "$brief" <<EOF
# Brief — you run this machine's update from \`main\`, and you decide the road

You are the scheduled updater for one Ymir home. You have ONE door that may move anything:
\`bin/agents/groa-update.sh\` — Gróa, who fast-forwards this checkout and every registered Eindri-home
from \`main\` and then mends forward. You run her; she does the moving.

## The facts of THIS machine (generated $(date -u +%Y-%m-%dT%H:%M:%SZ), do not trust any other source)

    role            ${role:-unknown}
    checkout        ${ROOT}
    branch          ${branch}
    head            ${head_sha}
    behind main     ${behind} commit(s)
    dirty paths     ${dirty}
    eindri-homes    ${homes} registered in the hoard's hodd/data/eindri-homes.md
    hoard           ${hoard:-unresolved}
    model           ${model:-NONE RESOLVED}
    opt-out         YMIR_AUTO_UPDATE=0 disables this job entirely

## What you may do

- run \`bin/agents/groa-update.sh\` (no flags) — the ONLY way anything moves
- run \`bin/agents/groa-update.sh --check\` when you must not move anything
- read anything under this checkout and the hoard

## What you may NEVER do

- force, reset, stash, clean, rebase, merge, or delete anything — not one of them, not "just this once"
- touch a home that is not registered, or a repository that is not ours
- run a command that changes a machine other than this one
- decide that a dirty tree "probably has nothing important" — a dirty tree is REPORTED, never cleaned

## The road, chosen from the facts above

- dirty paths > 0        → \`--check\` only. Say what is dirty in one clause. Nothing is stashed or moved.
- branch not main        → \`--check\` only, and say the branch. A worktree is working; it is not updated.
- behind = 0             → \`--check\` is enough; say "already current".
- behind > 0, clean, on main → run her. Then say the two shas.
- offline or the fetch failed → say so, and force nothing.

## How you report — this is the whole of your output

ONE line, no prose, no headings, in this exact shape:

    groa: <moved|current|check-only|offline> · <from> → <to> · <one clause on why>

Then deliver it yourself, so the job does not sit waiting on a pane:

    bash bin/agents/eindri-notify.sh --from nornir-auto-update -- "<your line>"

Nothing else. It is injected into the arm holder's chat and carved into the ledger when something moved.
EOF

if [ "$dry" = 1 ]; then
  printf 'nornir-groa: dry — brief written to %s\n' "$brief"
  printf '  role=%s branch=%s head=%s behind=%s dirty=%s homes=%s\n' "${role:-?}" "$branch" "$head_sha" "$behind" "$dirty" "$homes"
  exit 0
fi

order="Run this machine's scheduled update now, following your brief exactly. One line of report."

# ── 2 · spawn the agent; a machine that cannot start a brain still moves ─────────────────────────────
agent_line=""; road=""; out_file="$STATE_DIR/groa-update.out"; err_file="$STATE_DIR/groa-update.err"
rm -f "$out_file" "$err_file"
pi_cmd="pi -p --append-system-prompt $(printf '%q' "$brief") ${model:+--model $(printf '%q' "$model")} $(printf '%q' "$order")"

wait_for_line() {  # <seconds> — poll the output file for the one line the brief demands
  local n=0
  while [ "$n" -lt "$1" ]; do
    grep -qE '^[[:space:]]*groa:' "$out_file" 2>/dev/null && return 0
    sleep 5; n=$((n+5))
  done
  return 1
}

if [ "$no_agent" = 0 ] && [ -z "$model" ]; then
  road="fallback (no model resolved from the home — see config/agents.yaml, or set YMIR_UPDATE_MODEL)"
elif [ "$no_agent" = 0 ] && command -v pi >/dev/null 2>&1; then
  # THE SEAT FIRST, A PLAIN TERMINAL ELSEWHERE (the Allfather, 2026-11-08: *"if herdr not available use
  # a regular terminal"*). A visible seat is preferred because a person can then see what the updater
  # decided; a machine without herdr still gets the same agent in a plain terminal.
  if command -v herdr >/dev/null 2>&1; then
    road="herdr"
    # A TYPED SHELL LINE IS NOT A SPAWN (measured 2026-11-08: the pane showed the escaped command at its
    # prompt and no pi ever started — `printf %q` escaping meets a shell that does not read it). So the
    # invocation goes in a SCRIPT and the pane is told one unquoted word: run it.
    runner="$STATE_DIR/groa-update-run.sh"
    {
      printf '#!/usr/bin/env bash\n'
      printf 'cd %q || exit 1\n' "$ROOT"
      printf 'exec pi -p --append-system-prompt %q' "$brief"
      [ -n "$model" ] && printf ' --model %q' "$model"
      printf ' %q 2>%q | tee %q\n' "$order" "$err_file" "$out_file"
    } > "$runner"
    chmod +x "$runner"
    pane=""
    tab_out="$(timeout 60 herdr tab create --cwd "$ROOT" --label "nornir:auto-update" 2>/dev/null || true)"
    pane="$(printf '%s' "$tab_out" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
r=d.get("result") or d
print((r.get("root_pane") or {}).get("pane_id") or "")' 2>/dev/null)"
    if [ -n "$pane" ]; then
      # A REAL PI AGENT, SEATED AND NAMED — not a print-mode one-shot wearing a pane (measured 2026-11-08:
      # the Allfather watched the pane answer yet saw no agent, because `pi -p` prints and leaves). This is
      # herdr's own shape: start the agent in a shell pane, then PROMPT it — the same road
      # `bin/agents/domain.sh` uses to seat a keeper.
      seat_name="nornir-update"
      # A REAL PI AGENT IN THE PANE — in PRINT MODE, on purpose (measured 2026-11-08, twice):
      # an interactive pi in a scheduled pane stops dead on the MCP trust dialog ("Allow project MCP
      # server 'engram'?"), because the pi-mcp-adapter asks a HUMAN and a 03:41 job is nobody. Print mode
      # declares the project servers blocked, says so, and answers the order — which is exactly the one
      # line this job exists to get. `--mcp-project-servers deny` is kept in case a future build honours it.
      runner="$STATE_DIR/groa-update-run.sh"
      {
        printf '#!/usr/bin/env bash\n'
        printf 'cd %q || exit 1\n' "$ROOT"
        printf 'exec pi -p --model %q --append-system-prompt %q --no-mcp --mcp-project-servers deny -t bash,read %q 2>%q | tee %q\n' \
          "$model" "$brief" "$order" "$err_file" "$out_file"
      } > "$runner"
      chmod +x "$runner"
      timeout 30 herdr pane run "$pane" "bash $runner" >/dev/null 2>&1 || true
      timeout 30 herdr agent rename "$pane" "$seat_name" >/dev/null 2>&1 || true
      printf 'nornir-groa[1]{road,pane,seat,state}:\n  "herdr","%s","%s","a pi agent is seated — it reports its own line"\n' "$pane" "$seat_name"
      exit 0
    fi
    road="terminal (herdr has no pane to give)"
  else
    road="terminal"
  fi

  # the plain terminal — headless, exactly the same brief and order
  if [ -z "$pane" ] || [ "${road#herdr}" != "herdr" ]; then
    # print mode exactly as pi.dev documents it: `pi -p "<prompt>"`, bounded, MCP off (a headless
    # session cannot approve a project MCP server and should not try), tools limited to what the brief allows
    timeout 420 pi -p --model "$model" -t bash,read --no-mcp \
      --append-system-prompt "$brief" "$order" 2>"$err_file" | tail -8 > "$out_file"
  fi
  agent_line="$(grep -E '^[[:space:]]*groa:' "$out_file" 2>/dev/null | tail -1 | sed 's/^[[:space:]]*//')"
  [ -z "$agent_line" ] && road="$road → fallback (no usable line)"
else
  road="fallback (no pi on this machine)"
fi

if [ -z "$agent_line" ]; then
  # THE FALLBACK IS LOUD: a machine that could not start a brain must still move, and must say so.
  before="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  out="$(timeout 900 "$GROA" 2>&1)"; grc=$?
  after="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  moved="no"; [ "$before" != "$after" ] && moved="yes"
  agent_line="groa: $([ "$moved" = yes ] && echo moved || echo current) · $before → $after · $road, Gróa run directly"
  [ "$grc" -ne 0 ] && agent_line="groa: check-only · $before → $after · $road and Gróa exited $grc (nothing forced)"
fi

printf '%s\n' "$agent_line"
printf 'nornir-groa[1]{role,road,line}:\n  "%s","%s","%s"\n' "${role:-unknown}" "$road" "$agent_line"

# ── 3 · the line reaches the holder; the ledger hears it only when something moved ───────────────────
if [ -x "$ROOT/bin/agents/eindri-notify.sh" ]; then
  "$ROOT/bin/agents/eindri-notify.sh" --from "nornir auto-update" -- "$agent_line" >/dev/null 2>&1 || true
fi
case "$agent_line" in
  *moved*) [ -x "$ROOT/bin/records/runes-append.sh" ] && \
    "$ROOT/bin/records/runes-append.sh" nornir groa-update --realm work --message "scheduled update: $agent_line" >/dev/null 2>&1 || true ;;
esac
exit 0
