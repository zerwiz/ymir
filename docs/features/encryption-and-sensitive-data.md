# Encryption and sensitive data — at rest, in transit, and end to end

> **Status: partly built.** The vault (LUKS) and age‑encrypted secrets ship; the gate, the
> crypto door for agents, and per‑place encrypted roots are plan 77's work.

## What it is

Some of what Ymir holds is **sensitive**, and a leak has consequences beyond embarrassment —
contracts, fines, legal exposure. So encryption in Ymir is not a mood; it is the difference
between *"we had a policy"* and *"the data was unreadable."*

> ***If it cannot be read where it should not be, it did not leak.***

## The three kinds, and what each protects

| kind | protects against | how |
|---|---|---|
| **in transit** | the network | TLS everywhere; nothing crosses in the clear |
| **at rest** | a stolen disk, a copied folder, a backup | encrypted roots and the vault |
| **end to end** | **the server itself** | Matrix Olm/Megolm in an encrypted room — the server holds ciphertext |

## Do it

```bash
# in transit — the door is TLS (behind the gate)
bin/room/gladsheim.sh status            # the homeserver it speaks to is https://…

# at rest — the vault
bin/vault/hnitbjorg.sh status           # sealed | open
bin/vault/hnitbjorg.sh open             # work, then
bin/vault/hnitbjorg.sh close            # seal it

# at rest — secrets referenced, never inlined
bin/vault/hodd.sh emit secrets/platform.env
```

## The rule that surprises people

**An encrypted room is only encrypted if EVERY client encrypts.** Measured: setting
`m.room.encryption` on a room works, but a plain client can still post a cleartext message,
and the server will store it. So an agent inside a sensitive room needs a **crypto‑capable
client** — that is the `matrix-bot-sdk` / `vodozemac` piece, and it is required, not optional.

## What may go where

| class | in transit | at rest |
|---|---|---|
| public | TLS | none needed |
| team | TLS + SSO | the place's own root (encrypted when the place needs it) |
| client | TLS + SSO + realm role | encrypted root; every access runed |
| operator | TLS + your identity | the hoard, age‑encrypted where secret |
| **confidential** | **no network at all** | the vault — see [`confidential-session.md`](confidential-session.md) |

**Confidential content never enters a team tool** — not a room, not a whiteboard, not a
dashboard — because a tool that can render it can leak it.

**See also:** [`distinct-gates.md`](distinct-gates.md) · [`the-secrets-vault.md`](the-secrets-vault.md) ·
[`the-vault-hnitbjorg.md`](the-vault-hnitbjorg.md) · [`confidential-session.md`](confidential-session.md).
