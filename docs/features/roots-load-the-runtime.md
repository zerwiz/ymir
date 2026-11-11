# Your agents load Ymir from the runtime, in every folder

Ymir is a program. It is meant to work wherever you open an agent: in your home folder, in a client project, or
anywhere else. It should not only work when you happen to be inside the Ymir checkout. Each harness (pi,
Claude Code, OpenCode, Cursor, Codex) has a **root**, the global config in your home that every session reads.
The installer writes Ymir into those roots.

Those roots must load the **pinned runtime**. That is the checkout named in `$YMIR_HOME/config/runtime.env`,
which only ever stands on the merged default branch. They must never load a **working tree**, the checkout
where you or an agent switch branches. If a root loads the working tree, a `git checkout` changes the code every
agent on the machine runs, without anyone approving it. It can also load every pi extension twice and refuse all
of them.

## What you get

- **pi**, from any folder, loads Ymir's whole extension set from the runtime. That includes `ro` (read-only
  mode), `todo`, `open-editor` and the rest of `.pi/extensions`. It also gets the pi packages Ymir depends on:
  `pi-mcp-adapter`, `pi-web-access`, `@llblab/pi-telegram`, and `@juicesharp/rpiv-ask-user-question`, which
  provides ask-user. Those packages are listed in one place, the pi harness descriptor `.agents/harnesses/pi.yaml`.
- **Every harness root** points at the runtime. That covers pi's settings and MCP doors, the `.ymir-root` record,
  Claude Code's user-scope MCP doors, OpenCode, Cursor and Codex. If a root names a working tree, install and
  update point it at the runtime's copy of the same file. A check refuses it and tells you the fix.
- If no runtime is pinned, the checkout serves instead, and every command says so. It does not fall back
  silently.

## What you need

- Ymir installed, with a runtime pinned in `$YMIR_HOME/config/runtime.env`. You may write `$HOME` in that file.
  It is expanded.
- `python3`.
- The harnesses you use. A harness that is not installed is skipped, and the skip is not a failure.

## The commands

```bash
bin/seat/runtime-root.sh                     # which runtime your agents load, and why
bin/seat/runtime-root.sh scan                # every root config: any path into a working tree (exit 1 if one)
bin/seat/runtime-root.sh repoint --dry-run   # what would be re-pointed — changes nothing
bin/seat/harness-extensions-install.sh       # the one door: binds pi's root, installs its packages, re-points every root
bin/seat/harness-extensions-install.sh --check
bin/pi/pi-ensure.sh status                   # pi's packages and its root set (ro · todo · open-editor)
bin/seat/valknut-load.sh --check             # pi's root alone, with the remedy if it names a working tree
```

The installer and every update run `harness-extensions-install.sh` for you. Gróa runs it too. A home installed
before 2026-11-11 is fixed by migration `0022-roots-load-the-runtime`. `bin/agents/eir-doctor.sh check` has a
`roots` surface that names any working-tree path, and `eir-doctor.sh fix` repairs it.

## Limits

- A path whose file does not exist in the runtime is **held**: it is named, and left as it is. This usually
  means an errand's worktree whose change has not landed yet. Merge the change and redeploy the runtime with
  `bin/engine/runtime-deploy.sh`, or remove that entry yourself.
- Only the root configs listed above are read. In `~/.claude.json`, only the user-scope `mcpServers` is touched.
  The per-project state stays as it is.
- Each file that is changed keeps one backup beside it, named `*.bak-runtime-<time>`.
- When you start `pi` inside a Ymir checkout, the one-home door (`~/.pi/agent/bin/pi`) still gives that session
  the checkout's own tree, loaded once. That is how you test a branch. Everywhere else, pi loads the runtime.

## If it does not work

- `runtime-root.sh` says `checkout` although you pinned a runtime: the pinned folder is not a Ymir checkout,
  because it has no `bin/seat` or `RULES/`. Run `bin/engine/runtime-deploy.sh`.
- `scan` still lists a path after `repoint`: it is held. Read its row.
- pi still shows "Tool … conflicts": run `bin/seat/valknut-load.sh --check`. Its rows name the second home.
