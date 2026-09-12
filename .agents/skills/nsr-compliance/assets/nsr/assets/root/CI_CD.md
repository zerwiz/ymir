# CI/CD — __PROJECT__

Pipeline overview. Detail in `docs/CI_CD/`.

## Stages

1. **Build** — validate structure & docs.
2. **Test** — run gates + scripted test suites.
3. **Release** — versioning & promotion.
4. **Deploy** — env-driven rollout per env tier, per client, per tenant (`docs/CI_CD/deployment/`).

## Compliance Gates

- `.compliance/gates/check_env.sh` — required env vars present.
- `.compliance/gates/check_paths.sh` — no absolute paths.
- `.compliance/gates/check_platform.sh` — POSIX-portable.
- `.agents/skills/NSRcompliance/gates/verify_docs.py` — docs in sync.
- `.agents/skills/NSRcompliance/gates/validate_code.sh` — runs all gates; `$? == 0`.

## Rules

- CI never hardcodes values or secrets; deploy via `deploy.sh --env <env> --target <client|tenant>`.
- Every deploy runs `check_env.sh → check_paths.sh → check_platform.sh` then `validate_code.sh` before production.