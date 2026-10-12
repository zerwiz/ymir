# Distinct gates — one class per service, one gate per class

> **Status: law (Rule 18); the gates themselves are partly built.** The rule binds today; the
> class manifest exists; the doors are plan 77's work.

## What it is

Ymir holds several kinds of material with genuinely different audiences — a public site, a
team's shared work, a client's realm, your own hoard, and NDA‑grade vault content. Treating
them as one boundary is how a teammate ends up reading a private plan — or how one leak opens
every surface at once.

So the boundary is **many gates, each with its own mechanism**:

| class | its gate | who passes |
|---|---|---|
| **public** | open (rate‑limited) | anyone |
| **team** | SSO | invited teammates |
| **client** | SSO + a realm‑scoped role | that client's people only |
| **operator** | your own identity (SSH ward + session) | you |
| **confidential** | the **vault** (LUKS + airlock) | you, offline only |
| **fleet** | agent tokens per seat | agents, as themselves |

## The law

```
gate_law[5]{rule}
  "One class per service — a service serving two classes has two doors, or it is mis-built"
  "One gate per class — the MECHANISM differs, not only the policy"
  "A door never serves two classes — mixing is how a team member reads a private plan"
  "Crossing carries proof — a credential that names the CLASS and the person"
  "Confidential is not 'team with a tighter password' — it never leaves the vault"
```

## Do it

```bash
# the manifest: every service, its class, its gate
$EDITOR "$YMIR_HOME/config/services.yaml"
```

Each service gets exactly **one** class and **one** gate. The manifest is the map; a service
with no class is a door nobody has decided about.

## Why "distinct" and not just "classified"

A shared gate is a **shared failure**: one leaked SSO session would open every surface behind
it. Distinct gates make a leak **local** — the team gate cannot reach your hoard, and your
door cannot reach the vault's plaintext.

## The refusal is the feature

A gate that never refuses is untested. Every class must prove a **negative** — a team login
asking for an operator path is denied; an operator path asking for vault plaintext is denied —
and the denial is written to **Runes**, naming the class and the caller.

**See also:** [`team-places.md`](team-places.md) · [`the-secrets-vault.md`](the-secrets-vault.md) ·
[`confidential-session.md`](confidential-session.md).
