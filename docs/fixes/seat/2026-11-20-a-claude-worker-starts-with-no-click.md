# A Claude worker starts with no human click

**Date:** 2026-11-20 · **Component:** seat · **Doors:** `bin/seat/claude-seat.sh` (new), `bin/seat/herdr-run.sh`,
`src/ymir_runtime/claude_seat.py` (new), `src/ymir_runtime/harness.py`, `src/ymir_runtime/seat.py`,
`.agents/harnesses/claude-worker.settings.json` · **Tests:** `src/ymir_runtime/tests/test_claude_seat.py`,
`src/ymir_runtime/tests/test_harness.py`

## What was wrong

The operator's word: *"they get blocked all the time and I need to accept things all the time."* Measured on the dev
machine the same day, four faults stopped Claude workers:

1. **The model.** `eindri-start.sh --kind claude --model claude-opus-5-5` reached the CLI as
   `claude --model claude/claude-opus-5-5`, because the herdr road builds `provider/model`. Claude answered
   *"There's an issue with the selected model"*, the pane sat, and herdr called it `done`. Seven workers sat that way
   until the helm typed `/model opus` into each one.
2. **Trust.** Claude asks *"Yes, I trust this folder"* in any folder whose entry in `~/.claude.json` lacks
   `hasTrustDialogAccepted`. A worktree in a repository nobody opened by hand is such a folder.
3. **Permissions.** The herdr road launched a bare `claude`: no worker profile, so any tool outside the user's own
   allow list opened a dialog. The engine road used `acceptEdits`, which still asks about every MCP tool.
4. **No seat check.** Nothing read the pane, so a stuck seat was reported as a seat.

## What was forged

- **The model name comes from the allow-list.** For a Claude seat, `herdr-run.sh` asks
  `claude-seat.sh model <request>`, which reads the bare id from `bin/model/model-allow.sh`. `claude/claude-opus-5-5`,
  `anthropic/…`, `claude-opus-5-5`, `opus` and `sonnet` all reach Claude as a name it accepts. No model named means the
  list's Claude default, never the role's `agents.yaml` model (which belongs to pi or opencode). The engine's
  `harness.resolve` now normalises the `claude/` and `anthropic/` prefixes instead of refusing them.
- **The seat folder is trusted before launch.** `claude_seat.trust()` marks that one folder under a lock, with an
  atomic replace that keeps every other key, and checks the write afterwards (Claude rewrites the file from memory).
  It refuses `$HOME`, `/` and anything above the home. Both roads call it.
- **The launch runs in `dontAsk` mode** with the shipped worker profile, plus one `mcp__<server>` allow for each MCP
  server Claude is configured with. A tool outside the list is denied, never asked about. The profile's deny list and
  every hook still apply: this is not a bypass. `Skill` and `NotebookEdit` joined the profile's allow list.
- **The seat check.** After launch, `herdr-run.sh` reads the pane at about 20 s and 60 s (`YMIR_CLAUDE_SEAT_CHECKS`).
  A model refusal, a trust, switch-confirm or permission dialog, a login screen, or a brief that never landed gets one
  automatic repair. If it is still stuck, the seat is **FAILED** with its reason named and exit 5. The repair never
  approves a permission on the worker's behalf: it refuses that call and tells the worker to carry on.

## Proof

Three throwaway workers were seated through `eindri-start.sh --kind claude`, in a scratch repository whose folder was
not trusted, with `--model claude/claude-opus-5-5`, `opus` and `sonnet`. Each one was marked trusted, passed both
seat checks with no repair, and wrote its `PROOF.txt` (`claude-opus-5-5`, `claude-opus-5-5`, `claude-sonnet-5-5`).
Nobody pressed a key. All three were closed and their worktrees removed.

## Not changed here

- **Sessions resumed in the home folder.** The `claude --resume` processes in the home folder are restored by the
  herdr server's own session restore (`herdr::persist::restore`). It resumes each pane in its saved folder, and falls
  back to `$HOME` when that folder no longer exists. The three sessions found in the home folder were started there
  (their transcripts live under the home folder's own project in `~/.claude/projects/`), so there is no other project folder for them.
  The home folder is never marked trusted, so those panes still ask once per session.
- **`seat-reap.sh <id>`** looks for a workspace labelled `eindri-<id>`. `herdr-run.sh --space` labels it
  `<project>:<id>`, and a `--tab` seat has no workspace at all, so `seat-reap.sh` could not find these seats. The
  proof seats were closed by `/exit` and `herdr tab|workspace close`.
- The engine road gets the trust mark and `dontAsk`, but not the 20 s and 60 s pane check.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #853
