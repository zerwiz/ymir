## runtime · unversioned · 2026-09-27 — the foundation of several Ymirs, one company: the grants law and the namespace-scoped journal

### Why

Plan 58's section *Several Ymirs, one company: shared projects over A2A*
(2026-09-26) federates **several operators' Ymirs** — many minds, each with its
own private hoard, cooperating on a company project. Plan 42 federated one
operator's machines (one mind, many bodies); this crosses the realm law
(Rule 05), so a shared company namespace must be an **explicit grant** between
operators, never a blanket merge. The plan named the gap plainly: *"the grants
law, the namespace-scoped journal, the cross-operator well share, and the Óðrerir
company view are all unbuilt."* This is the foundation — the first two of the
four, plus the card alignment the other two will stand on. The remainder is
named below, not implied.

### What

**1. The grants law — explicit, signed, cross-operator shares.** A new config
kind, `grants`, over `hodd/identity/grants.yaml`:

- `config/grants.schema.json` — the registry shape: a grant names its
  `grant_id`, its `namespace`, a `role`, and its two **parties**
  (`grantor` · `grantee`), each `{ymir, operator, heimdall, card}`, plus the
  Heimdall `signatures` (ed25519/JWS).
- `src/ymir_runtime/grants.py` — the realm law as a semantic check, in the
  load-with-schema voice (Phase 7): a grant that crosses operators is REFUSED
  without a signature from EACH party's Heimdall, naming the Heimdall that did
  not sign; a party whose `card.signed` is true must have its own signature; a
  foreign signer is refused; a grant naming one Heimdall on both sides is
  refused; a duplicated `grant_id` is refused. The door is
  `python3 -m ymir_runtime.grants [check|signers|default]`, and the config door
  reaches it as `bin/gates/checks/ymir-config-check.sh validate <grants.yaml>`.
- The data resolves from the hoard (`default_registry()` →
  `<hoard>/identity/grants.yaml`); no operator identity is written into the tree.
  `config/grants.yaml.example` is a placeholder scaffold only.

**2. The namespace-scoped journal.** Plan 51's outbox/fold trio is extended, never
mutated:

- `bin/records/journal-append.sh --namespace <ns>` adds an `ns` field to the entry (and
  refuses a malformed namespace, exit 2). An entry with no `ns` is unchanged —
  the operator's own.
- `bin/records/journal-receive.sh` folds an entry with `ns` into
  `journal/folded/<ns>/<host>.jsonl` and one without into
  `journal/folded/<host>.jsonl`. A company project's entries are thus scoped by
  **operator (host) + namespace** and never merged into a peer's lineage; an old
  entry with no namespace reads as the operator's own. `--status` names the
  namespaces it folded; `--dry-run` names the scopes it would fold.

**3. Typed-card alignment (gated on plan 58 Phase 6).** The grant's `card` block
is deliberately the SAME shape as the shared A2A agent-card contract
(`packages/contracts` `AgentInterface`: protocol · endpoint · signed) — one
contract, no second one invented. **Dependency:** `packages/contracts` is being
forged by the `phase6-typed-surfaces` errand and is **not yet on main** at this
writing, so this PR does not add a TS file that would not compile. The offline
proof detects the contract when it lands and asserts the grant card block still
matches its three fields; until then it records the declared dependency. The
grant already carries the `signed` bit the shared `AgentInterface` names.

### The proofs (run, not asserted)

`tests/e2e/several-ymirs-foundation-proof.sh` — offline, fixture-driven:

```
several_ymirs_proof[4]{gate,result,detail}:
  "a signed cross-operator grant validates","PASS"
  "a cross-operator grant missing a signature is refused, naming heimdall-b","PASS"
  "a namespaced entry folds into its namespace only (own=1, scoped=1)","PASS"
  "typed-card dependency declared: phase6 packages/contracts not yet on this tree (gate holds)","PASS"
several_ymirs_proof_verdict[1]{verdict,detail}:
  "pass","grants law + namespace-scoped journal proven"
```

- `python3 -m unittest` — 141 tests, green (14 new in `test_grants.py`).
- `.agents/tests/journal.test.sh` — extended: a namespaced entry carries `ns`, a
  plain one does not, a malformed namespace is refused, `--list` reports it.
- `.agents/tests/journal-fold.test.sh` — extended: the own log holds only the two
  unscoped entries, the company entry folds into its namespace only, replay stays
  idempotent, `--status` names the namespace.

### Honest state — what is NOT here

The federated stack is not built by this errand. **Cross-operator well share** and
the **Óðrerir company view** remain unbuilt and ride their own errands; the
company-heart routing for namespaced outboxes and the `grants_grant`/`grants_revoke`
tools on Skuld also follow. This is the foundation: the law and the scoping the
rest stands on.

### Files

- `config/grants.schema.json` · `config/grants.yaml.example` (new)
- `src/ymir_runtime/grants.py` · `src/ymir_runtime/tests/test_grants.py` (new)
- `src/ymir_runtime/config/load.py` · `config/__main__.py` (kind registered)
- `src/ymir_runtime/tests/test_config.py` (five kinds)
- `bin/records/journal-append.sh` · `bin/records/journal-receive.sh`
- `.agents/tests/journal.test.sh` · `.agents/tests/journal-fold.test.sh`
- `tests/e2e/several-ymirs-foundation-proof.sh` (new)
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md` (§7.4, §7.5)
- `.agents/skills/ratatoskr-a2a/SKILL.md` (the federation section)
