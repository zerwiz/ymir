#!/usr/bin/env bash
# The ward for plan 248 P2 + P3 — every root agent loads the PINNED runtime, never a working tree, and pi's
# root carries Ymir's extensions and packages. RULES/51: a feature is done when it answers from a session
# opened OUTSIDE the checkout, after a fresh install AND after an update.
#
# Everything runs in a THROWAWAY HOME with two real clones of this repository — the runtime and a working
# tree — and a fake `pi` on PATH (it records `pi install` into the throwaway settings and prints its argv
# otherwise). The real ~/.pi, ~/.claude, ~/.config/opencode and ~/.agents are never read or written: PATH
# holds only the fake and /usr/bin:/bin, and HOME is the throwaway.
#
#   1. the pin is honoured when runtime.env writes "$HOME/…" (the sed reader ignored it — the fault)
#   2. valknut-load --check and harness-extensions-install --check REFUSE a working-tree path and name the remedy
#   3. install binds pi's root to the runtime, installs the descriptor's packages, re-points every root's
#      working-tree path at its twin, and HOLDS a path with no twin
#   4. a session in ~ and in an unrelated project: the root names the runtime's tree, which holds ro · todo ·
#      open-editor; the one-home door hands it through untouched
#   5. a session in the working tree: the door's onehome rule still applies (PR #654 kept coherent)
#   6. an update (a second run, and migration 0022) is idempotent: everything current, no new backup
#   7. nothing pinned: the checkout serves, and says so
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$here/../../.." && pwd)"
ok=0; fail=0
t() { local n=$1; shift; if "$@" >"$W/.out" 2>&1; then ok=$((ok+1)); printf 'ok   %s\n' "$n"; else fail=$((fail+1)); printf 'FAIL %s\n' "$n"; sed -n 1,12p "$W/.out" | sed 's/^/     /'; fi; }
bad() { printf '%s\n' "$*" >&2; return 1; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
H="$W/home"; mkdir -p "$H" "$W/fake" "$W/unrelated/project"

# Two clones of the tree under test, at its HEAD: the pinned runtime and a working tree.
git clone -q --shared "$SRC" "$H/runtime" 2>/dev/null || { echo "FAIL could not clone $SRC"; exit 1; }
git clone -q --shared "$SRC" "$H/ymir" 2>/dev/null
for d in "$H/runtime" "$H/ymir"; do git -C "$d" checkout -q "$(git -C "$SRC" rev-parse HEAD)" 2>/dev/null; done
RT="$H/runtime"; WT="$H/ymir"

# The home, with runtime.env written exactly as the operator writes it: a literal $HOME.
mkdir -p "$H/ymirhome/config"
printf '%s\n' 'YMIR_RUNTIME_DIR="$HOME/runtime"' 'YMIR_RUNTIME_BRANCH="main"' >"$H/ymirhome/config/runtime.env"

# A fake pi: `install <spec>` lands in the throwaway settings; anything else prints its argv.
cat >"$W/fake/pi" <<'FAKE'
#!/usr/bin/env bash
case "${1-}" in
  --version) echo "0.0.0-fake"; exit 0 ;;
  install) python3 - "$2" <<'PY'
import json, os, sys
p = os.path.expanduser("~/.pi/agent/settings.json")
d = json.load(open(p)) if os.path.exists(p) else {}
d.setdefault("packages", [])
if sys.argv[1] not in d["packages"]:
    d["packages"].append(sys.argv[1])
json.dump(d, open(p, "w"), indent=2)
PY
    exit 0 ;;
esac
printf '%s\n' "$@"
FAKE
chmod +x "$W/fake/pi"

# The root configs as the first seat had them on 2026-11-11: every one names the working tree.
mkdir -p "$H/.pi/agent/extensions" "$H/.config/opencode"
cat >"$H/.pi/agent/settings.json" <<EOF
{"defaultProvider":"x","packages":["npm:pi-mcp-adapter"],"extensions":["-builtin:mcp","$WT/.pi/extensions"]}
EOF
cat >"$H/.pi/agent/mcp-adapter.json" <<EOF
{"mcpServers":{"well":{"url":"http://127.0.0.1:8316/mcp/well"},
 "ymir":{"command":"python3","args":["$WT/bin/mcp/ymir-mcp.py"]},
 "errand":{"command":"$WT/.yggdrasil/gone/bin/pi/launch.sh","args":[]}}}
EOF
printf '%s\n' "$WT" >"$H/.pi/agent/extensions/.ymir-root"
cat >"$H/.claude.json" <<EOF
{"projects":{"$WT":{"mcpServers":{}}},"mcpServers":{"ymir":{"type":"stdio","command":"python3","args":["$WT/bin/mcp/ymir-mcp.py"]}}}
EOF
cat >"$H/.config/opencode/opencode.json" <<EOF
{"mcp":{"ymir":{"type":"local","command":["python3","$WT/bin/mcp/ymir-mcp.py"]}}}
EOF

run() {  # <cwd> <cmd…> — inside the throwaway HOME, the fake pi first on a bare PATH
  local cwd=$1; shift
  ( cd "$cwd" && env -i HOME="$H" YMIR_HOME="$H/ymirhome" PATH="$W/fake:/usr/bin:/bin" TERM=dumb "$@" )
}
settings_ext() { python3 -c 'import json,sys;print("\n".join(json.load(open(sys.argv[1])).get("extensions",[])))' "$H/.pi/agent/settings.json"; }
nbak() { find "$H" -maxdepth 4 -name '*.bak-*' -not -path '*/runtime/*' -not -path '*/ymir/*' 2>/dev/null | wc -l | tr -d ' '; }

# ── 1 · the pin, through a literal $HOME ──────────────────────────────────────
case_pin() {
  run "$WT" bash bin/seat/runtime-root.sh >"$W/o" || return 1
  grep -q "\"$(cd "$RT" && pwd -P)\",\"pinned\"" "$W/o" || bad "not pinned: $(cat "$W/o")"
  run "$WT" bash bin/seat/valknut-load.sh --ext-home | grep -q "\"$RT/.pi/extensions\"" \
    || bad "valknut-load still resolves the working tree"
}
t "1 the pin is honoured through a literal \$HOME" case_pin

# ── 2 · the checks refuse a working-tree path, and name the remedy ────────────
case_refuse_valknut() {
  run "$WT" bash bin/seat/valknut-load.sh --check >"$W/o" && bad "valknut-load --check passed a working-tree root"
  grep -q "pi's root names a working tree.*FAIL.*$WT/.pi/extensions" "$W/o" || bad "no working-tree row: $(cat "$W/o")"
  grep -q "remedy.*runtime-root.sh repoint" "$W/o" || bad "the remedy is not named"
}
case_refuse_harness() {
  run "$WT" bash bin/seat/harness-extensions-install.sh --check >"$W/o" && bad "--check passed"
  grep -q '"roots","stale",.*ymir-mcp.py' "$W/o" || bad "the MCP door was not refused: $(cat "$W/o")"
  grep -q '"pi","stale"' "$W/o" || bad "pi's root was not called stale"
  grep -q 'help: bin/seat/harness-extensions-install.sh' "$W/o" || bad "no help line"
}
t "2a valknut-load --check refuses a working-tree root" case_refuse_valknut
t "2b harness-extensions-install --check refuses it on every root" case_refuse_harness

# ── 3 · a fresh install ───────────────────────────────────────────────────────
case_install() {
  run "$WT" bash bin/seat/harness-extensions-install.sh >"$W/install" 2>&1
  settings_ext | grep -qxF "$RT/.pi/extensions" || bad "root does not name the runtime: $(settings_ext)"
  settings_ext | grep -qxF "$WT/.pi/extensions" && bad "the working tree is still named"
  settings_ext | grep -qxF -- "-builtin:mcp" || bad "a flag the operator owns was dropped"
  for p in npm:pi-mcp-adapter npm:pi-web-access npm:@llblab/pi-telegram npm:@juicesharp/rpiv-ask-user-question; do
    grep -qF "\"$p\"" "$H/.pi/agent/settings.json" || bad "package not installed: $p"
  done
  grep -qF "$RT/bin/mcp/ymir-mcp.py" "$H/.pi/agent/mcp-adapter.json" || bad "pi's ymir door not re-pointed"
  grep -qF "$RT/bin/mcp/ymir-mcp.py" "$H/.config/opencode/opencode.json" || bad "opencode's ymir door not re-pointed"
  python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));a=d["mcpServers"]["ymir"]["args"][0];sys.exit(0 if a.startswith(sys.argv[2]) else 1)' \
    "$H/.claude.json" "$RT/" || bad "claude's ymir door not re-pointed"
  grep -qF "\"$WT\"" "$H/.claude.json" || bad "~/.claude.json per-project state was touched"
  grep -q '"roots","held",.*gone/bin/pi/launch.sh' "$W/install" || bad "the twinless path was not held: $(grep roots "$W/install")"
  grep -qF "$WT/.yggdrasil/gone" "$H/.pi/agent/mcp-adapter.json" || bad "a twinless path was guessed at"
  head -1 "$H/.pi/agent/extensions/.ymir-root" | grep -qxF "$(cd "$RT" && pwd -P)" || bad ".ymir-root does not lead with the runtime"
  grep -qxF "$WT" "$H/.pi/agent/extensions/.ymir-root" && bad ".ymir-root still records the working tree"
  return 0
}
t "3 install binds every root to the runtime, installs the packages, holds the twinless" case_install

# The twinless errand path is the operator's to drop; drop it so the later proofs judge Ymir's own writes.
python3 - "$H/.pi/agent/mcp-adapter.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["mcpServers"].pop("errand", None); json.dump(d, open(sys.argv[1], "w"), indent=2)
PY

# ── 4 · a session OUTSIDE the checkout ────────────────────────────────────────
case_outside() {
  local cwd
  for cwd in "$H" "$W/unrelated/project"; do
    run "$cwd" bash "$RT/bin/seat/pi-door.sh" --why | grep -q '"pass","-","this directory carries no .pi/extensions tree"' \
      || bad "the door did not hand a session in $cwd through"
  done
  run "$H" bash "$RT/bin/pi/pi-ensure.sh" status >"$W/o" || bad "pi-ensure status failed outside: $(cat "$W/o")"
  # The root set is read from the descriptor (the one place it is named), never restated here.
  local e set
  set="$(awk '$0=="root_extensions:"{on=1;next} on&&/^  - /{sub(/^  - /,"");print;next} on&&/^[^ ]/{on=0}' "$RT/.agents/harnesses/pi.yaml")"
  [ "$(printf '%s\n' "$set" | grep -c .)" -ge 3 ] || bad "the descriptor names fewer than three root extensions: $set"
  for e in $set; do grep -q "\"$e\",\"present\",\"$RT/.pi/extensions\"" "$W/o" || bad "$e absent from the root"; done
  grep -q '"named","pinned"' "$W/o" || bad "the root settings do not name the runtime's tree"
  run "$W/unrelated/project" bash "$RT/bin/seat/runtime-root.sh" scan >"$W/o" || bad "a root still names a working tree: $(cat "$W/o")"
}
t "4 a session in ~ and in an unrelated project loads the runtime's set" case_outside

# ── 5 · a session in the working tree: the door's onehome rule still holds ────
case_door() {
  run "$WT" bash "$WT/bin/seat/pi-door.sh" --why | grep -q "\"onehome\",\"$(cd "$WT/.pi/extensions" && pwd -P)\"" \
    || bad "the door did not give the working tree one home"
  run "$WT" bash "$WT/bin/seat/pi-door.sh" --list-models >"$W/o"
  head -1 "$W/o" | grep -qx -- '-ne' || bad "discovery not off: $(head -1 "$W/o")"
  grep -qF "$RT/.pi/extensions" "$W/o" && bad "the runtime's tree was loaded beside the working tree"
  grep -qxF "npm:@juicesharp/rpiv-ask-user-question" "$W/o" || bad "the root's packages were not carried"
}
t "5 in the working tree the door keeps ONE home" case_door

# ── 6 · an update: idempotent, migration included ─────────────────────────────
case_update() {
  local before after
  before="$(nbak)"
  run "$RT" bash bin/seat/harness-extensions-install.sh >"$W/o" 2>&1
  grep -q '"roots","current"' "$W/o" || bad "update did not find the roots current: $(grep roots "$W/o")"
  run "$WT" bash .agents/migrations/0022-roots-load-the-runtime.sh >"$W/o" 2>&1 || bad "migration failed"
  grep -q '^0022: done' "$W/o" || bad "migration did not finish: $(cat "$W/o")"
  after="$(nbak)"
  [ "$before" = "$after" ] || bad "an idempotent run wrote $((after-before)) new backup(s)"
  run "$WT" bash bin/seat/harness-extensions-install.sh --check >"$W/o" 2>&1 || bad "--check after update: $(cat "$W/o")"
  run "$WT" bash bin/seat/valknut-load.sh --check | grep -q "pi's root names no working tree.*PASS" || bad "valknut row not PASS"
}
t "6 an update (re-run + migration 0022) leaves every root current, writes nothing new" case_update

# ── 7 · nothing pinned: the checkout serves, and says so ──────────────────────
case_unpinned() {
  rm -f "$H/ymirhome/config/runtime.env"
  run "$WT" bash bin/seat/runtime-root.sh >"$W/o"
  grep -q '"checkout","no runtime pinned' "$W/o" || bad "the fallback did not say so: $(cat "$W/o")"
  run "$WT" bash bin/seat/runtime-root.sh scan >"$W/o"; grep -q 'no runtime is pinned' "$W/o" || bad "scan did not note the fallback"
}
t "7 unpinned: the checkout serves, and the reason is printed" case_unpinned

printf '\n%s passed, %s failed\n' "$ok" "$fail"
[ "$fail" -eq 0 ]
