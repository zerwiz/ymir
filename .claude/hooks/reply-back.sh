#!/usr/bin/env bash
# reply-back.sh — Claude Code `Stop` hook: a turn started by a stamped message answers its sender.
# All the judgement lives in bin/agents/reply.sh (who is owed, once, never a reply). This only finds the house and
# hands it the hook's payload. It never blocks a stop and never fails the harness.
input="$(cat 2>/dev/null)"
for root in "${YMIR_ROOT:-}" "$HOME/ymir-runtime" "$HOME/ymir"; do
  [ -n "$root" ] && [ -r "$root/bin/agents/reply.sh" ] || continue
  # stdout stays empty: Claude reads a Stop hook's stdout as a directive
  printf '%s' "$input" | timeout 140 bash "$root/bin/agents/reply.sh" --claude-stop >&2 || true
  break
done
exit 0
