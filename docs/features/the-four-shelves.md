# The four shelves — where your own material goes in your home

**What it is.** Your home (`$YMIR_HOME`, by default `~/Documents/ymirhome`) has four shelves. Each holds one
kind of material, so a path tells you what a file is:

| Shelf | Holds | Never holds |
|---|---|---|
| `hodd/` | the house's **record**: memory, identity, plans, secrets, reference, docs | anything a running program writes, your own notes, build output |
| `life/` | **your own material**: `personal/`, `work/`, `marketing/`, `meetings/`, `outreach/` | the house's ledger, a secret, runtime state |
| `state/` | **runtime state** that supervisors write and rewrite | anything you must keep, anything another machine must read |
| `config/` | your **settings**, per machine | a secret value, a record |

Your companies and their projects live in their own realm folders, beside these four.

## Where to look it up

This page does not list every path, and no other page should either. Two files in your home say how *your*
home is actually laid out:

- `.ymir-layout.yaml` — every shelf and its path.
- `hodd/identity/home.yaml` — the master register: every register the home holds, and the shelf it governs.

If you are unsure where something belongs, open `home.yaml` first.

## What you need

Nothing beyond a normal install. A fresh install creates the four shelves. An update runs the migration below
for you.

## The commands

See what the migration would move, without moving anything:

```sh
bash .agents/migrations/0026-life-and-state-out-of-hodd.sh --dry-run
```

Run every pending migration, this one included:

```sh
bin/engine/ymir-migrate.sh apply
```

Ask the healer whether every shelf holds its own kind:

```sh
bin/agents/eir-doctor.sh check
```

The `hoard` row names any file on the wrong shelf, with the path and the rule.

## What the migration does

It moves your old `hodd/life` folder into `life/`, the old `hodd/state` folder into `state/`, and the topic
folders of the old `hodd/workspaces` into `life/<topic>/`.

- It writes a record of every move **before** the first one, under `hodd/reference/moves/`.
- It never deletes and never overwrites. If a name already exists, the incoming file is kept beside it as
  `<name>.from-hodd`.
- It counts the files before and after, and stops loudly if the two differ.
- Run it twice and the second run says there is nothing to do.

It then leaves two links, `hodd/life` and `hodd/state`, pointing at the new shelves. Older scripts that still
name the old folders keep working and write to the right place. The links last one release cycle, and they are
never committed.

## Limits

- Anything in the old workspaces folder that is not one of the five topics is left where it is, and the
  migration names it. Only you can say where it goes.
- A new file that names one of the retired folders is refused at commit. A line that must quote the old path,
  such as a history note, can carry `retired-path-ok:` with a reason.

## If it does not work

- **The count did not match.** Nothing further runs. Read the newest file under `hodd/reference/moves/`. It lists
  every move that happened.
- **"could not link hodd/state".** A program kept writing into the old folder during the move. Run the
  migration again when the machine is quiet.
- **Eir says a layout key names a path that does not exist.** Your `.ymir-layout.yaml` is stale. Point the key at
  the real folder, or remove it.

## CHANGE LOG

- **2026-11-19** — written with plan 331: the four shelves, migration 0026 and the one-cycle links.
- **2026-11-20** — carried to main from the developer seat that built it, at the Allfather's word "make so all carry the new home".
