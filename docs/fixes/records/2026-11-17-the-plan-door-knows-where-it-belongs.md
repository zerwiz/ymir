# The plan door knows where it belongs

**Component:** records (`bin/records/plan.sh` and every harness tool named `ymir_plan`) · **Date:** 2026-11-17

## What was wrong

There were two plan doors and only one of them was honest.

`bin/records/plan.sh` knew four scopes, found a shelf by its folder, refused an unknown project, numbered per shelf
and wrote the index row in the same act. The tool an agent actually calls — `ymir_plan`, in Pi's `elder.ts`, in
OpenCode's `ymir-tools.ts`, in Codex's `tools.mjs` and in the MCP face — was a second implementation of the same
thing: it hardcoded `whynotproductions/ymir`, built the path by string concatenation, padded the number to two digits,
wrote a bare stub and told the caller to add the README index row by hand.

Two faults followed from that, both measured:

1. **`--scope machine` meant "this host".** A plan about the heart, filed while it was being written, landed on
   heimdall's shelf. There was no way to name another machine, so the host was an assumption, not a parameter.
2. **The pad width was never fixed.** A shelf could end up carrying `0002` and `005` at once, and no door said so.

## The fix

**One behaviour in `bin/`, every harness reaching it.** All four faces now call `bin/records/plan.sh` and pass its
answer through whole — a refusal is the door's words, not a tool error. The tools gained the arguments the door needs
(`action`, `scope`, `host`, `owner`, `realm`, `project`, `from_meeting`) and lost their own path arithmetic.

**`--host` names which machine.** The shelf is `hodd/machines/<host>/plans/`, with the folder read from
`hodd/data/fleet.json`. A host the fleet does not know is refused **by name**, with the fleet's names printed — the
same reason an unknown project is refused. Machine plans now carry `host:` in their header.

**The route above the ledger.** With no `--scope` named, `new` asks the registries that already exist —
`hodd/identity/projects.yaml`, `hodd/identity/services.yaml`, `hodd/data/fleet.json` — and answers:

| Work about | The door does |
|---|---|
| Ymir itself, the fleet, the arms | files it on the ymir project's ledger |
| the Gimlé kit, a hosted surface | refuses: *"this is Gimlé's — a plan here would be read by nobody; open it there"* |
| the board, a card, a queue | refuses: *"this is a card, not a plan — the board holds it"* |
| a machine's repair, limits, faults | files it on that machine's shelf, naming the host |
| the Allfather's own work | files it in `hodd/plans/` |
| a project the registry knows | files it on that project's shelf |

A named `--scope` is the caller's word and always wins, and a refusal names the shelf it meant. `plan.sh route`
answers the same question and writes nothing.

**One pad width per shelf.** `new` adopts the shelf's own width instead of imposing `%03d`; `next_number` reads the
index as well as the files, so a number whose file has moved is still spent; `plan.sh check` reports a shelf carrying
two shapes and exits nonzero.

**Two questions are left to the Allfather** (plan 311 §5): whether Gimlé's plans live in its own repository or on the
shelf in this home (today both exist), and whether Trello mirrors the ledger. The Gimlé refusal names both places and
says whose call it is, rather than deciding.

## Proof

`tests/test_plan_door_knows_where.sh`, wired as gate `bin/gates/checks.d/0222-plan-door.sh`. Every case runs in a
throwaway home seeded from the shape `hodd/AGENTS.example.md` teaches; nothing touches the real ledger. It proves the
five things the plan owes: three scopes from one door with the index row in the same act, the heart's shelf from this
machine, an unknown project refused with the shelves it might have meant named, Gimlé and Trello named as such, and a
two-width shelf reported. `tests/test_codex_plugin.mjs` was updated to the door's contract (the plan **and** its row in
one act, the body appended, a refusal for an unknown project).

Measured on the Allfather's own home, read-only:

```
$ bin/records/plan.sh check
pad[1]{shelf,widths,files}:
  "svartalfaheim/whynotproductions/projects/ymir/plans","66,100","100-the-hotline.md … and 375 more"
```

That is a real fault the door now names: the ymir ledger carries two numbering shapes (plans 66–99 as `NN-`, 100+ as
`NNN-`). It is reported, not renumbered — renaming a plan is a hand's act, with a note (Rule 06).

## What is owed

- The mixed-width ymir ledger is **reported, not mended**: renumbering history is the Allfather's call.
- Gimlé's shelf in the home and Gimlé's own repository both hold plans; which one is canonical is plan 311 §5.

## CHANGE LOG

- 2026-11-17 — written with plan 311: the route above the ledger, `--host`, one pad width per shelf, and the harness
  faces reduced to faces over the door.
