#!/usr/bin/env bash
# syn-guard-pretool-check.sh - PreToolUse seatbelt for the runtime's load-bearing
# invariants. Best-effort guardrail, NOT a security boundary: bash is too
# expressive to sandbox here, so this denies the few shapes that silently break
# something hard to detect — a hand-tampered lock, a clobbered supervision
# marker, a rewritten audit chain, an edit to the seatbelt itself, a leaked
# secret, or a silent change to a fleet-steering registry.
#
# Owned by the Sýn harness extension; wired beside syn-arm-pretool-check.sh.
# Exit: 0 = allow, 2 = block (stderr carries the reason).
set -u

command_text=""
while [ $# -gt 0 ]; do
  case "$1" in
    --command) command_text=${2-}; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$command_text" ] || exit 0
cmd="$command_text"

deny() { printf 'denied: %s\n' "$1" >&2; exit 2; }

# A destructive shape is one that removes, overwrites, or rewrites a path.
destructive_on() {  # <needle>
  local n=$1
  case "$cmd" in
    *" rm "*"$n"*|*"rm -"*"$n"*|*" mv "*"$n"*|*"mv -"*"$n"*) return 0 ;;
    *"truncate"*"$n"*|*"sed -i"*"$n"*|*"tee "*"$n"*|*"dd "*"$n"*) return 0 ;;
    *"chmod "*"$n"*|*"chown "*"$n"*) return 0 ;;
    *">"*"$n"*) return 0 ;;
  esac
  return 1
}

# Reading a secret is itself the leak.
reads_on() {  # <needle>
  local n=$1
  case "$cmd" in
    *"cat "*"$n"*|*"less "*"$n"*|*"head "*"$n"*|*"tail "*"$n"*) return 0 ;;
    *"grep"*"$n"*|*"rg"*"$n"*|*"printenv"*"$n"*|*"env "*"$n"*) return 0 ;;
  esac
  return 1
}

# 1. The session lock — owned by session-start / lease, never by hand.
for n in 'state/.lock' '.lock-path' 'brokk.lock'; do
  destructive_on "$n" && deny "the session lock ($n) is owned by session-start/lease; do not edit it by hand"
done

# 2. Supervision markers — a stale one silences the turn-end guard.
for n in '.supervision-armed' '.watch.heartbeat' '.watcher-stop' '.wake-queue'; do
  destructive_on "$n" && deny "the supervision marker ($n) is owned by the watcher/drain; do not edit it by hand"
done

# 3. The Runes ledger — an append-only hash chain; rewriting breaks the audit.
for n in 'runes_audit.md' 'runes.lock'; do
  destructive_on "$n" && deny "the Runes ledger ($n) is append-only; write through bin/runes-append.sh"
done

# 4. The seatbelt machinery — never edit what decides your own pass.
for n in 'bin/syn-' '.pi/extensions/' '.opencode/plugins/' '.agents/harness/'; do
  destructive_on "$n" && deny "the guard/extension machinery ($n) is off-limits to a bash mutation; change it through a reviewed commit"
done

# 5. Secrets — never read, echo, or stage them.
for n in '.env.local' '.env.realm' 'auth.json' '.token'; do
  destructive_on "$n" && deny "secrets ($n) must never be written or staged by a shell command"
  reads_on "$n" && deny "secrets ($n) must never be read or echoed by a shell command"
done
case "$cmd" in
  *"git add"*'.env.local'*|*"git add"*'.env.realm'*)
    deny "never stage .env.local / .env.realm"
    ;;
esac

# 6. Fleet-steering registries — route changes through their owning scripts.
for n in 'data/eindri-homes.md' 'workspace/projects.yaml' 'config/cron.yaml'; do
  destructive_on "$n" && deny "the registry ($n) steers the fleet; edit it deliberately, not with a shell rewrite"
done

exit 0
