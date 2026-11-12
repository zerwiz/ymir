# Public signature (PR identity)

Agents open PRs through `bin/forge/pr-open.sh`, which renders a six-line signature block and refuses leaks.

## Commands
- `bin/forge/pr-open.sh --role <agent> --house <h> --fleet <f> --errand <id> --authority "..." --proves "..." --title ... --body-file ... [--dry-run]`
- `bin/gates/guards/pr-identity-guard.sh <pr> | --ci`

## Names of models and tools stay out of prose

A pull request title, a pull request body and every commit message may not name a model, a model maker or an agent
harness (RULES/53). The door refuses with the line and the word. Say "the agent harness" or "the worker"; put a path or
flag in `backticks` and it passes. The word list is `bin/gates/maker-words.txt`; a reasoned exception goes in
`bin/gates/maker-allow.txt`. The collaboration kit carries the same ward to client repositories.
