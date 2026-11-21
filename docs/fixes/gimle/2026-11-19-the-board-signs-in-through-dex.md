# The board signs in through Dex, not through its own Google app

**Component:** `gimle` (the heart's deployment: the board, the issuer and the portal proxy).
**Date:** 2026-11-19. **Plan:** the operator's plan 325, in its section dated the same night.

## What was wrong

The board's own "Continue with Google" button answered `Error 400: redirect_uri_mismatch`.

The board's instance configuration held the issuer's own Google client. That client allows exactly one
redirect: the issuer's `/dex/callback`. The board sends `https://<board>/auth/google/callback/` (measured from its
`/auth/google/` redirect). Google refused the mismatch, as it should.

The board is **Plane community edition 1.4.2**. That edition has **no generic OpenID Connect sign-in**. Its
providers are Google, GitHub, GitLab and Gitea, and only Gitea and GitLab take a configurable host. A setting
named `IS_OIDC_ENABLED` does not exist there.

## What was changed

The board now signs in through its **Gitea** provider. That provider points at a small adapter, `board-sso`. The
adapter speaks Gitea's OAuth dialect to the board and plain OpenID Connect to Dex.

| Piece | What it does |
|---|---|
| a Dex client `gimle-board` | confidential; its redirect is exactly `https://<board>/auth/gitea/callback/`, trailing slash included |
| the adapter (`~/board-sso/` on the heart, a user unit) | `authorize` redirects to Dex with the scope rewritten to `openid email profile` (Dex refuses Gitea's `read:user`); `access_token` forwards to Dex's token endpoint; `user` and `user/emails` shape Dex's userinfo as a Gitea user |
| a portal route `/board-sso/*` | publishes the adapter under the issuer's own host, so the browser and the board reach the same URL |
| the board's instance configuration | Gitea on and pointed at the adapter; Google off, with its borrowed client id and secret cleared; open sign-up off |

The board reads its sign-in settings from its database, and the database wins over its env file. So the change
was made in the database, after a full backup of that table. The env file was backed up too, and not changed.

## How a person is known

The board knows a person by the **email on its own user record**. The adapter maps one verified address to
another through an aliases file, so one person with a work and a private address lands on one board user. Every
other address reaches the board as itself.

With open sign-up off, the board refuses an unknown address by name (`SIGNUP_DISABLED`, 5015), unless a workspace
invite exists for it. An address the issuer has not verified is refused as `OAUTH_PROVIDER_UNVERIFIED_EMAIL`.
Aliases apply only to verified addresses.

## What was learned

- **Recreating Dex needs `DEX_UID` and `DEX_GID`.** A plain `docker compose up --force-recreate` runs the
  container as uid 1001. That user cannot write `state/dex.db`, so `/dex/healthz` returns 500 while discovery still
  answers 200. Raise it with `DEX_UID=$(id -u) DEX_GID=$(id -g) docker compose up -d`, as the compose file's header
  says.
- **A single-file bind mount follows the inode.** Edit such a file in place (truncate and write). A tool that
  replaces the file leaves the container reading the old one.

## Proved, and owed

- Proved: discovery answers; Dex accepts the client and its redirect; the adapter refuses an unknown client; a token
  call from inside the board's container reaches Dex (`invalid_grant` with the real secret, `invalid_client` with a
  wrong one); the board's Google endpoint now answers `GOOGLE_NOT_CONFIGURED`. The adapter's shaping, its aliases and
  its unverified path were tested against a stand-in issuer.
- Owed: one real browser sign-in by the operator.
- Owed: the button reads "Continue with Gitea", because that label is fixed in the board's bundle.
- Owed: the adapter's source belongs in the hall's own repository, beside its OIDC bridge.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #872
