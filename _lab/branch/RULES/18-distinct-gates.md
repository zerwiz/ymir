# Rule 18 — Distinct gates: one class per service, one gate per class

> Adopted 2026-10-12, on the Allfather's word: *"we need to have distinct gates from
> what's private and what's team data, etc."*

Ymir holds several kinds of material with genuinely different audiences — a public
site, a team's shared work, a client's realm, the operator's own hoard, and NDA-grade
vault content. Treating them as one boundary is how a teammate ends up reading a
private plan, or a leak in one place opens every place. So the boundary is not one
gate with many rules; it is **many gates, each with its own mechanism**.

## The law

```
gate_law[5]{rule}:
  "One class per service — a service that serves two classes has two doors, or it is mis-built"
  "One gate per class — the MECHANISM differs, not only the policy"
  "A door never serves two classes — mixing is how a team member reads a private plan"
  "Crossing carries proof: a credential that names the CLASS and the person or agent"
  "Confidential is not 'team with a tighter password' — it is a different mechanism: it never leaves the vault"
```

## The classes, and their gates

```
classes[6]{class,gate mechanism,who passes}
  "public","none (open, rate-limited)","anyone"
  "team","SSO from the chosen identity provider","invited teammates"
  "client","SSO + a realm-scoped role","that client's people only"
  "operator","the operator's own identity (SSH ward + session)","the operator alone"
  "confidential","the VAULT: LUKS + airlock (Rules 15, 16)","the operator, offline-only"
  "fleet","agent tokens per identity, per seat","agents, as themselves — never a person's login"
```

## Read each as absolute

1. **One class per service.** A dashboard that shows both team work and operator plans is
   two surfaces wearing one door. Split it, or its door is a lie.
2. **One gate per class — a different mechanism.** Open is not a gate; SSO is not the
   operator's key; the operator's key is not the vault. A class that borrows another's
   mechanism has no gate of its own.
3. **A door never serves two classes.** The crossing credential names the class it may
   reach. A team credential presented at an operator door is refused — and the refusal is
   **recorded**.
4. **The fleet is not the team.** An agent speaks with its own token, per seat; a person
   speaks with their own login. Neither credential grants the other's rights.
5. **Confidential is a mechanism, not a policy level.** Vault content does not sit behind
   a stricter password — it sits behind a different *kind* of boundary: it never leaves
   the vault (Rule 15) and is worked with no route off it (Rule 16).

## The refusal is the feature

A gate that never refuses is untested. Every class must prove a **negative**: a team
login asking for an operator path is denied; an operator path asking for vault plaintext
is denied; a public caller asking for anything else is denied. A denial is written to the
Runes ledger naming the class and the caller. Without that evidence, "distinct gates" is
aspiration, not architecture.
