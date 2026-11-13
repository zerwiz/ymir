# Rule 07 gains clause C: a new port is a random five-digit number

**Date:** 2026-11-12 · **Component:** rules · **Door:** `RULES/07-config.md` (appended amendment C)

At the Allfather's word — *"Use a random 5 digit ports to avoid conflicts — this should already be a global
rule for all agents and LLMs"* — RULES/07 gains an appended amendment. A new service never takes a well-known
or four-digit default port. It takes a random port in `10000–32767`, below the kernel's ephemeral range
(`32768–60999` on this host), checked free with `ss`, and recorded once as the env default that the app, the
published port, the proxy and the health probe all read. A project with several ports takes a consecutive
block from a random base. Ports already in service are not moved for this rule alone. The clause applies to
every agent and every LLM tool, Eindri included.

## CHANGE LOG

- 2026-11-12 — written with the change it describes.
