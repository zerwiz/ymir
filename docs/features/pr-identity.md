# Public signature (PR identity)

Agents open PRs through `bin/forge/pr-open.sh`, which renders a six-line signature block and refuses leaks.

## Commands
- `bin/forge/pr-open.sh --role <agent> --house <h> --fleet <f> --errand <id> --authority "..." --proves "..." --title ... --body-file ... [--dry-run]`
- `bin/gates/guards/pr-identity-guard.sh <pr> | --ci`
