#!/usr/bin/env bash
# test_in_call.sh — the in-a-call guard, against a stand-in sound server (no real audio touched).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; G="$HERE/../in-call.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
cat > "$T/bin/pactl" <<'P'
#!/usr/bin/env bash
case "$*" in
 "list source-outputs") cat "$FAKE_OUTS" ;;
 "list short sources") printf '1\talsa_input.pci-0\tPipeWire\n2\tbluez_input.AA_BB.0\tPipeWire\n3\talsa_output.x.monitor\tPipeWire\n' ;;
esac
P
chmod +x "$T/bin/pactl"
export PATH="$T/bin:$PATH" FAKE_OUTS="$T/outs" YMIR_DESK_ROLE=dev
fail=0; ok() { printf 'ok   %s\n' "$1"; }; no() { printf 'FAIL %s\n' "$1"; fail=1; }
: > "$T/outs"
"$G" check >/dev/null 2>&1 && ok "free when nothing captures" || no "free when nothing captures"
printf 'Source Output #7\n\tSource: 2\n\tProperties:\n\t\tapplication.name = "Discord"\n' > "$T/outs"
out="$("$G" check --what "the voice engine" 2>&1)"; rc=$?
{ [ $rc = 3 ] && grep -q Discord <<<"$out"; } && ok "held mic refused, holder named" || no "held mic refused ($rc: $out)"
"$G" check --now >/dev/null 2>&1 && ok "--now passes" || no "--now passes"
YMIR_DESK_ROLE=heart "$G" check >/dev/null 2>&1 && ok "a heart has no desk" || no "a heart has no desk"
"$G" bluetooth && ok "bluetooth source seen" || no "bluetooth source seen"
printf 'Source Output #8\n\tSource: 3\n\tProperties:\n\t\tapplication.name = "peak meter"\n' > "$T/outs"
"$G" check >/dev/null 2>&1 && ok "a monitor tap is not a call" || no "a monitor tap is not a call"
printf 'Source Output #9\n\tSource: 1\n\tProperties:\n\t\tapplication.name = "@zerwiz/rodd"\n' > "$T/outs"
"$G" check >/dev/null 2>&1 && ok "Rödd's own window is not a call" || no "Rödd's own window is not a call"
exit $fail
