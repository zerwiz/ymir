#!/usr/bin/env bash
# harness-extensions-install.sh — every harness gets the house's extensions and packages, on install AND on update.
#
#   bin/seat/harness-extensions-install.sh            sync every harness present on this host
#   bin/seat/harness-extensions-install.sh --check     report per harness: current · stale · absent · skip
#
# WHY (RULES/13, 2026-11-02; his word: *"all extentons and packets to all harnesses must come on uptaaes"*).
# Measured that day: the extensions lived only in the checkout, so an agent booted anywhere else had none;
# OpenCode's global AGENTS.md was three weeks stale; and nothing but Pi and OpenCode was refreshed by an update
# at all. A user's agent therefore drifts from the house the moment they pull.
#
# WHAT IT DOES, per harness, from the descriptors in `.agents/harnesses/`:
#   pi        the settings `extensions[]` entry, resolved by realpath (bin/seat/valknut-load.sh --global)
#             AND the one-home door (bin/seat/pi-door.sh) seated as ~/.pi/agent/bin/pi
#   opencode  the plugin set copied into ~/.config/opencode/plugins
#   claude    the hook scripts into ~/.claude/hooks  (the JSON wiring is NAMED, never merged blind)
#   codex     hooks.json and the skills links under ~/.codex
#   cursor    the rules into ~/.cursor/rules
# A harness that is not installed is a clean SKIP with its reason, never a failure (RULES/25).
set -uo pipefail

_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$_d" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"

# A PINNED runtime wins over the working tree (RULES/02 §7): the extensions a harness loads must be the
# ones a deployment proved, not whatever branch an agent left checked out.
# The home is asked of the ONE resolver (Rule 07), never read out of the environment here.
if [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
fi
_pin=""
[ -r "$ROOT/bin/pi/arm-pin-lib.sh" ] && . "$ROOT/bin/pi/arm-pin-lib.sh" 2>/dev/null && arm_pin_dir _pin
if [ -n "$_pin" ] && [ -d "$_pin/.git" ]; then
  ROOT="$_pin"
fi
unset _pin

mode="install"
case "${1:-}" in
  -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --check|check) mode="check" ;;
  ""|install|--install) ;;
  *) printf 'error: unknown action %s\nhelp: harness-extensions-install.sh [--check]\n' "$1" >&2; exit 2 ;;
esac

say() { printf '%s\n' "$*"; }
changed=0; stale=0; absent=0

copy_tree() {  # <src-dir> <dst-dir> <label> — copy only what differs, keep one .bak of anything replaced
  local src=$1 dst=$2 label=$3 n=0
  [ -d "$src" ] || return 0
  mkdir -p "$dst" 2>/dev/null || { say "  \"$label\",\"skip\",\"$dst is not writable\""; return 0; }
  while IFS= read -r f; do
    case "$f" in */node_modules/*|*/__pycache__/*|*.pyc) continue ;; esac
    rel=${f#"$src"/}
    target="$dst/$rel"
    if [ -f "$target" ] && cmp -s "$f" "$target"; then continue; fi
    if [ "$mode" = "check" ]; then
      say "  \"$label\",\"stale\",\"$rel differs from the tree\""; stale=$((stale+1)); return 1
    fi
    mkdir -p "$(dirname "$target")"
    [ -f "$target" ] && cp -p "$target" "$target.bak-$(date -u +%Y%m%d-%H%M%S)" 2>/dev/null
    cp -p "$f" "$target" && n=$((n+1))
  done < <(find "$src" -type f 2>/dev/null)
  [ "$n" -gt 0 ] && { say "  \"$label\",\"synced\",\"$n file(s) into $dst\""; changed=$((changed+1)); }
  return 0
}

printf 'harness_extensions[%s]{harness,state,detail}:\n' 6

# ── pi: the settings entry that makes the extensions load from any directory, and
#        the DOOR that keeps a seat started by hand to ONE home (2026-11-11) ──────
# pi's loader takes `<cwd>/.pi/extensions` AND every directory the settings name, and
# de-duplicates on the resolved path alone — so a hand-started `pi` in one checkout
# while the settings name another loaded 44 colliding extensions and refused them all
# (RULES/13). bin/seat/pi-door.sh is installed as `pi`, first on PATH, and hands such a
# launch one home; everywhere else it hands the launch through untouched.
PI_DOOR_DST="$HOME/.pi/agent/bin/pi"
pi_door_state() {
  [ -f "$ROOT/bin/seat/pi-door.sh" ] && [ -x "$PI_DOOR_DST" ] || { printf 'absent'; return 0; }
  cmp -s "$ROOT/bin/seat/pi-door.sh" "$PI_DOOR_DST" && printf 'current' || printf 'stale'
}
pi_door_seat() {
  mkdir -p "$HOME/.pi/agent/bin" 2>/dev/null || return 1
  cp -p "$ROOT/bin/seat/pi-door.sh" "$PI_DOOR_DST" 2>/dev/null || return 1
  chmod 0755 "$PI_DOOR_DST"
}

# The door must WIN on PATH, not merely exist: measured 2026-11-12, `which -a pi` named the npm and mise
# copies first, so a hand-started pi bypassed the door. One marked block, written to the profile the
# operator's shell reads AND to its interactive rc (which runs later and re-prepends), puts the door's
# directory first. YMIR_PI_DOOR_PATH=print writes nothing and prints the exact block instead.
PI_DOOR_MARK="# >>> ymir pi door >>>"; PI_DOOR_MARK_END="# <<< ymir pi door <<<"
pi_door_block() {
  printf '%s\n%s\n%s\n' "$PI_DOOR_MARK" \
    'case ":$PATH:" in ":$HOME/.pi/agent/bin:"*) ;; *) export PATH="$HOME/.pi/agent/bin:$PATH" ;; esac' "$PI_DOOR_MARK_END"
}
pi_door_files() {  # the profile and rc files this operator's shell reads
  case "${SHELL##*/}" in
    zsh) printf '%s\n' "$HOME/.zprofile" "$HOME/.zshrc" ;;
    *)   printf '%s\n' "$HOME/.profile" "$HOME/.bashrc" ;;
  esac
}
pi_door_path_state() {  # written | absent
  local f any=0
  for f in $(pi_door_files); do
    [ -f "$f" ] && grep -qF "$PI_DOOR_MARK" "$f" 2>/dev/null || { printf 'absent'; return 0; }
  done
  printf 'written'
}
pi_door_path_seat() {  # write the block into each file that lacks it; never rewrite a line of the operator's
  local f
  for f in $(pi_door_files); do
    grep -qF "$PI_DOOR_MARK" "$f" 2>/dev/null && continue
    [ -w "$(dirname "$f")" ] || return 1
    { [ -s "$f" ] && printf '\n'; pi_door_block; } >>"$f" 2>/dev/null || return 1
  done
}

if command -v pi >/dev/null 2>&1; then
  state="current"; detail=""
  if [ "$mode" = "check" ]; then
    if grep -q "$ROOT/.pi/extensions" "$HOME/.pi/agent/settings.json" 2>/dev/null; then
      detail="settings extensions[] → $ROOT/.pi/extensions"
    else
      state="stale"; detail="settings extensions[] does not name this checkout"; stale=$((stale+1))
    fi
  else
    if bash "$ROOT/bin/seat/valknut-load.sh" --global >/dev/null 2>&1; then
      state="synced"; detail="settings extensions[] → $ROOT/.pi/extensions"
    else
      state="skip"; detail="valknut-load could not bind the seat"
    fi
  fi
  case "$(pi_door_state)" in
    current) detail="$detail · one-home door current" ;;
    stale)   if [ "$mode" = "check" ]; then
               detail="$detail · one-home door stale"; stale=$((stale+1)); [ "$state" = current ] && state="stale"
             elif pi_door_seat; then
               # A deploy is a COPY, and nothing re-ran it: measured 2026-11-13 on a second machine, the release
               # carried the fixed door while ~/.pi/agent/bin/pi still held the old rule that read a lone
               # `-e` as ownership — the seat there died of the very conflict this release fixed. Sync
               # re-seats a STALE door, not only an absent one.
               detail="$detail · one-home door re-seated (it was behind the tree)"
             else
               detail="$detail · one-home door STALE and not seatable ($PI_DOOR_DST)"
             fi ;;
    absent)  if [ "$mode" = "check" ]; then
               detail="$detail · one-home door ABSENT (a seat started in another checkout loads two homes)"
               stale=$((stale+1)); [ "$state" = current ] && state="stale"
             elif pi_door_seat; then
               detail="$detail · one-home door seated → $PI_DOOR_DST"
             else
               detail="$detail · one-home door NOT seated ($PI_DOOR_DST is not writable)"
             fi ;;
  esac
  if [ "${YMIR_PI_DOOR_PATH:-}" = print ]; then
    detail="$detail · PATH block (not written):"
    say "  \"pi\",\"$state\",\"$detail\""
    pi_door_block | sed 's/^/    # /'
  else
    case "$(pi_door_path_state)" in
      written) detail="$detail · door first on PATH (profile block written)" ;;
      absent)  if [ "$mode" = "check" ]; then
                 detail="$detail · door NOT first on PATH (no profile block)"
                 stale=$((stale+1)); [ "$state" = current ] && state="stale"
               elif pi_door_path_seat; then
                 detail="$detail · door first on PATH (profile block written: $(pi_door_files | tr '\n' ' '))"
               else
                 detail="$detail · door PATH block NOT written (profile not writable)"
               fi ;;
    esac
    say "  \"pi\",\"$state\",\"$detail\""
  fi
else
  say "  \"pi\",\"absent\",\"no pi on this host\""; absent=$((absent+1))
fi

# ── opencode: the plugin set (guards + the recovered ymir-tools) ──────────────
# ONE home. The source is .agents/harness/opencode/plugins; the deployed copy is
# ~/.config/opencode/plugins. OpenCode also auto-loads <project>/.opencode/plugins,
# so a symlink there registered every guard TWICE (6 plugins, 12 load failures,
# 2026-11-04). Never link the source into a project — deploy it here.
#
# V2 plugins import `@opencode/plugin` (and ymir-tools imports `effect`), so the
# deployed home must be able to resolve them. A missing node_modules is a plugin
# that cannot load at all; install it once, here, rather than failing per file.
if command -v opencode >/dev/null 2>&1; then
  if [ -d "$ROOT/.agents/harness/opencode/plugins" ]; then
    copy_tree "$ROOT/.agents/harness/opencode/plugins" "$HOME/.config/opencode/plugins" "opencode" || true
    if [ "$mode" != "check" ] && command -v npm >/dev/null 2>&1; then
      if [ ! -d "$HOME/.config/opencode/node_modules/@opencode/plugin" ]; then
        ( cd "$HOME/.config/opencode" \
          && { [ -f package.json ] || printf '%s\n' '{"name":"ymir-opencode-plugins","private":true,"type":"module"}' >package.json; } \
          && npm install --no-audit --no-fund --silent @opencode/plugin effect >/dev/null 2>&1 ) \
          && say "  \"opencode-deps\",\"installed\",\"@opencode/plugin + effect in ~/.config/opencode\"" \
          || say "  \"opencode-deps\",\"absent\",\"npm could not install @opencode/plugin (plugins import it and will not load)\""
      fi
    fi
  else
    say "  \"opencode\",\"absent\",\"no .agents/harness/opencode/plugins in this tree\""
  fi
  [ "$mode" = "install" ] && say "  \"opencode\",\"note\",\"the twenty tools come from ymir-tools.ts; loaded by opencode's own config\"" || true
else
  say "  \"opencode\",\"absent\",\"no opencode on this host\""; absent=$((absent+1))
fi

# ── claude: the hook SCRIPTS; the JSON wiring is named, never merged blind ────
if command -v claude >/dev/null 2>&1; then
  copy_tree "$ROOT/.claude/hooks" "$HOME/.claude/hooks" "claude-hooks" || true
  # FOUR user-scope hooks, each wired as ONE NAMED entry in ~/.claude/settings.json, so they
  # serve EVERY project on the machine and never a single repo:
  #   SessionStart  load-agents-md.sh  Claude Code reads CLAUDE.md, never a project's AGENTS.md
  #   PreToolUse    eindri-only.sh      (Agent|Task) workers are Eindri, never Claude subagents
  #   PreToolUse    nda-write.sh        (Write|Edit|MultiEdit) company/client names never enter the public tree (RULES/04)
  #   Stop          ymir-arm.sh         (asyncRewake) the Gná arm reaches a seat in ANY project — OPT-IN
  # The global arm is OPT-IN (2026-11-12): it wakes every Claude session on the machine, in every
  # repository and with whatever permissions it holds, to act on the wake queue — and Gná writes lines
  # derived from inbound mail into that queue. Seated only when YMIR_CLAUDE_GLOBAL_ARM=1 or
  # $YMIR_HOME/config/claude-global-arm reads `on`; inside the house the project hook arms it anyway.
  # An entry whose hook command names the script is current; none is added on install (one
  # backup kept per run) and reported stale on --check. Nothing else in the file moves.
  if [ -f "$ROOT/.claude/hooks/load-agents-md.sh" ]; then
    _arm_opt="off"
    _home=""; command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root _home 2>/dev/null || _home="${YMIR_HOME:-}"
    if [ "${YMIR_CLAUDE_GLOBAL_ARM:-}" = 1 ]; then _arm_opt="on"
    elif [ -r "$_home/config/claude-global-arm" ] && [ "$(tr -d '[:space:]' < "$_home/config/claude-global-arm" 2>/dev/null)" = on ]; then _arm_opt="on"; fi
    _wired="$(python3 - "$HOME/.claude/settings.json" "$mode" "$_arm_opt" <<'PY' 2>/dev/null
import json, os, shutil, sys, datetime
dst, mode, arm_opt = sys.argv[1], sys.argv[2], sys.argv[3]

# (name, event, fragment, entry) — entry is the exact object to append when absent.
desired = [
    ("claude-agents-md", "SessionStart", "load-agents-md.sh", {
        "hooks": [{"type": "command",
                   "command": 'bash "$HOME/.claude/hooks/load-agents-md.sh"', "timeout": 5}]}),
    ("claude-eindri-only", "PreToolUse", "eindri-only.sh", {
        "matcher": "Agent|Task",
        "hooks": [{"type": "command",
                   "command": 'bash "$HOME/.claude/hooks/eindri-only.sh"', "timeout": 10}]}),
    ("claude-nda-write", "PreToolUse", "nda-write.sh", {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [{"type": "command",
                   "command": 'bash "$HOME/.claude/hooks/nda-write.sh"', "timeout": 10}]}),
    ("claude-ymir-arm", "Stop", "ymir-arm.sh", {
        "hooks": [{"type": "command",
                   "command": 'bash "$HOME/.claude/hooks/ymir-arm.sh"',
                   "asyncRewake": True, "timeout": 28800}]}),
]

try:
    doc = json.load(open(dst)) if os.path.exists(dst) else {}
    if not isinstance(doc, dict):
        raise ValueError
except Exception:
    for name, _e, _f, _x in desired:
        print(f"{name}|skip|~/.claude/settings.json does not parse — left untouched")
    raise SystemExit

changed = False
for name, event, frag, entry in desired:
    hooks = doc.get("hooks") if isinstance(doc.get("hooks"), dict) else {}
    entries = hooks.get(event) or []
    if any(frag in (h.get("command") or "") for e in entries for h in (e.get("hooks") or [])):
        print(f"{name}|current|{event} already names {frag}")
        continue
    if name == "claude-ymir-arm" and arm_opt != "on":
        # opt-in: never added unasked, never reported stale; an operator's existing entry is left alone
        print(f"{name}|opt-in|not seated — YMIR_CLAUDE_GLOBAL_ARM=1 or config/claude-global-arm=on seats it")
        continue
    if mode == "check":
        print(f"{name}|stale|no {event} entry names {frag}")
        continue
    doc.setdefault("hooks", {}).setdefault(event, []).append(entry)
    changed = True
    print(f"{name}|wired|one {event} entry added for {frag} (backup kept)")

if changed and mode != "check":
    try:
        if os.path.exists(dst):
            shutil.copy2(dst, dst + ".bak-" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d-%H%M%S"))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        json.dump(doc, open(dst, "w"), indent=2)
        open(dst, "a").write("\n")
    except Exception as exc:
        print(f"claude-hooks|fail|could not write {dst}: {exc}")
PY
)"
    while IFS='|' read -r _hn _hs _hd; do
      [ -n "$_hn" ] || continue
      case "$_hs" in
        wired)   say "  \"$_hn\",\"synced\",\"$_hd\""; changed=$((changed+1)) ;;
        stale)   say "  \"$_hn\",\"stale\",\"$_hd\""; stale=$((stale+1)) ;;
        current) say "  \"$_hn\",\"current\",\"$_hd\"" ;;
        *)       say "  \"$_hn\",\"$_hs\",\"$_hd\"" ;;
      esac
    done <<< "$_wired"
    unset _wired
  fi
  if [ -f "$ROOT/.claude/settings.json" ]; then
    # The house's own hooks live in the PROJECT-scope file, which Claude auto-loads inside this
    # repo; they are deliberately not mirrored into the user file (they name $CLAUDE_PROJECT_DIR).
    # So the honest check is that the file parses — the three user-scope hooks are checked above.
    if [ "$(command -v python3)" ] && python3 - "$ROOT/.claude/settings.json" <<'PY'
import json, sys
json.load(open(sys.argv[1]))
PY
    then
      say "  \"claude-house\",\"current\",\"the house's project-scope hooks parse (auto-loaded in this repo)\""
    else
      say "  \"claude-house\",\"stale\",\"the house's .claude/settings.json does not parse\""
      [ "$mode" = "check" ] && stale=$((stale+1))
    fi
  fi
  # The doors (plan 239 P1): the same MCP set Pi carries, seated through `claude mcp add`.
  if [ -x "$ROOT/bin/bridge/mcp-config.sh" ]; then
    if [ "$mode" = "check" ]; then
      if bash "$ROOT/bin/bridge/mcp-config.sh" claude --check >/dev/null 2>&1; then
        say "  \"claude-mcp\",\"current\",\"the well-door set is seated (no engram)\""
      else
        say "  \"claude-mcp\",\"stale\",\"a Ymir door is missing — bin/bridge/mcp-config.sh claude\""; stale=$((stale+1))
      fi
    elif bash "$ROOT/bin/bridge/mcp-config.sh" claude >/dev/null 2>&1; then
      say "  \"claude-mcp\",\"current\",\"the well-door set is seated (user scope, no engram)\""
    else
      say "  \"claude-mcp\",\"stale\",\"mcp-config.sh claude could not seat every door\""
    fi
  fi
else
  say "  \"claude\",\"absent\",\"no claude on this host\""; absent=$((absent+1))
fi

# ── codex: hooks.json and the skills links ───────────────────────────────────
if command -v codex >/dev/null 2>&1; then
  if [ -f "$ROOT/.codex/hooks.json" ]; then
    if cmp -s "$ROOT/.codex/hooks.json" "$HOME/.codex/hooks.json" 2>/dev/null; then
      say "  \"codex\",\"current\",\"hooks.json matches the tree\""
    elif [ "$mode" = "check" ]; then
      say "  \"codex\",\"stale\",\"hooks.json differs\""; stale=$((stale+1))
    else
      mkdir -p "$HOME/.codex"
      [ -f "$HOME/.codex/hooks.json" ] && cp -p "$HOME/.codex/hooks.json" "$HOME/.codex/hooks.json.bak-$(date -u +%Y%m%d-%H%M%S)"
      cp -p "$ROOT/.codex/hooks.json" "$HOME/.codex/hooks.json" && say "  \"codex\",\"synced\",\"hooks.json\""
    fi
  else
    say "  \"codex\",\"current\",\"no hooks.json in the tree for codex\""
  fi
else
  say "  \"codex\",\"absent\",\"no codex on this host\""; absent=$((absent+1))
fi

# ── zed: skills natively, AGENTS.md natively, context servers by a NAMED merge ─
if command -v zed >/dev/null 2>&1 || [ -d "$HOME/.config/zed" ]; then
  # .agents/skills is Zed's own shelf too, so nothing is copied for skills — it reads the same tree.
  if [ -d "$ROOT/.agents/skills" ]; then
    say "  \"zed\",\"current\",\".agents/skills is Zed's native shelf — nothing to copy\""
  fi
  if [ -f "$HOME/.config/zed/settings.json" ] && python3 - "$HOME/.config/zed/settings.json" <<'PY2' >/dev/null 2>&1
import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if isinstance(d.get("context_servers"), dict) and d["context_servers"] else 3)
PY2
  then
    say "  \"zed\",\"current\",\"context_servers wired in ~/.config/zed/settings.json\""
  else
    say "  \"zed\",\"note\",\"context_servers is empty or absent — a NAMED merge, never blind: the key is context_servers, not mcpServers\""
  fi
else
  say "  \"zed\",\"absent\",\"no zed on this host\""; absent=$((absent+1))
fi

# ── cursor: the rules ────────────────────────────────────────────────────────
if command -v cursor-agent >/dev/null 2>&1 || command -v cursor >/dev/null 2>&1; then
  copy_tree "$ROOT/.cursor/rules" "$HOME/.cursor/rules" "cursor-rules" || true
else
  say "  \"cursor\",\"absent\",\"no cursor on this host\""; absent=$((absent+1))
fi

if [ "$mode" = "check" ] && [ "$stale" -gt 0 ]; then
  say "help: bin/seat/harness-extensions-install.sh (syncs every harness present; never merges a JSON you own)"
  exit 1
fi
if [ "$mode" = "check" ]; then
  printf 'harness_extensions[1]{state}:\n  "current","every harness present on this host carries the tree'"'"'s set"\n'
fi
exit 0
