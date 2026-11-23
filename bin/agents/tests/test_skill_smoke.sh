#!/usr/bin/env bash
# test_skill_smoke.sh — plan 350 D: a skill that names a door that is gone, or a CLI verb its help no longer offers,
# is GONE; a skill whose commands all stand is ok; a skill naming none is `none`. Nothing a skill names is run.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/shelf/good" "$T/shelf/stale" "$T/shelf/quiet" "$T/shelf/verb" "$T/bin"
printf -- '---\ndescription: x\n---\nRun `bin/agents/skill-smoke.sh` and `bash bin/agents/veil.sh send`.\n' >"$T/shelf/good/SKILL.md"
printf -- '---\ndescription: x\n---\nRun `bin/brokk-gone-door.sh` first.\n' >"$T/shelf/stale/SKILL.md"
printf -- '---\ndescription: x\n---\nJust read the room.\n' >"$T/shelf/quiet/SKILL.md"
printf -- '---\ndescription: x\n---\nList them: `forge teams`, then `forge sessions`.\n' >"$T/shelf/verb/SKILL.md"
printf '#!/usr/bin/env bash\nprintf "usage: forge sessions [N] | team list\\n"\n' >"$T/bin/forge"; chmod +x "$T/bin/forge"
echo "test_skill_smoke"
out="$(PATH="$T/bin:$PATH" SKILL_SMOKE_CLIS=forge bash "$root/bin/agents/skill-smoke.sh" --shelf "$T/shelf" 2>&1)"; rc=$?
[ "$rc" = 1 ] && ok "a shelf with a gone command is red" || bad "rc=$rc"
printf '%s' "$out" | grep -q '"good","ok",2' && ok "a skill whose doors stand is ok" || bad "good: $out"
printf '%s' "$out" | grep -q '"stale","GONE",1,"bin/brokk-gone-door.sh"' && ok "a door that is gone is named" || bad "stale"
printf '%s' "$out" | grep -q '"quiet","none",0' && ok "a skill naming no command is a note, not a fault" || bad "quiet"
printf '%s' "$out" | grep -q '"verb","GONE",2,"forge teams"' && ok "a renamed CLI verb is caught (teams, where help offers team list)" || bad "verb: $out"
mv "$T/shelf/stale" "$T/stale.off"; mv "$T/shelf/verb" "$T/verb.off"
PATH="$T/bin:$PATH" SKILL_SMOKE_CLIS=forge bash "$root/bin/agents/skill-smoke.sh" --shelf "$T/shelf" >/dev/null 2>&1 && ok "a clean shelf is green" || bad "clean shelf red"
echo "test_skill_smoke: $pass passed, $fail failed"
[ "$fail" = 0 ]
