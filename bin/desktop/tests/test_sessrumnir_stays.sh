#!/usr/bin/env bash
# test_sessrumnir_stays.sh — plan 271 piece 4: the launcher says "up" only when the window STAYED,
# and names the reason when it did not. Proven on a stand-in for Electron: no window, no GPU, no
# real Electron process is ever started here.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
L="$HERE/../sessrumnir-launch.sh"; JS="$HERE/../../../apps/sessrumnir/bin/sessrumnir.js"
# the app wherever it is (the split, 2026-11-19): this tree, else its own home; absent = nothing to prove here
[ -f "$JS" ] || JS="$(bash "$HERE/../../apps/app-path.sh" sessrumnir 2>/dev/null)/bin/sessrumnir.js"
[ -f "$JS" ] || { printf 'skip: Sessrúmnir is not on this machine (bin/apps/apps.sh install sessrumnir)\n'; exit 0; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/root/apps/sessrumnir/bin" "$T/root/apps/sessrumnir/out/main" "$T/state" "$T/fake/electron/dist"
cp "$JS" "$T/root/apps/sessrumnir/bin/"; echo '{"version":"0.0.0"}' > "$T/root/apps/sessrumnir/package.json"
: > "$T/root/apps/sessrumnir/out/main/index.js"
# a package copy (a build and no src/): the stale-build ward (plan 283) passes it — without this file it refused
mkdir -p "$T/root/apps/sessrumnir/out/renderer"; : > "$T/root/apps/sessrumnir/out/renderer/index.html"
# stand-in: stays up for $FAKE_LIFE seconds, then ends by exit code or by a signal
cat > "$T/fake/electron/dist/electron" <<'F'
#!/usr/bin/env node
setTimeout(() => { if (process.env.FAKE_SIGNAL) process.kill(process.pid, process.env.FAKE_SIGNAL); else process.exit(0) },
  Number(process.env.FAKE_LIFE || 1) * 1000)
F
chmod +x "$T/fake/electron/dist/electron"
export SESSRUMNIR_NO_FOCUS=1 YMIR_ROOT_DIR="$T/root" YMIR_STATE_DIR="$T/state" YMIR_ALLOW_WORKTREE_RUNTIME=1 SESSRUMNIR_SKIP_ENSURE=1 \
  SESSRUMNIR_ELECTRON="$T/fake/electron/dist/electron" SESSRUMNIR_STAY_S=3 YMIR_DESK_ROLE=heart \
  YMIR_APPS_HOME="$T/no-apps-home"   # fenced: an installed app's `current` would win over the fixture above
unset YMIR_APP_SESSRUMNIR_DIR
fail=0; ok() { printf 'ok   %s\n' "$1"; }; no() { printf 'FAIL %s\n' "$1"; fail=1; }

out="$(FAKE_LIFE=30 bash "$L" start 2>&1)"; rc=$?
{ [ $rc = 0 ] && grep -q '"up"' <<<"$out"; } && ok "a window that stays is reported up" || no "stay ($rc: $out)"
pkill -f "$T/fake/electron/dist/electron" 2>/dev/null; sleep 1   # kill: a fake electron this test started seconds ago, matched by its temp path — there is no pid to name

: > "$T/state/sessrumnir.log"
out="$(FAKE_LIFE=1 FAKE_SIGNAL=SIGSEGV bash "$L" start 2>&1)"; rc=$?
{ [ $rc = 1 ] && grep -q "did not stay up" <<<"$out"; } && ok "a window that dies in 1s is NOT reported up" || no "die ($rc: $out)"
grep -q "signal=SIGSEGV" "$T/state/sessrumnir.log" && ok "the log names the signal (it was empty before)" || no "log: $(cat "$T/state/sessrumnir.log")"
grep -q "\[launcher\] the window did not stay up" "$T/state/sessrumnir.log" && ok "the launcher wrote its verdict to the log" || no "no launcher line"

# The split (2026-11-19): installed in its own home, the app is three folders below the apps home, not below Ymir.
# The window must still be handed the Ymir tree the launcher runs from (docs/fixes/sessrumnir/2026-11-19-…).
# SESSRUMNIR_JS names a build to prove (a checkout of the app); the default is the app this machine has.
JS2="${SESSRUMNIR_JS:-$JS}"
rel="$T/apps-home/sessrumnir/releases/abc123"
mkdir -p "$rel/bin" "$rel/out/main" "$rel/out/renderer" "$rel/src"
cp "$JS2" "$rel/bin/"; echo '{"version":"0.0.0"}' > "$rel/package.json"; : > "$rel/out/main/index.js"
: > "$rel/src/a.ts"; touch -d '2000-01-01' "$rel/src/a.ts"; : > "$rel/out/renderer/index.html"
cat > "$T/fake/electron/dist/electron" <<'F'
#!/usr/bin/env node
require('fs').writeFileSync(process.env.FAKE_ROOT_OUT, process.env.YMIR_ROOT || '(unset)')
setTimeout(() => process.exit(0), 30000)
F
want="$(cd "$HERE/../../.." && pwd)"
if grep -q isYmirTree "$rel/bin/sessrumnir.js"; then
  : > "$T/state/sessrumnir.log"
  FAKE_ROOT_OUT="$T/root.out" YMIR_APP_SESSRUMNIR_DIR="$rel" bash "$L" start >/dev/null 2>&1
  got="$(cat "$T/root.out" 2>/dev/null)"
  [ "$got" = "$want" ] && ok "from the apps home the window is handed Ymir's tree ($got)" \
    || no "apps-home root: got '$got', want '$want'"
  pkill -f "$T/fake/electron/dist/electron" 2>/dev/null; sleep 1   # kill: the stand-in this test started, matched by its temp path
else
  printf 'skip: this app build predates the root fix (zerwiz/sessrumnir owes it; SESSRUMNIR_JS=<checkout>/bin/sessrumnir.js proves one)\n'
fi
exit $fail
