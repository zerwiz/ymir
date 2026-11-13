#!/usr/bin/env bash
# test_sessrumnir_stays.sh — plan 271 piece 4: the launcher says "up" only when the window STAYED,
# and names the reason when it did not. Proven on a stand-in for Electron: no window, no GPU, no
# real Electron process is ever started here.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
L="$HERE/../sessrumnir-launch.sh"; JS="$HERE/../../../apps/sessrumnir/bin/sessrumnir.js"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/root/apps/sessrumnir/bin" "$T/root/apps/sessrumnir/out/main" "$T/state" "$T/fake/electron/dist"
cp "$JS" "$T/root/apps/sessrumnir/bin/"; echo '{"version":"0.0.0"}' > "$T/root/apps/sessrumnir/package.json"
: > "$T/root/apps/sessrumnir/out/main/index.js"
# stand-in: stays up for $FAKE_LIFE seconds, then ends by exit code or by a signal
cat > "$T/fake/electron/dist/electron" <<'F'
#!/usr/bin/env node
setTimeout(() => { if (process.env.FAKE_SIGNAL) process.kill(process.pid, process.env.FAKE_SIGNAL); else process.exit(0) },
  Number(process.env.FAKE_LIFE || 1) * 1000)
F
chmod +x "$T/fake/electron/dist/electron"
export SESSRUMNIR_NO_FOCUS=1 YMIR_ROOT_DIR="$T/root" YMIR_STATE_DIR="$T/state" YMIR_ALLOW_WORKTREE_RUNTIME=1 SESSRUMNIR_SKIP_ENSURE=1 \
  SESSRUMNIR_ELECTRON="$T/fake/electron/dist/electron" SESSRUMNIR_STAY_S=3 YMIR_DESK_ROLE=heart
fail=0; ok() { printf 'ok   %s\n' "$1"; }; no() { printf 'FAIL %s\n' "$1"; fail=1; }

out="$(FAKE_LIFE=30 bash "$L" start 2>&1)"; rc=$?
{ [ $rc = 0 ] && grep -q '"up"' <<<"$out"; } && ok "a window that stays is reported up" || no "stay ($rc: $out)"
pkill -f "$T/fake/electron/dist/electron" 2>/dev/null; sleep 1   # kill: a fake electron this test started seconds ago, matched by its temp path — there is no pid to name

: > "$T/state/sessrumnir.log"
out="$(FAKE_LIFE=1 FAKE_SIGNAL=SIGSEGV bash "$L" start 2>&1)"; rc=$?
{ [ $rc = 1 ] && grep -q "did not stay up" <<<"$out"; } && ok "a window that dies in 1s is NOT reported up" || no "die ($rc: $out)"
grep -q "signal=SIGSEGV" "$T/state/sessrumnir.log" && ok "the log names the signal (it was empty before)" || no "log: $(cat "$T/state/sessrumnir.log")"
grep -q "\[launcher\] the window did not stay up" "$T/state/sessrumnir.log" && ok "the launcher wrote its verdict to the log" || no "no launcher line"
exit $fail
