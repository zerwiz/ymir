#!/usr/bin/env bash
# 0003-private-data-separation — move all private data to YMIR_HOME
# Idempotent: safe to run repeatedly. Copies (never moves); originals
# remain until manually removed.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
YMIR_HOME="${YMIR_HOME:-$HOME/Documents/Ymir}"

echo "0003-private-data-separation"
echo "  source:  $ROOT (repo)"
echo "  target:  $YMIR_HOME"

# 1. Create target layout
mkdir -p "$YMIR_HOME"/{config,secrets,identity,workspaces/{work,personal},memory/{daily,well},smidja,state,data}

# 2. Migrate hodd/ (Hoard) → YMIR_HOME/
# Non-destructive: never overwrites an existing file, and MERGES a directory
# into its target. The target dirs are pre-created above, so a naive
# `[ -e "$2" ] && return` skipped every directory source — `data/` among them,
# which silently dropped the realm declaration and made 0004 fall back to a
# neutral realm.
copy() {  # <src> <dest>
  [ -e "$1" ] || return 0
  if [ -d "$1" ]; then
    mkdir -p "$2" || return 0
    cp -rn "$1"/. "$2"/ 2>/dev/null && printf '  copied %s\n' "${1#$ROOT/}"
    return 0
  fi
  if [ -e "$2" ]; then return 0; fi
  mkdir -p "$(dirname "$2")" || return 0
  cp -rn "$1" "$2" 2>/dev/null && printf '  copied %s\n' "${1#$ROOT/}"
}

copy "$ROOT/hodd/secrets"        "$YMIR_HOME/secrets"
copy "$ROOT/hodd/identity"       "$YMIR_HOME/identity"
copy "$ROOT/hodd/docs"           "$YMIR_HOME/memory"
copy "$ROOT/hodd/masterplan.md"  "$YMIR_HOME/memory/masterplan.md"
copy "$ROOT/hodd/append-only-log.md" "$YMIR_HOME/memory/append-only-log.md"

# 3. Migrate svartalfaheim/ (tenant data) → YMIR_HOME/workspaces/ + identity/companies/
copy "$ROOT/svartalfaheim/work/workspace" "$YMIR_HOME/workspaces/work"
copy "$ROOT/svartalfaheim/wayof/companies" "$YMIR_HOME/identity/companies"

# 4. Migrate workspace/ (operator's world-tree) → YMIR_HOME/workspaces/
for d in work personal memory companies; do
  copy "$ROOT/workspace/$d" "$YMIR_HOME/workspaces/$d"
done

# 5. Migrate config/agents.yaml → YMIR_HOME/config/
copy "$ROOT/config/agents.yaml" "$YMIR_HOME/config/agents.yaml"

# 6. Migrate state/ → YMIR_HOME/state/
copy "$ROOT/state" "$YMIR_HOME/state"

# 7. Migrate data/ → YMIR_HOME/data/
copy "$ROOT/data" "$YMIR_HOME/data"

# 8. Migrate .agents/memory/kaia.engram* → the HOARD's memory (the one store)
copy "$ROOT/.agents/memory/kaia.engram"       "$YMIR_HOME/hodd/memory/kaia.engram"
copy "$ROOT/.agents/memory/kaia.engram-wal"   "$YMIR_HOME/hodd/memory/kaia.engram-wal"
copy "$ROOT/.agents/memory/kaia.engram-shm"   "$YMIR_HOME/hodd/memory/kaia.engram-shm"

# 9. Migrate smidja/smidja_data/smidja.db* → YMIR_HOME/smidja/
copy "$ROOT/smidja/smidja_data/smidja.db"          "$YMIR_HOME/smidja/smidja.db"
copy "$ROOT/smidja/smidja_data/smidja.db-wal"      "$YMIR_HOME/smidja/smidja.db-wal"
copy "$ROOT/smidja/smidja_data/smidja.db-shm"      "$YMIR_HOME/smidja/smidja.db-shm"

# 10. Create .gitignore for private repo
cat >"$YMIR_HOME/.gitignore" <<'GITIGNORE'
# Runtime — rebuilt per machine
smidja/
state/
*.wal
*.shm
*.pid
*.lock

# Local overlays
config/agents.*.yaml
GITIGNORE

# 11. Initialize git repo if not already
if [ ! -d "$YMIR_HOME/.git" ]; then
  git -C "$YMIR_HOME" init >/dev/null 2>&1 && echo "  initialized private git repo at $YMIR_HOME"
fi

# 12. Offer to add GitHub remote for multi-machine sync
if [ -d "$YMIR_HOME/.git" ] && [ -t 0 ]; then
  read -p "  Add private GitHub remote for multi-machine sync? (git@github.com:user/repo.git) [y/N]: " yn
  case "$yn" in [Yy]*)
    read -p "    GitHub repo URL: " gh_url
    [ -n "$gh_url" ] && git -C "$YMIR_HOME" remote add origin "$gh_url" && \
      git -C "$YMIR_HOME" add -A && \
      git -C "$YMIR_HOME" commit -m "chore: initial Ymir private data" >/dev/null 2>&1 && \
      git -C "$YMIR_HOME" push -u origin main && \
      echo "    pushed to $gh_url" || true
    ;;
  esac
fi

# 13. Write layout record
cat >"$YMIR_HOME/.ymir-layout.yaml" <<YAML
version: 1
migrated_from: "$ROOT"
migrated_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
layout:
  config: "$YMIR_HOME/config"
  secrets: "$YMIR_HOME/secrets"
  identity: "$YMIR_HOME/identity"
  workspaces: "$YMIR_HOME/workspaces"
  memory: "$YMIR_HOME/memory"
  smidja: "$YMIR_HOME/smidja"
  state: "$YMIR_HOME/state"
  data: "$YMIR_HOME/data"
git_repo: "$YMIR_HOME"
github_repo: "${gh_url:-}"
secrets_encrypted: false
YAML

echo "0003-private-data-separation: done — private data now at $YMIR_HOME"
