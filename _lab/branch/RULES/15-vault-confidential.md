# Rule 15 — The vault is a confidential domain: its content never leaves it

> Adopted 2026-10-11, on the Allfather's word: **some vault projects are under NDA
> and legally cannot leave the vault.** A leak is not an embarrassment — it is
> breach of contract: **fines, and potentially prosecution, for the user.** This
> rule exists so that never happens.

Hnitbjörg (Rule 14's peer, the encrypted document vault) is not merely *private*.
Once it is opened it holds work that **may not exist anywhere else** — not on this
disk in the clear, not in a log, not in a model. Treat every byte inside it as if it
were under NDA, because some of it is.

## The law

```
vault_law[6]{rule}:
  "Everything inside the vault is confidential by default — assume NDA, always"
  "Vault content never leaves the vault, in any form, local or remote"
  "No model, agent, embedding, log, ticket, plan, ledger, crash dump, or network ever sees vault content"
  "Vault work happens ONLY while the vault is open, and produces nothing outside the vault"
  "No repo or home file references the vault mount or a vault path"
  "Seal it when the work is done"
```

Read each as absolute:

1. **Confidential by default.** Documents, code, data, designs, drafts, notes —
   everything inside the mount is NDA-grade until the Allfather says otherwise.
2. **Nothing leaves, in any form.** Not into the **repo** (public), not into the
   **home** (private — but still off-vault), not into the **memory well**
   (embeddings, recall), not into **tickets / plans / the Runes ledger / daily
   logs**, not into a **model's prompt or context — local or remote** — and not onto
   any **network**, **telemetry**, **screenshot**, or **crash dump**.
3. **No AI sees it.** Do not paste vault content into a chat, an agent prompt, a
   commit message, or a tool argument. Do not let an agent read a vault file unless
   the task is explicitly vault work being performed *inside* the vault — and even
   then, the agent's output stays in the vault.
4. **Work stays inside.** A vault project is worked on only while the vault is open,
   with tooling confined to the vault. Nothing is copied out — **not a snippet, not
   a paraphrase, not a "de-identified" excerpt, not a filename.**
5. **Nothing points in.** A repo or home file never names the vault mount or a path
   inside it.
6. **Seal when done.** When vault work ends, the vault is closed (Rule 14's vault
   scripts: `bin/vault/hnitbjorg.sh close`).

## Why this is a rule and not advice

An NDA breach cannot be undone by an apology or a `git reset`. It is a **legal
event**. The only control that works is to make the content never leave — so the
rule names every door it could leave by, and the ward watches the one door a
machine can watch.

## Enforcement

- **`bin/gates/guards/vault-guard.sh`** — while the vault is OPEN, it hashes every
  file inside the mount and **refuses to commit any file in the repo or the home
  whose content matches a vault file**. Installed as a **pre-commit hook** in both
  trees, so git runs it on every commit, including the hasty ones.
- **AGENTS.md** carries the duty to every agent, in the always-loaded contract.
- The vault is **sealed by default**; only the Allfather opens it.

**The honest limit.** A machine can catch a file copied out verbatim; it cannot catch
a screenshot, a spoken summary, or a paste into a remote model. Those are the
**operator's and the agent's** discipline, named in the law above — the ward raises
the floor, it does not replace the rule.

Confirmed by the Allfather 2026-10-11.
