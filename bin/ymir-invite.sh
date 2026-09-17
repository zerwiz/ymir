#!/usr/bin/env bash
# ymir-invite — hand someone a way in to your Ymir, and take it back.
#
# One operator owns the instance; an invite code is how someone else is let in
# to try it. Codes are machine state (never in the repo), each with its own
# ceiling, and registration is closed when no live code exists.
#
#   ymir-invite mint [--limit N]   print a new code (default ceiling: 5)
#   ymir-invite list               every code, and how much of it is spent
#   ymir-invite revoke <CODE>      take a code back, now
#   ymir-invite where              where the accounts live on this machine
#   ymir-invite ensure             mint only if none is live (used by the installer)
#
# The accounts themselves are read and written by the gate's own store module,
# so there is one definition of what an account and an invite are.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Where an app lives: apps/<surface> in a clone, node_modules/@zerwiz/<pkg> in an
# npm install — both shapes, one resolver (bin/app-lib.sh).
if [ -z "${YMIR_APP_LIB_LOADED:-}" ]; then
  _ya="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yac in "$_ya/app-lib.sh" "$(dirname "$_ya")/bin/app-lib.sh"; do
    [ -r "$_yac" ] && { . "$_yac"; YMIR_APP_LIB_LOADED=1; break; }
  done
  unset _ya _yac
fi
app_dir hlidskjalf APP_HLIDSKJALF || APP_HLIDSKJALF=""

MODULE="$APP_HLIDSKJALF/server/accounts.ts"
STORE="$APP_HLIDSKJALF/server/accounts.ts" # absolute: one definition of an account, wherever this is run from

die() { printf 'ymir-invite: %s\n' "$1" >&2; exit 1; }

command -v bun >/dev/null 2>&1 || die "bun is required (bin/ymir-install.sh installs it)"

# A tiny bun program per action — the module is the single source of truth.
accounts() {
  ( cd "$APP_HLIDSKJALF" && bun -e "$1" )
}

[ -f "$MODULE" ] || die "the account store module is missing: $MODULE"

action="${1:-}"
case "$action" in
  mint)
    limit=5
    shift || true
    while [ $# -gt 0 ]; do
      case "$1" in
        --limit) limit="${2:?--limit needs a number}"; shift 2 ;;
        *) die "unknown option: $1" ;;
      esac
    done
    [[ "$limit" =~ ^[0-9]+$ ]] || die "--limit must be a number"
    accounts "import { addInvite, STORE } from '$STORE';
      const i = addInvite($limit);
      console.log('invite[1]{code,limit,store}:');
      console.log(\`  \"\${i.code}\",\${i.limit},\"\${STORE}\"\`);
      console.error(\`\nShare it: it admits \${i.limit} account(s), then it is spent.\`);"
    ;;

  list)
    accounts "import { listInvites, listAccounts } from '$STORE';
      const inv = listInvites(), acc = listAccounts();
      console.log(\`invites[\${inv.length}]{code,used,limit,state}:\`);
      for (const i of inv) console.log(\`  \"\${i.code}\",\${i.used},\${i.limit},\"\${i.used >= i.limit ? 'spent' : 'live'}\"\`);
      console.log(\`accounts[\${acc.length}]{login,created}:\`);
      for (const a of acc) console.log(\`  \"\${a.login}\",\"\${a.created}\"\`);"
    ;;

  revoke)
    code="${2:-}"; [ -n "$code" ] || die "usage: ymir-invite revoke <CODE>"
    accounts "import { revokeInvite } from '$STORE';
      const gone = revokeInvite('$code');
      console.log(\`revoke[1]{code,removed}:\n  \"$code\",\${gone}\`);"
    ;;

  where)
    accounts "import { STORE, CONFIG_DIR } from '$STORE';
      console.log(\`store[1]{path,dir}:\n  \"\${STORE}\",\"\${CONFIG_DIR}\"\`);"
    ;;

  ensure)
    # Mint one only when nothing is live — so the installer is idempotent and
    # never quietly grows a pile of codes.
    accounts "import { addInvite, invitesOpen, listInvites, STORE } from '$STORE';
      if (invitesOpen()) {
        const live = listInvites().filter(i => i.used < i.limit);
        console.log(\`invite[\${live.length}]{code,used,limit}:\`);
        for (const i of live) console.log(\`  \"\${i.code}\",\${i.used},\${i.limit}\`);
      } else {
        const i = addInvite();
        console.log('invite[1]{code,limit,store}:');
        console.log(\`  \"\${i.code}\",\${i.limit},\"\${STORE}\"\`);
      }"
    ;;

  ""|-h|--help|help)
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    ;;

  *) die "unknown action: $action (try: mint, list, revoke, where, ensure)" ;;
esac
