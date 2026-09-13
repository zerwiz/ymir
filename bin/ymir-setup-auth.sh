#!/usr/bin/env bash
# ymir-setup-auth.sh — set the operator's Ymir credential at first setup.
#
# Two doors into the gate (apps/hlidskjalf/server):
#   * a local password  -> HLIDSKJALF_AUTH="<user>:<password>" (the gate's own login)
#   * GitHub sign-in     -> GITHUB_CLIENT_ID + GITHUB_CLIENT_SECRET (a GitHub OAuth app;
#                           the gate's /api/auth/github names a login, it never grants
#                           access on its own — an account/invite is still required).
# A secret is never printed or logged; both doors write .env.local (0600, gitignored).
#
# Usage:
#   ymir-setup-auth.sh status                 # which door (if any) is configured
#   ymir-setup-auth.sh set [--user U]         # prompt for an operator password
#   ymir-setup-auth.sh github                 # prompt for a GitHub OAuth app's keys
#   ymir-setup-auth.sh --version | --help
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${YMIR_ENV_FILE:-$ROOT/.env.local}"

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'error: %s\n' "$1" >&2; exit 1; }

env_has() { grep -q "^$1=" "$ENV_FILE" 2>/dev/null; }

# Replace or append a key in .env.local without ever putting the value in argv
# (printf is a shell builtin; the value never reaches a child process's args).
set_env_key() {  # <key> <value>
  local key=$1 val=$2 tmp="" line
  mkdir -p "$(dirname "$ENV_FILE")"
  [ -f "$ENV_FILE" ] || : >"$ENV_FILE"
  chmod 600 "$ENV_FILE" 2>/dev/null || true
  tmp="$(mktemp)" || die "could not create a temp file"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in "$key="*) continue ;; esac
    printf '%s\n' "$line"
  done <"$ENV_FILE" >"$tmp"
  printf '%s=%s\n' "$key" "$val" >>"$tmp"
  mv "$tmp" "$ENV_FILE" || die "could not write $ENV_FILE"
  chmod 600 "$ENV_FILE" 2>/dev/null || true
}

prompt_secret() {  # <prompt> <result-var>
  local prompt=$1 result_var=$2 value=""
  if [ -t 0 ]; then
    printf '%s' "$prompt"
    stty -echo 2>/dev/null || true
    IFS= read -r value || true
    stty echo 2>/dev/null || true
    printf '\n'
  else
    IFS= read -r value || true
  fi
  printf -v "$result_var" '%s' "$value"
}

ACTION="${1:-status}"; shift || true
case "$ACTION" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage; exit 0 ;;
esac

case "$ACTION" in
  status)
    if env_has HLIDSKJALF_AUTH; then
      printf 'auth[1]{door,env,file}:\n  "password","HLIDSKJALF_AUTH","%s"\n' "$ENV_FILE"
    elif env_has GITHUB_CLIENT_ID && env_has GITHUB_CLIENT_SECRET; then
      printf 'auth[1]{door,env,file}:\n  "github","GITHUB_CLIENT_ID+GITHUB_CLIENT_SECRET","%s"\n' "$ENV_FILE"
    else
      printf 'auth[1]{door,env,file}:\n  "none","-","%s"\n' "$ENV_FILE"
    fi
    ;;

  set)
    user="${USER:-operator}"
    while [ $# -gt 0 ]; do case "$1" in --user) user=${2-}; shift 2 ;; *) shift ;; esac; done
    [ -t 0 ] || die "ymir-setup-auth set needs an interactive terminal (or set HLIDSKJALF_AUTH in $ENV_FILE yourself)"
    printf 'Operator username [%s]: ' "$user"; IFS= read -r u || true; [ -n "${u:-}" ] && user="$u"
    prompt_secret 'Password: ' pass
    [ -n "$pass" ] || die "empty password — refusing to set a blank credential"
    prompt_secret 'Confirm:  ' pass2
    [ "$pass" = "$pass2" ] || die "passwords do not match"
    set_env_key HLIDSKJALF_AUTH "$user:$pass"
    printf 'auth[1]{door,set,file}:\n  "password","%s","%s"\n' "$user" "$ENV_FILE"
    printf 'next: restart the gate so it reads the new credential (scripts/stop.sh; scripts/start.sh)\n'
    ;;

  github)
    [ -t 0 ] || die "ymir-setup-auth github needs an interactive terminal"
    printf 'Create a GitHub OAuth app (Settings > Developer settings > OAuth Apps), set its\n'
    printf 'callback to http://127.0.0.1:3889/api/auth/github/callback, then paste:\n\n'
    printf 'Client ID: '; IFS= read -r cid || true
    [ -n "${cid:-}" ] || die "empty client id"
    prompt_secret 'Client secret: ' csec
    [ -n "$csec" ] || die "empty client secret"
    set_env_key GITHUB_CLIENT_ID "$cid"
    set_env_key GITHUB_CLIENT_SECRET "$csec"
    printf 'auth[1]{door,set,file}:\n  "github","GITHUB_CLIENT_ID","%s"\n' "$ENV_FILE"
    if command -v gh >/dev/null 2>&1 && ! gh auth status >/dev/null 2>&1; then
      printf 'hint: run `gh auth login` too — repo access (PRs, deploys) is separate from sign-in.\n'
    fi
    printf 'next: restart the gate (scripts/stop.sh; scripts/start.sh)\n'
    ;;

  *) printf 'error: unknown action %s\nhelp: ymir-setup-auth.sh [status|set|github]\n' "$ACTION" >&2; exit 2 ;;
esac
