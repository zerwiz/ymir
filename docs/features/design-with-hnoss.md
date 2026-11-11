# Design with Hnoss — the design smithy

Ymir can make real design artifacts: prototypes, landing pages, dashboards, decks,
images and motion video. The engine is **OpenDesign**, an open-source local-first
design studio; **Hnoss** is the craft's name in this house. Everything it produces
is real files — HTML and CSS — which you can open, export, or hand to a builder.

## What it is

A design studio you run on your own machine, wired to your own model. Ask for a
hero, a landing page, a dashboard or a deck; the engine composes the design prompt,
your model writes the HTML, and the file lands in a project you can look at in the
Studio at `http://127.0.0.1:7456`.

The brand contract is a `DESIGN.md` — palette, type, posture. Every render reads
it, so a design cannot drift away from the house look by accident.

## What you need

- The Studio running: `bin/pi/open-design.sh start` (this machine runs it as a
  Docker container on loopback).
- The MCP bridge `open-design-mcp` on your PATH (`npm i -g open-design-mcp`).
- A model that answers. By default Hnoss uses whatever provider and model **pi's
  own settings name** — the same brain your agents use — so you do not configure
  models twice.

## The commands

```
bin/pi/open-design.sh start|stop|status     the Studio itself (:7456)
bin/pi/hnoss-ensure.sh status               which door, which provider, which model
bin/pi/hnoss-ensure.sh ensure               seat the launcher + pi's MCP entry
bin/pi/hnoss-mcp-launch.sh --resolve        what the door would be, without raising it
bin/pi/hnoss-mcp-launch.sh --print          raise the door and print it
```

From an agent, the design tools appear as MCP tools named `od_*` — projects,
files, lint, brief, and `od_generate_design`.

## Which model it uses

Three cases, and the door says which one it took:

- **A rail in your pi registry** (`llama-swap`, `llamacpp-*`) — dialled directly at
  its own address. Nothing else is involved.
- **A provider built into pi** (`opencode-go` and its peers) — reached through the
  **Bifrost bridge** on loopback, which adds the session header that gateway
  requires and holds the key. This is why the model works here even though the
  design client itself cannot speak to that gateway.
- **Anything else** — refused, by name. There is no silent fallback to a
  different model; a design that generated on a model you did not ask for is worse
  than a design that did not generate.

## Limits

- The Studio is loopback-only and single-tenant: it is for this machine, not for
  the LAN and not for a tunnel.
- The default heap in the container image is too small for a real page. The
  operator's deployment `.env` raises it (`NODE_OPTIONS`); if every generation dies
  with "daemon unreachable", that is the first thing to look at.
- A very long page takes minutes. It is not hung.
- Hnoss designs; it does not build product code. The builder takes it from there.

## If it does not work

Run `bin/pi/hnoss-ensure.sh status` first — it names the four things that can be
wrong: no MCP server, no launcher, no pi MCP entry, or a model door that refuses
(with the reason in the refusal).

Then `bin/pi/open-design.sh status`. A green container is not a reachable door: the
real check is that `http://127.0.0.1:7456/api/health` answers.

For the model itself, the log tells the truth:
`state/model-bridge-4613.log` records every request with `model=<id>
provider=<provider>`, so you can see exactly which model served the page.

## CHANGE LOG

- **2026-11-10** — written when the model door was fixed: Hnoss now reaches the provider pi
  itself uses, and says which door and which model it took.
