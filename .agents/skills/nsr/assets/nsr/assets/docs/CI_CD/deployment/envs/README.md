# envs/

Per-environment base config templates.

## Files
- `development.env.example`
- `staging.env.example`
- `production.env.example`

## Rules
- Commit templates only; never real `.env`/secrets.
- Declare every required var explicitly for `check_env.sh`.