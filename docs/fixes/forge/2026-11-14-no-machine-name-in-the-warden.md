# No machine's name in the warden or in its record

**Date:** 2026-11-14 · **Component:** forge · **Door:** `bin/forge/queue-warden.sh`

## What was wrong

The warden's own header and the fix note beside it quoted the Allfather's word of 2026-11-14 *with the
heart's machine name in it*, and named that machine again in the config path
(`config/machines/<machine>/wardens.yaml`). The feature page named it too, and named this machine as
the place the clock is disabled.

A quotation is not a licence to ship a hostname. This repository is **100% agnostic** (`RULES/25`, and
the section appended to `AGENTS.md` on 2026-11-14): a shipped file names no machine, because the same
file must read true on every seat of the fleet and on a stranger's clone.

## What changed

| Where | Before | Now |
|---|---|---|
| the header comment | the heart's machine name | "the heart handles the merging of the PRs … `config/machines/<heart>/wardens.yaml`", with the heart defined as the machine `bin/skuld/role.sh` names heart |
| the fix note's quotation | the same name, twice | the same sentence without it, plus a dated note that says the correction was made and why |
| the feature page | a specific machine for the disabled clock | the rule: a machine whose wardens file carries `enabled: off` carries no clock |

The rule the door enforces was already machine-agnostic — it reads the role from the fleet registry in
the operator's home (`bin/skuld/role.sh resolve`) and never spells a hostname — so nothing in the
behaviour changed. `queue-warden status` on this machine still reads
`closed: merge: off in this machine's wardens file`.

## What stays

A fix note may say where a measurement was taken; a *rule* may not be written in terms of a machine.
The note beside this one keeps its `heimdall` mentions because they record where the old warden ran and
where a number was measured — that is the record of an event, not a rule that names a host.

## Limits

The two commits already pushed on this branch carry the name in their **messages**. History is not
rewritten to hide a fault (and a force-push is not this house's road); the correction is this note and
the commits after it.

## CHANGE LOG

- 2026-11-14 — written with the change, at the helm's word before the heart took the branch.
