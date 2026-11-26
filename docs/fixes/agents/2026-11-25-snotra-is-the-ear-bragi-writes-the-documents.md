# Snotra's card is the meeting ear; the documenter's craft is Bragi's (plan 374 D2)

- `.agents/agents/snotra-documenter.md` → `.agents/agents/snotra-ear.md` (`git mv`, history kept), recast as the
  keeper of the meeting system in `systems/snotra/`, which `systems/snotra/domain.yaml` already names her keeper of.
- `.agents/agents/bragi-marketer.md` gains the documenter's five capabilities and a section that says where they came
  from.
- `.agents/roles.yaml`: the `documenter` role now routes to `bragi`. The role key is unchanged, so the chooser and the
  harness configs that name `documenter` keep working.
- `bin/agents/name-registry.sh` strips the `-ear` suffix, so the card still registers as `snotra`.
- The asset tables (`.agents/README.md`, `eindri-profiles.md`, `norse-naming.md`) and `systems/snotra/AGENTS.md`
  (appended) name the new card.

> [!NOTE]
> The home's register of domains still names the agent `snotra-documenter`. It lives in the home, so the
> helm changes it there: `bin/agents/domain.sh` finds the card by the prefix `snotra`, so nothing breaks meanwhile.

## Proof

- `bash bin/agents/eindri-role.sh choose "write the docs and a readme for the release"` → `"bragi","document — prose, guides, references",2`.
- `python3 bin/mcp/ymir-mcp.py --selftest` → `prompts: 25` (the `snotra` prompt is now the ear's).
