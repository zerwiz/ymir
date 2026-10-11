# Rule 16 — The confidential session: work on the vault without a route off it

> Adopted 2026-10-11, as Rule 15's companion. Rule 15 says *vault content never
> leaves*. Rule 16 makes that **structural**: a way to work on vault projects in
> which there is no path out except the vault itself.

Rule 15 watching the door is not enough on its own — the operator and the agents are
still on an ordinary machine, beside the memory well, the tickets, the logs and the
wider network. A **confidential session** removes those neighbours for the duration
of the work.

## The law

```
confidential_law[5]{rule}:
  "A confidential session works only inside the vault — the workdir lives in the mount"
  "No well, no tickets, no plans, no runes, no daily log: those doors are OFF in a session"
  "The model tier is explicit: local (on-machine only), none, or remote — chosen, never assumed"
  "The airlock tier has NO network at all; a model, if any, runs inside it"
  "While a session is live, nothing outside the vault may be committed — the guard refuses it"
```

## The session

`bin/vault/confidential.sh` is the door:

```bash
bin/vault/confidential.sh start [--tier local|none|remote] [--airlock] [--sandbox] [--name NAME] [-- CMD…]
bin/vault/confidential.sh stop
bin/vault/confidential.sh status
```

- **`--tier local`** (default, for sensitive work): the model is the **on-machine**
  router only (`http://127.0.0.1:8080/v1`). No remote endpoint is configured.
- **`--tier none`**: no model at all — pure reading, writing, and reasoning by hand.
- **`--tier remote`**: the operator's configured provider is allowed (for work whose
  NDA permits a third party). Off unless chosen.
- **`--airlock`**: an **interactive** shell under `bwrap --unshare-net` — **no network
  whatsoever**, not even loopback to the host.
- **`--sandbox`**: a **sealed one-shot** run through **Utgard** (the sandcastle/docker
  sandbox engine, `bin/forge/utgard.sh run … --network none`): a **read-only rootfs**,
  **only the vault workdir mounted**, no network, and CPU/RAM/timeout caps. The
  strongest isolation for a command; it is `-- CMD`, not a shell.

The workdir is `$VAULT_MNT/confidential/<name>` — **inside the vault**. The session
sets the tool config and model tier in the environment, and disables every off-vault
record door (the well, tickets, runes, the daily log) by pointing them at the session
or turning them off. When it ends, the vault is sealed.

## Enforcement

- **`bin/gates/guards/confidential-guard.sh`** — while a session marker is live, it
  **refuses to commit any file whose path is not inside the vault mount.** Nothing can
  be written to the repo or the home from inside a session, by any tool, without the
  commit being refused. Seated in `guards.sh` and in both pre-commit hooks.
- Rule 15's `vault-guard` still watches for a verbatim copy; this watches the
  **boundary**.

**The honest limit.** The session constrains the *filesystem* strictly and the
*network* when `--airlock` is used. Without `--airlock`, network egress is not
isolated (a local model needs loopback) — so the tiers say plainly what is and is not
allowed, and the choice is the operator's, recorded in the session.

Confirmed by the Allfather 2026-10-11.
