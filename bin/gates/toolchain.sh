#!/usr/bin/env bash
# toolchain.sh — the provider wrappers (W0033). A typed front door to the tools
# the fleet provisions and deploys with, so agents call one CLI, never ad-hoc
# vendor commands. The registry of purposes is `workspace/config/toolchain.md`.
#
# Usage:
#   toolchain.sh list
#   toolchain.sh status
#   toolchain.sh run <provider> [args...]
#   toolchain.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; }

CMD="${1-}"; shift || true
case "$CMD" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage; exit 0 ;;
esac

# provider|cli|purpose|auth-check
TABLE="
supabase|supabase|Postgres, auth, edge functions|supabase projects list
firebase|firebase|hosting, functions, firestore|firebase projects:list
pocketbase|pocketbase|single-file backend|pocketbase --version
vercel|vercel|frontend deploy|vercel whoami
netlify|netlify|frontend deploy|netlify status
expo|expo|React Native builds|expo whoami
stripe|stripe|payments|stripe config --list
github|gh|SCM, PRs, secrets|gh auth status
cloudflare|cloudflared|tunnel, DNS|cloudflared --version
docker|docker|sandboxes, images|docker info
podman|podman|sandboxes, images|podman info
pm2|pm2|process supervision|pm2 pid all
"

rows() { printf '%s\n' "$TABLE" | sed '/^$/d'; }

case "$CMD" in
  list)
    printf 'providers[%s]{provider,cli,purpose,present}:\n' "$(rows | wc -l | tr -d ' ')"
    rows | while IFS='|' read -r p cli purpose _; do
      present=$(command -v "$cli" >/dev/null 2>&1 && echo yes || echo no)
      printf '  "%s","%s","%s","%s"\n' "$p" "$cli" "$purpose" "$present"
    done
    ;;

  status)
    printf 'providers[%s]{provider,cli,present,auth}:\n' "$(rows | wc -l | tr -d ' ')"
    rows | while IFS='|' read -r p cli purpose check; do
      if command -v "$cli" >/dev/null 2>&1; then
        if $check >/dev/null 2>&1; then auth=ok; else auth=unauth; fi
        printf '  "%s","%s","yes","%s"\n' "$p" "$cli" "$auth"
      else
        printf '  "%s","%s","no","%s"\n' "$p" "$cli" "install: $cli"
      fi
    done
    ;;

  run)
    p=${1-}; shift || true
    [ -n "$p" ] || { printf 'error: run needs a provider\nhelp: bin/toolchain.sh run <provider> [args...]\n' >&2; exit 2; }
    line=$(rows | awk -F'|' -v p="$p" '$1==p{print; exit}')
    [ -n "$line" ] || { printf 'error: unknown provider %s\nhelp: bin/toolchain.sh list\n' "$p" >&2; exit 2; }
    cli=$(printf '%s' "$line" | cut -d'|' -f2)
    command -v "$cli" >/dev/null 2>&1 || { printf 'error: %s CLI not installed\nhelp: install %s first\n' "$p" "$cli" >&2; exit 1; }
    exec "$cli" "$@"
    ;;

  *) printf 'error: unknown command %s\nhelp: bin/toolchain.sh [list|status|run|--version]\n' "$CMD" >&2; exit 2 ;;
esac
