# Claude Eindri run Sonnet 5.5, and no pane needs a /model switch

On 2026-11-12 the Allfather's word was that Claude workers run Sonnet 5.5. PR #679 made `sonnet` the spawner's default and `opus` the choice for `--effort high` and above. Two faults kept that word from holding.

## What was wrong

- The shipped allow-list template named no Sonnet, so a list copied from it refused a Sonnet spawn.
- A Claude seat was launched on the exact id the list resolved to, and the template named no default, so a pane could start on the wrong model until someone typed `/model`.

## What changed

- `config/models-allowed.yaml.example` allows `claude/claude-sonnet-5-5` and sets it as the Claude default. Opus stays a commented line to opt into.
- `bin/agents/einherjar-spawn.sh` still asks the list about the exact id, but a Claude seat launches on the family alias it resolved to: `claude --model sonnet`.
- `tests/test_model_allow.sh` holds the new shape: no `--model` gives sonnet, `--effort high` gives opus, haiku and other harnesses' models are refused.

> [!IMPORTANT]
> The operator's own list lives in the home and is the helm's edit. It needs the same `claude/claude-sonnet-5-5` line and `defaults: claude: claude-sonnet-5-5`.
