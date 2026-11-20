# _common.sh — sourced by every kit hook; not a hook itself.
#
# kit_enter <hook>   stop at once when the kit is already running this hook further up the chain (a repository
#                    hook that calls back into .githooks must not run the kit twice)
# kit_notify         hand a refusal to the project's notice command (scripts/notify.sh); never fails the hook
# kit_chain <hook>   run the repository's own hooks after the kit's (scripts/hooks-chain.sh); stdin passes on
kit_enter() {
  case ":${KIT_HOOK_ACTIVE:-}:" in *":$1:"*) exit 0 ;; esac
  export KIT_HOOK_ACTIVE="${KIT_HOOK_ACTIVE:+$KIT_HOOK_ACTIVE:}$1"
}
kit_notify() {
  if [ -x scripts/notify.sh ]; then bash scripts/notify.sh "$1" "$2" >/dev/null 2>&1
  elif [ -x scripts/notify-arm.sh ]; then bash scripts/notify-arm.sh "$1" "$2" >/dev/null 2>&1
  fi
  return 0
}
kit_chain() {
  local hook="$1"; shift
  [ -f scripts/hooks-chain.sh ] || return 0
  bash scripts/hooks-chain.sh "$hook" "$@"
}
