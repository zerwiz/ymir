#!/usr/bin/env bash
# github-deploy.sh — zero-trust deploys (W0035). Sync secrets from the local env
# into GitHub (never into commits), dispatch a deploy workflow, and watch runs.
# Requires the `gh` CLI, authenticated. Galdr-style TOON.
#
# Usage:
#   github-deploy.sh secrets [--env staging|production] [--repo owner/name] [--project <id>]
#   github-deploy.sh dispatch <staging|production> [--repo owner/name] [--project <id>]
#   github-deploy.sh status [--repo owner/name] [--project <id>]
#   github-deploy.sh --version
#
# Secrets synced (only those present in .env.local):
#   NETLIFY_AUTH_TOKEN NETLIFY_SITE_ID VERCEL_TOKEN GITHUB_TOKEN TELEGRAM_BOT_TOKEN
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# The operator's settings and secrets live in the home they chose, never in the
# code tree — a packaged install replaces its tree on upgrade, and a credential
# must never sit in a tree that ships (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_settings_dir YMIR_SETTINGS_DIR
hoard_local_env YMIR_ENV_FILE
ENV_FILE="${BROKK_ENV_FILE:-$YMIR_ENV_FILE}"
SECRETS="NETLIFY_AUTH_TOKEN NETLIFY_SITE_ID VERCEL_TOKEN GITHUB_TOKEN TELEGRAM_BOT_TOKEN"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

CMD="${1-}"; shift || true
command -v gh >/dev/null 2>&1 || { printf 'error: gh not installed\nhelp: install the GitHub CLI\n' >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { printf 'error: gh not authenticated\nhelp: gh auth login\n' >&2; exit 1; }

REPO=""; ENVIRONMENT=""; PROJ=""
ARGS=()
while [ $# -gt 0 ]; do case "$1" in
  --repo) REPO=${2-}; shift 2 ;;
  --project) PROJ=${2-}; shift 2 ;;
  --env) ENVIRONMENT=${2-}; shift 2 ;;
  *) ARGS+=("$1"); shift ;;
esac; done
if [ -n "$PROJ" ] && [ -x "$SCRIPT_DIR/project-git.sh" ]; then
  REPO="$("$SCRIPT_DIR/project-git.sh" "$PROJ" --field owner)/$("$SCRIPT_DIR/project-git.sh" "$PROJ" --field repo)"
fi
REPO_ARG=(); [ -n "$REPO" ] && REPO_ARG=(--repo "$REPO")

case "$CMD" in
  secrets)
    [ -r "$ENV_FILE" ] || { printf 'error: env file not found: %s\nhelp: put the secrets in .env.local\n' "$ENV_FILE" >&2; exit 1; }
    printf 'secrets[%s]{name,scope,status}:\n' "$(echo "$SECRETS" | wc -w | tr -d ' ')"
    for s in $SECRETS; do
      v=$(grep -E "^${s}=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2-)
      if [ -z "$v" ]; then printf '  "%s","%s","absent-in-env"\n' "$s" "${ENVIRONMENT:-repo}"; continue; fi
      if [ -n "$ENVIRONMENT" ]; then
        printf '%s' "$v" | gh secret set "$s" --env "$ENVIRONMENT" "${REPO_ARG[@]}" >/dev/null 2>&1 && printf '  "%s","%s","set"\n' "$s" "$ENVIRONMENT" || printf '  "%s","%s","FAILED"\n' "$s" "$ENVIRONMENT"
      else
        printf '%s' "$v" | gh secret set "$s" "${REPO_ARG[@]}" >/dev/null 2>&1 && printf '  "%s","repo","set"\n' "$s" || printf '  "%s","repo","FAILED"\n' "$s"
      fi
    done
    ;;

  dispatch)
    env_name=${ARGS[0]:-}
    case "$env_name" in
      staging|production) ;;
      *) printf 'error: dispatch needs staging|production\nhelp: bin/github-deploy.sh dispatch staging\n' >&2; exit 2 ;;
    esac
    if gh workflow run "deploy-${env_name}.yml" "${REPO_ARG[@]}" >/dev/null 2>&1; then
      printf 'dispatched[1]{workflow,environment,status}:\n  "deploy-%s.yml","%s","queued"\n' "$env_name" "$env_name"
    else
      printf 'error: dispatch failed (workflow present? gh authenticated for the repo?)\n' >&2; exit 1
    fi
    ;;

  status)
    printf 'runs[%s]{workflow,status,conclusion,created}:\n' "$(gh run list --limit 5 "${REPO_ARG[@]}" 2>/dev/null | wc -l | tr -d ' ')"
    gh run list --limit 5 --json name,status,conclusion,createdAt "${REPO_ARG[@]}" 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except: d=[]
for r in d: print(f"  \"{r.get(\"name\",\"\")}\",\"{r.get(\"status\",\"\")}\",\"{r.get(\"conclusion\",\"\")}\",\"{r.get(\"createdAt\",\"\")[:16]}\"")'
    ;;

  *) printf 'error: unknown command %s\nhelp: bin/github-deploy.sh [secrets|dispatch|status|--version]\n' "$CMD" >&2; exit 2 ;;
esac
