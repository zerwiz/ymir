#!/usr/bin/env bash
# test_hypr_door_guard.sh — the ward that keeps every Hyprland act in display-lib.sh (plan 341.2).
#
#   1 · the real tree is clean (the accept line of 341.2)
#   2 · a direct `hyprctl dispatch` in a script under bin/ is refused and named by file and line
#   3 · `keyword`, `eval` and `reload` are acts too, in scripts/ as well as bin/
#   4 · a comment may name the words; a written waiver (`hypr-door-ok:`) lets one line stand
#   5 · the owner itself, and documents, are not judged
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
G="$REPO/bin/gates/guards/hypr-door-guard.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }

# 1
if bash "$G" --repo "$REPO" >/dev/null 2>&1; then ok "the tree is clean"; else bad "the tree is not clean: $(bash "$G" --repo "$REPO" 2>&1 | head -3)"; fi

# a scratch repository
R="$T/r"; mkdir -p "$R/bin/desktop" "$R/scripts" "$R/docs"
git -C "$R" init -q
printf '#!/usr/bin/env bash\nhyprctl dispatch "hl.dsp.focus({})"\n' >"$R/bin/desktop/display-lib.sh"
printf '#!/usr/bin/env bash\n# hyprctl dispatch workspace 3 is named in a comment\necho fine\n' >"$R/bin/desktop/ok.sh"
printf 'Run `hyprctl keyword general:gaps_in 5` to see it refused.\n' >"$R/docs/note.md"
git -C "$R" add -A >/dev/null
if bash "$G" --repo "$R" >/dev/null 2>&1; then ok "the owner, a comment and a document are not judged"; else bad "a clean scratch tree was refused"; fi

# 2
printf '#!/usr/bin/env bash\necho a\nhyprctl dispatch focuswindow "address:$a"\n' >"$R/bin/desktop/bad.sh"
git -C "$R" add bin/desktop/bad.sh
out="$(bash "$G" --repo "$R" 2>&1)"; rc=$?
[ $rc = 1 ] && [[ "$out" == *"bin/desktop/bad.sh:3"* ]] && ok "a direct dispatch is refused and named by file:line" || bad "a direct dispatch passed (rc=$rc)"
git -C "$R" rm -q -f bin/desktop/bad.sh

# 3
for act in 'keyword general:gaps_in 5' 'eval "hl.config({})"' 'reload'; do
  printf '#!/usr/bin/env bash\nhyprctl %s >/dev/null\n' "$act" >"$R/scripts/act.sh"
  git -C "$R" add scripts/act.sh
  bash "$G" --repo "$R" >/dev/null 2>&1; rc=$?
  [ $rc = 1 ] && ok "hyprctl ${act%% *} in scripts/ is refused" || bad "hyprctl ${act%% *} passed"
done
git -C "$R" rm -q -f scripts/act.sh

# 4
mkdir -p "$R/scripts"
printf '#!/usr/bin/env bash\nhyprctl reload  # hypr-door-ok: a fixture that must reload the compositor itself\n' >"$R/scripts/waived.sh"
git -C "$R" add scripts/waived.sh
bash "$G" --repo "$R" >/dev/null 2>&1 && ok "a written waiver lets one line stand" || bad "the waiver was ignored"

# reads are not acts
printf '#!/usr/bin/env bash\nhyprctl clients -j | head\nhyprctl monitors -j\n' >"$R/scripts/read.sh"
git -C "$R" add scripts/read.sh
bash "$G" --repo "$R" >/dev/null 2>&1 && ok "a read (clients, monitors) is not an act" || bad "a read was refused"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
