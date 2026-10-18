#!/usr/bin/env bash
# app-folder.test.sh — Rule 23's ward: an application's folder is not a toolbox, and the
# commons is not per-app.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
G="$ROOT/bin/gates/guards/app-folder-guard.sh"
fail=0; ok() { printf 'ok - %s\n' "$1"; }; bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin/seat" "$T/RULES" "$T/apps/alpha" "$T/apps/beta/midgard/design-system" "$T/apps/beta/apps"
printf 'x\n' >"$T/RULES/01-x.md"; printf 'x\n' >"$T/apps/alpha/README.md"
printf 'x\n' >"$T/apps/beta/midgard/design-system/tokens.css"

YMIR_GUARD_ROOT="$T" bash "$G" check >/dev/null 2>&1 && bad "a midgard/ inside an app passed" || ok "a shared-commons folder inside an app FAILS"
YMIR_GUARD_ROOT="$T" bash "$G" check 2>&1 | grep -q 'shared-commons folder inside apps' && ok "…and it is named as such" || bad "the finding is not named"
YMIR_GUARD_ROOT="$T" bash "$G" check 2>&1 | grep -q 'apps/ folder inside an app' && ok "…and a nested apps/ is named too" || bad "nested apps/ not named"

rm -rf "$T/apps/beta"; mkdir -p "$T/apps/beta"
YMIR_GUARD_ROOT="$T" bash "$G" check >/dev/null 2>&1 && ok "clean apps pass" || bad "a clean apps tree was refused"
mkdir -p "$T/apps/beta"; printf 'x\n' >"$T/apps/beta/desktop-place.sh"
YMIR_GUARD_ROOT="$T" bash "$G" check >/dev/null 2>&1 && bad "a layer tool inside apps passed" || ok "a layer's tool inside an app FAILS"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"; exit "$fail"
