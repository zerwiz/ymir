# Work on the vault in a confidential session

## What it is

The vault (**Hnitbjörg**) may hold work under NDA. A **confidential session** lets you
work on it with **no route off the vault**: the work lives *inside* the vault, every
door that could record or send something out is turned **off**, and you choose exactly
what the AI may be — the **local** model, **none**, or a **remote** one. With
`--airlock`, the session has **no network at all**.

Use it whenever you are working on a vault project. Do not work on vault content
outside a session.

## What you need

- The vault **open**: `bin/vault/hnitbjorg.sh open`.
- **`bwrap`** (bubblewrap) only if you want `--airlock`.
- A **local model** if you want AI without leaving the machine — Ymir's own router
  (`http://127.0.0.1:8080/v1`) is used automatically.

## Do it

```bash
# 1. open the vault
bin/vault/hnitbjorg.sh open

# 2. start a session — you land in the vault's own work directory
bin/vault/confidential.sh start
#    →  ~/Vault/confidential/session-<pid>
```

Inside the session:

- your shell's working directory **is inside the vault**;
- the **well, tickets, runes and daily log are off** — nothing is recorded off-vault;
- the model is the **local** router only (no remote endpoint is configured).

Choose the model tier explicitly when it matters:

```bash
bin/vault/confidential.sh start --tier local    # on-machine model ONLY (default)
bin/vault/confidential.sh start --tier none     # no model at all — reading/writing by hand
bin/vault/confidential.sh start --tier remote   # your configured provider is allowed
bin/vault/confidential.sh start --airlock       # NO network at all
```

When you are done:

```bash
bin/vault/confidential.sh stop      # end the session
bin/vault/hnitbjorg.sh close        # seal the vault
```

## Notes and limits

- **The filesystem boundary is enforced.** While a session is live, the
  `confidential-guard` ward **refuses to commit any file that is not inside the
  vault** — in the repo or the home. Work and commit *inside* the vault.
- **The network is isolated only with `--airlock`.** Without it, a local model needs
  loopback, so external egress is not blocked — the tiers say plainly what is allowed,
  and the choice is yours. For fully offline AI, use `--airlock` and run the model
  **inside** the session (its loopback is the session's own).
- **Rule 15 still applies.** The session confines the work; `vault-guard` separately
  refuses a commit that copies a vault file verbatim — belt and braces.
- **A session is started by you, never by an agent.** The vault is sealed by default;
  only the Allfather opens it.

## If it does not work

| What you see | What to do |
|---|---|
| `the vault is not open` | `bin/vault/hnitbjorg.sh open` first. |
| `bwrap is required for --airlock` | Install bubblewrap (`sudo pacman -S bubblewrap` / `sudo apt install bubblewrap`), or drop `--airlock`. |
| A commit is refused with *outside the vault is staged* | You are committing outside the vault during a session — commit the work inside the vault, or `bin/vault/confidential.sh stop`. |
| The model does not answer in a session | Check the local router is up (`llama-router status`); use `--tier none` if you want no model. |
