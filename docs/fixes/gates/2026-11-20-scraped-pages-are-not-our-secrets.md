# 2026-11-20 — scraped public pages are not this house's secrets

**Component:** gates · **File:** `.gitleaks.toml`

The secret scan reads the history of every branch. A research errand's salvage branch
(`salvage/eu-ai-funds-scout-1120`, commit `34b9045df`) carries two pages scraped from public websites,
`.scout/raw/chips-ju.html` and `.scout/raw/eusair.html`, whose embedded browser keys belong to those sites. That one
branch turned the scan red on `main` and on every pull request. `.scout/raw/*.html` joins the third-party allowlist
beside lockfiles and bundles. The branch itself is kept (nothing deleted); whether it is reviewed or retired is the
operator's call.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #853
