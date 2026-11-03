# Codex CLI workers in Herdr

Eindri can use Codex CLI as its harness. Install Codex CLI and authenticate it with its normal login flow before dispatching work. Run the command from a Herdr-managed pane; Ymir does not take control of a focused Herdr session from outside it.

Use `bin/agents/eindri-start.sh "<task>" --id <id> --project <project> --kind codex` for the engine road, or `bin/agents/einherjar-spawn.sh <id> --harness codex --backend herdr` for an existing errand. The standard worktree, brief, review and delivery gates still apply.

For the direct Herdr road use `YMIR_HERDR_KIND=codex bin/seat/herdr-run.sh eindri <name> -- "<task>"`. This starts Herdr's `codex` agent kind and submits the task through the agent prompt surface.

Omit `--model` to use Codex's configured default. An explicit model must be a native Codex model id, not a Pi `provider/model` token; Codex validates its availability at startup. The engine's optional effort becomes Codex's `model_reasoning_effort` setting. This adapter does not disable Codex approvals or its sandbox.

If startup fails, check that `codex --help` works in that same pane, that Codex is signed in, and that `HERDR_ENV=1` is inherited from Herdr. A missing binary or an unavailable model is an error, not a fallback to another harness. Live Herdr acceptance must be run inside Herdr; offline command tests do not prove a visible worker has started.

For a packaged Codex CLI that requires its standalone mode, set `YMIR_CODEX_NO_DAEMON=1` in the launching environment. The engine, legacy spawn, direct Herdr and tmux fallback then pass `--no-daemon`. Leave it unset for distributions that do not support that flag.
