# A second house — running the suite for another company

**What it is.** The collaboration suite (the gate, the whiteboard, the MCP, the documents) was written for one
house. A second company can run **its own copy** of it: its own service account, its own names, its own gate
secrets, its own members — on its own machine, sharing no secret, no user and no document with the first.

**What it is not.** It is not the same installation reached by another name. The two are separate
installations, and the line between them is the point: a person or a project belongs to exactly one.
See `bin/collab/kit/` for the standard a repository adopts, and `docs/features/gimle-the-hall.md` for the
first house's own page.

**What you need.** A machine you administer, root or an account with `sudo`, an empty service account name for
the house, and the copied tree. Nothing here needs the first house to be reachable.

## The shape you are building

| Piece | What it is |
|---|---|
| a service account | a system user named for the house, no login shell, and a group that holds the people who administer it |
| the tree | `/srv/<house>-suite`, owned by that account, mode `2770` (setgid) so new files keep the group |
| the secret store | `/etc/<house>-suite/secrets`, outside the tree, mode `700`, every value mode `600` |
| the gate's people | a `users_database.yml` naming only that house's members |
| the units | one per service, `User=` the service account, `Conflicts=` the first house's unit of the same name |
| the names | the house's own domain, in the gate, the proxy and the login pages |

## The steps

**1. The account.** A company system belongs to the company, not to a person: if the person who set it up is
away, the suite must not go with them.

```bash
groupadd --system <house>
useradd --system --gid <house> --home-dir /srv/<house>-suite --no-create-home \
        --shell /usr/sbin/nologin --comment "<House> suite service account" <house>
usermod -aG <house> <admin>          # each person who administers it, never as the owner
```

**2. The copy.** One `rsync`, and a named list of what must not travel. Everything excluded is a live secret or
the first house's own record; carrying it is the irreversible act, leaving it is not — the originals stay where
they were.

```bash
rsync -a /srv/<first>-suite/ /srv/<house>-suite/ \
  --exclude='*.bak-*'             `# old copies of configuration` \
  --exclude='.fallback.json'      `# a credential dump, if the copy carries one` \
  --exclude='gate/config/db.sqlite3'   `# the first house's access record` \
  --exclude='mail/*.key'          `# its mail relay key` \
  --exclude='desk/etc/*token*' --exclude='desk/etc/people.json' \
  --exclude='apps/*/.env' --exclude='apps/*/private.key' \
  --exclude='data/mcp/tokens' --exclude='data/mcp/access.jsonl'
chown -R <house>:<house> /srv/<house>-suite && chmod 2770 /srv/<house>-suite
find /srv/<house>-suite -type d -exec chmod g+rwxs,o-rwx {} +
find /srv/<house>-suite -type f -exec chmod g+rw,o-rwx {} +
```

**3. The secrets — generated there, never copied.** Two gates holding one signing secret can forge each other's
sessions, so every value is new and is created on the machine that will use it.

```bash
install -d -o <house> -g <house> -m 0700 /etc/<house>-suite/secrets
for f in gate-session.secret gate-storage-encryption.key gate-reset-password-jwt.secret gate-oidc-hmac.secret; do
  openssl rand -hex 32 > /etc/<house>-suite/secrets/$f
done
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out /etc/<house>-suite/secrets/gate-oidc-issuer.key
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=auth.<domain>/O=<House>" \
  -addext "subjectAltName=DNS:auth.<domain>" \
  -keyout /etc/<house>-suite/secrets/gate-tls.key -out /etc/<house>-suite/secrets/gate-tls.crt
chown -R <house>:<house> /etc/<house>-suite/secrets && chmod 600 /etc/<house>-suite/secrets/*
```

Prove they are new rather than assume it: compare the SHA-256 of each new value with the first house's and see
`not equal`. Never print a value — the digest is enough to answer "is this the same secret?".

**4. The gate's people.** Only that house's members, each with their own hash. A hash may be carried for the
person who already has one; a **new** person's first password is generated on the machine, hashed with the
gate's own tool, and written to a file only the person who delivers it can read.

```bash
docker run --rm -e PW authelia/authelia:latest sh -c 'authelia crypto hash generate argon2 --password "$PW"'
docker run --rm -e PW authelia/authelia:latest sh -c 'authelia crypto hash generate pbkdf2 --password "$PW"'  # OIDC client secret
```

The gate's configuration points at the secret store instead of holding a value:

```yaml
session:
  secret: '{{ secret "/secrets/gate-session.secret" }}'
```

**Two traps, both silent, both measured.** Keep them or you will ship a gate whose "secret" is a string:

- **The template filter is not on by default.** Without `--config.experimental.filters template`, the literal
  text `{{ secret "/secrets/…" }}` is accepted as the value — a session secret that is not a secret, and no
  error anywhere. Prove the file with `authelia validate-config --config … --config.experimental.filters template`.
- **A PEM in a single-quoted YAML scalar is folded onto one line** and refuses to parse. The key needs an
  indented block and `nindent`:

  ```yaml
  jwks:
    - key: |
        {{ secret "/secrets/gate-oidc-issuer.key" | nindent 10 }}
      algorithm: RS256
      use: sig
  ```

**5. The units.** One per service, all as the service account, each declaring the first house's unit as a
`Conflicts=` so a staged unit started by accident fails loudly instead of shadowing the running one. Install
them, `systemctl daemon-reload`, and prove with `systemd-analyze verify` (exit 0) — then **leave them disabled
and inactive** until the cutover.

**6. The names.** The gate, the proxy and the login pages carry the house's own domain — the door, the
documents, the whiteboard, the book and the MCP — and the session cookie's domain is the house's. A personal
tailnet name or address from the first house is a leftover, not a feature: remove it.

**7. The tokens.** One per member, scoped to that house's places, written into the suite's token file (mode
`600`, the service account only) and a copy into each member's home (mode `600`, owned by them). Every call is
audited.

## Proving it before anybody uses it

| Proof | What it answers |
|---|---|
| `grep -rIlE '<first-house-domain>\|<FirstHouse>\|<first-house>\|…'` over the staged tree | is the other house's name gone? |
| `grep -rn 'ts.net\|<tailnet address>'` | is a personal door gone? |
| `authelia validate-config … --config.experimental.filters template` | is the gate's configuration real, or full of literal placeholders? |
| `systemd-analyze verify <units>` | do the units parse? |
| `systemctl is-enabled/is-active` | are they staged and dark? |
| `systemctl is-active` on the first house's units, and their start times | was the old installation left alone? |
| `python3 -m py_compile`, `node --check`, `bash -n`, `caddy validate` on the suite's own files | do its scripts still run after the rename? |

Keep records out of the rename: a ticket ledger, a build output and an upstream source tree are history, not
configuration, and rewriting them destroys evidence. Say which files you excluded and why.

## Limits, and what this does not do

- **It does not cut over.** Staging stops at the proof. Stopping the old units, raising the new ones, adding the
  proxy blocks and adding the tunnel routes are a separate, deliberate act, written down first.
- **Tunnel routes are not on disk.** If the house arrives through a tunnel, its routes are added in the
  provider's dashboard by a person. No port is opened for a name.
- **A gate with no mail relay cannot send a reset.** Until the house's domain has SPF and DMARC, reset mail
  must be delivered by a person; the gate's notifier should be a file, not an unauthenticated sender.
- **The applications keep their own credentials.** A copied `.env` is a shared secret; each app is given new
  values the moment it is raised from the new tree.
- **Renaming is not rebranding.** Identifiers, file names and product names may still carry the first house's
  vocabulary; change what a person reads and what a service loads, and leave the rest for a decision.

## If it does not work

- **The gate starts and rejects everyone**: the users file was not reloaded, or the hash is not argon2id.
- **`validate-config` passes but the gate cannot read a secret**: the store's mode is `700` owned by the service
  account, so the container must run as **that** account (`--user`), not as its own default user.
- **A unit refuses to start**: `Conflicts=` — its counterpart is still running. That is the guard working; stop
  the old one first.
- **The tree is unreadable to an administrator**: they are not in the house's group. Group membership applies to
  a new session.
