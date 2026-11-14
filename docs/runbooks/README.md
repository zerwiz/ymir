# Runbooks

Task-oriented guides for operating a Ymir home. Each is written for the
operator, not just the maintainer.

```
runbooks[13]{file,subject}:
  "models.md","choose models per agent; local (llama.cpp) vs hosted; per-machine overlays"
  "agents.md","Eindri profiles: where they live, how to add/run/dispatch one"
  "agent-permissions.md","set what each agent may do — the bash gap and recommended postures"
  "updates-and-migrations.md","update the runtime; heal old homes (bin/engine/ymir-migrate.sh)"
  "secrets-and-hoard.md","Hodd: secrets by path, secret-guard, rotation + history scrub"
  "worktrees-isolation.md","Yggdrasil worktrees: isolated by default, --main opt-out, see them in Hlidskjalf, merge"
  "a2a.md","Ratatoskr — talk between agents over A2A: engine, MCPs, addressing, injection, registration"
  "realm-onboarding.md","onboarding a realm/tenant"
  "runtime.md","the pinned checkout, the deploy verb, the ward — a deployment is a version, not a copy"
  "harnesses.md","which harnesses Ymir knows (pi · opencode · claude · codex · cursor · grok · kimi · muse · zed), what each accepts, where each stores history"
  "platforms.md","Linux · macOS · Windows, the installers, the portable verbs, and the ratchet that keeps the debt falling"
  "gates-and-wards.md","what the wards refuse, how to add one, and what to do when one is red"
  "add-an-app.md","add an app to Ymir: the release, the one launcher command, the rune, both machines"
  "send-an-eindri.md","send out an Eindri: the brief and its fixed core, a herdr seat per errand, the stamped send door, one gathered PR"
```

Related: `.agents/skills/galdr-ymirsystem/assets/installation.md` (first setup),
`.agents/skills/galdr-ymirsystem/assets/registry.md` (inventory).

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
- **2026-11-13** — `add-an-app.md` added to the shelf (plan 275).
- **2026-11-14** — `send-an-eindri.md` added to the shelf (plan 275 item 31).
