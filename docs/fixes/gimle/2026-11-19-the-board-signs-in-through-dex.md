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

## Appended 2026-11-21 — superseded on 2026-11-20 by the board door

Everything above describes the adapter as it stood on the night of 2026-11-19. It stays as the record of what was
built. It is no longer how the board signs in.

**What replaced it.** On 2026-11-20 the Gitea-shaped adapter `board-sso` was retired (plan 326, the section
appended 2026-11-20 night). A person had seen three pages that were not Gimlé's: the board's login, a button
labelled "Sign in with Gitea", and the issuer's default page. The house runs no Gitea.

The board now signs in through **the board door**, `systems/login/board_door.py` in the hall's repository (`zerwiz/gimle`), used by the
login bridge. Every board page load asks the bridge's `/board/door`:

- An unsigned visitor gets the hall's own sign-in page, which names the board as the destination.
- A signed-in person gets a board session, made by the bridge with the board's own code.
- A new verified person joins at the least role, with one audit line per provision or refusal.

The rules the adapter carried moved into the door: verified email only, least role, Admin refused at start, an
audit line, and the kill switch `OIDC_BOARD_JIT=off`. The door's own page is `systems/login/board-door/README.md` there.

**What was taken down.** The adapter's unit is stopped and disabled. Its folder and unit moved on the heart to the
hall's retired shelf, with a roll-back note. The Dex client `gimle-board` is removed, and the board's
`IS_GITEA_ENABLED` is 0. The adapter's source is kept for reference in the hall's repository at `docs/reference/retired/board-sso/`.

**The three Owed lines above, closed:**

| Owed on 2026-11-19 | State on 2026-11-20 |
|---|---|
| one real browser sign-in by the operator | superseded: the door was proved in headless Chromium at desktop and phone width (signed out, signed in, signed out again); the adapter it would have tested no longer runs |
| the button reads "Continue with Gitea" | closed: the Gitea provider is off, and no sign-in step names Plane, Gitea or Dex |
| the adapter's source belongs in the hall's repository | closed: the adapter is retired, and its source sits on the hall's retired reference shelf |

**Where this note belongs.** It records the hall's deployment and touches no path in Ymir. At the Allfather's
standing word, *"all gimle things in gimle"*, the same note with this section now lives in the hall's repository at
`docs/fixes/login/2026-11-19-the-board-signs-in-through-dex.md` (zerwiz/gimle#21). This copy is the record of where
it was first written.
