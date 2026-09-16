#!/usr/bin/env bash
# syn-spawn-pretool-check.sh - PreToolUse seatbelt for spawning and for typing.
#
# Sýn guards how workers are raised. The failure this exists to end, observed
# live: an agent (me) hand-fired `herdr-run.sh eindri`, then delivered the brief
# by TYPING it into the pane — and when the agent had already exited the brief
# was typed into **bash**, where it sat as a command. Workers were "sent" and
# never started, and text was executed in a shell. One door exists for this and
# it is `bin/einherjar-spawn.sh` (firstmate's `fm-spawn.sh`, ported): it creates
# the worktree, records `state/<id>.meta`, and fails closed on an unverified
# harness.
#
# Usage: syn-spawn-pretool-check.sh --command <bash command>
# Exit:  0 = allow, 2 = block (stderr carries the reason and the remedy)
set -u

command_text=""
while [ $# -gt 0 ]; do
  case "$1" in
    --command) command_text=${2-}; shift 2 ;;
    *) shift ;;
  esac
done

# 1. Never type into a pane. A brief is not keystrokes: typing lands in whatever
#    owns the pane, and when the agent has exited that is the shell.
case "$command_text" in
  *"pane input"*|*"send-keys"*|*"pane type"*)
    printf 'denied: do not type into a pane — a brief delivered as keystrokes lands in whatever owns it (a shell, once the agent has exited)\n' >&2
    printf 'help: seat the worker through the door: bin/einherjar-spawn.sh <task-id> <project-dir> --mode local-only --harness opencode --model <model> --backend herdr\n' >&2
    exit 2 ;;
esac

# 2. Never hand-raise an Eindri. `herdr-run.sh run` (a command in a pane) is
#    fine; raising a WORKER by hand is not — it skips the worktree, the meta
#    record, and the harness verification.
case "$command_text" in
  *"herdr-run.sh eindri"*|*"herdr-run.sh agent"*)
    printf 'denied: an Eindri is raised through the door, not by hand — herdr-run.sh eindri skips the worktree, state/<id>.meta, and the harness check\n' >&2
    printf 'help: bin/einherjar-spawn.sh <task-id> <project-dir> --mode <direct-PR|local-only|no-mistakes> [--harness <name>] [--model <name>] [--backend tmux|herdr]\n' >&2
    exit 2 ;;
esac

# 3. A LOCAL model needs a live local server. Requesting one while the router is
#    down is how a seat came up, errored, and left a shell behind.
case "$command_text" in
  *"einherjar-spawn.sh"*)
    case "$command_text" in
      *"llama-cpp/"*|*"llama.cpp/"*|*"lmstudio/"*|*"ollama/"*)
        if ! (exec 3<>/dev/tcp/127.0.0.1/8080) 2>/dev/null; then
          printf 'denied: a local model was requested but no local server answers on :8080 — the worker will start, fail, and leave a shell\n' >&2
          printf 'help: raise the llama-router (bin/models-detect.sh reports what is served), or seat the worker on an online model\n' >&2
          exit 2
        fi ;;
    esac ;;
esac

exit 0
