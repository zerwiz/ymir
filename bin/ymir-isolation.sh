#!/usr/bin/env bash
# ymir-isolation.sh — capability-probed confinement for a single agent command.
#
# The layered model (audit §12): the container is the boundary against the rest of
# a shared host; bwrap is an OPTIONAL innermost scope for one model-generated
# command; Utgard remains the place for untrusted code. This script never assumes
# bwrap is usable — it probes, then degrades cleanly.
#
# Usage:
#   ymir-isolation.sh probe
#   ymir-isolation.sh run <worktree> -- <command...> [--net on|off]
#   ymir-isolation.sh --version
#
# Exit: 0 ok, 1 error, 2 usage, 3 unavailable (no isolating layer; ran anyway).
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/ymir-platform.sh
. "$SCRIPT_DIR/ymir-platform.sh"

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

CMD="${1-}"; shift || true
case "$CMD" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage; exit 0 ;;
esac

case "$CMD" in
  probe)
    layers="$(ymir_isolation_layers)"
    in_ctr="$(ymir_in_container && echo yes || echo no)"
    bwrap_ok="$(ymir_bwrap_available && echo yes || echo no)"
    bwrap_bin="$(command -v bwrap 2>/dev/null || echo -)"
    printf 'isolation[1]{layers,in_container,bwrap_binary,bwrap_usable}:\n'
    printf '  "%s","%s","%s","%s"\n' "$layers" "$in_ctr" "$bwrap_bin" "$bwrap_ok"
    if [ "$bwrap_ok" = no ] && [ "$bwrap_bin" != "-" ]; then
      printf 'note[1]: bwrap is installed but cannot create a namespace here.\n'
      printf '  A rootless/Hardened container (e.g. a Quadlet) denies nested user namespaces;\n'
      printf '  keep the container as the boundary, or opt the container in (see deploy/README.md).\n'
    elif [ "$bwrap_bin" = "-" ]; then
      printf 'note[1]: bwrap not installed (Fedora: sudo dnf install bubblewrap).\n'
    fi
    ;;

  run)
    WT=""; NET="off"
    while [ $# -gt 0 ]; do
      case "$1" in
        --) shift; break ;;
        --net) NET="${2-off}"; shift 2 ;;
        *) WT=$1; shift ;;
      esac
    done
    [ -n "$WT" ] || { printf 'error: run needs a worktree path\nhelp: bin/ymir-isolation.sh run <worktree> -- <command>\n' >&2; exit 2; }
    [ -d "$WT" ] || { printf 'error: worktree not found: %s\n' "$WT" >&2; exit 1; }
    [ "$#" -gt 0 ] || { printf 'error: run needs a command after --\n' >&2; exit 2; }
    WT="$(cd "$WT" && pwd)"

    if ymir_bwrap_available; then
      # Bind the read-only system, a writable worktree, a private /tmp, and no
      # network unless asked. --die-with-parent leaves nothing behind.
      ARGS=(--die-with-parent --unshare-all)
      [ "$NET" = on ] && ARGS+=(--share-net)
      ARGS+=(--proc /proc --dev /dev --tmpfs /tmp --setenv HOME /tmp)
      for d in /usr /lib /lib64 /bin /sbin /etc; do
        [ -e "$d" ] && ARGS+=(--ro-bind "$d" "$d")
      done
      ARGS+=(--bind "$WT" "$WT" --chdir "$WT" -- bash -lc "$*")
      exec bwrap "${ARGS[@]}"
    fi

    # No bwrap: degrade to the isolation already in force (the container), never
    # pretend the command was confined.
    if ymir_in_container; then
      printf 'isolation[1]{layer,status}:\n  "container","running in the container boundary (bwrap unavailable)"\n' >&2
    else
      printf 'isolation[1]{layer,status}:\n  "none","UNCONFINED — bwrap unavailable and not in a container"\n' >&2
    fi
    ( cd "$WT" && bash -lc "$*" )
    exit 3
    ;;

  *)
    printf 'error: unknown command %s\nhelp: bin/ymir-isolation.sh [probe|run|--version]\n' "$CMD" >&2
    exit 2 ;;
esac
