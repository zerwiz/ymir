## sessrumnir · 2026-11-19 — the seat borrows Ymir from its launcher, not from three folders up

### Why

Since the split, Sessrúmnir installs into its own home:
`~/.local/share/ymir-apps/sessrumnir/releases/<sha>`. The app still found Ymir's tree by going three
folders above itself. That was right only while it lived at `<ymir>/apps/sessrumnir`.

From the apps home, three folders up is `~/.local/share/ymir-apps/sessrumnir`. Measured in the live window
through DevTools (port 9316), after `bin/apps/apps.sh install sessrumnir` and a start from the apps home:

- `piDesktop.system.getPath('ymirRoot')` answered `/home/<user>/.local/share/ymir-apps/sessrumnir`.
- `piDesktop.system.fleet()` answered **0** agents, while `bin/desktop/hlidskjalf-agents.sh` answered the
  whole roster.
- Every pi seat the window raised inherited the wrong root. Its stderr said
  `gna-pi-watch: could not run bin/time/saga-session-start.sh — … ymir-apps/sessrumnir/bin/time/saga-session-start.sh: No such file or directory`.

### What changed

The fix has two halves, one in each repo.

| Half | File | Change |
|---|---|---|
| Ymir (this change) | `bin/desktop/sessrumnir-launch.sh` | Exports `YMIR_ROOT` as the Ymir tree the launcher runs from (the pin, or a checkout), and logs it on the `[launcher]` line. |
| The app (`zerwiz/sessrumnir`, owed) | `bin/sessrumnir.js`, `src/main/ipc/system-handlers.ts` | Keeps an inherited `YMIR_ROOT`; else uses the pin (`YMIR_RUNTIME_DIR`); else the old in-tree layout. A candidate counts only when it holds `bin/desktop` and `RULES`. With none, the Ymir shortcuts hide. |

> [!IMPORTANT]
> The Ymir half alone does not fix the window. `bin/sessrumnir.js` overwrites `YMIR_ROOT` unconditionally,
> so the app half must land in `zerwiz/sessrumnir` (branch `split/from-ymir`) and be installed with
> `bin/apps/apps.sh update sessrumnir`. The app half alone works on the `ymir-app` road, which exports
> `YMIR_RUNTIME_DIR`.

The app half is one commit, `sessrumnir: find Ymir's root from the launcher or the pin, not three folders up`.
It was built and proved on this machine from a local clone, and was not pushed.

### Proof

Both halves together, the app started from the dev road (`YMIR_APP_SESSRUMNIR_DIR`) through this launcher:

- The window mapped: `hyprctl clients` listed `ymir-sessrumnir`, `mapped True`, titled `Sessrúmnir`.
- `getPath('ymirRoot')` answered the Ymir checkout, and `fleet()` answered **35** agents.
- A pi seat raised in a probe workspace ran `commands.bash` and printed `seat-answers` and the right
  `YMIR_ROOT`. The log held no `saga-session-start.sh: No such file` line.
- `npm run typecheck` in the app reports the same 5 errors before and after the patch. None of them is
  in the two files it touches.

### Left open

- With the right root, the seat's first start took 80.8 s (`[Pi] Ready after 80768ms`), against 12.3 s
  when the saga hook failed at once. The session-start hook now really runs. Whether 80 s is acceptable
  is a separate question for the seat's start path.
- The file tree's Ymir shortcuts open `hodd/`, `svartalfaheim/` and `workspace/` under the Ymir **tree**.
  Those folders live in the operator's home (`$YMIR_HOME`), not the tree. That was already wrong before the
  split and is not changed here.

## CHANGE LOG

- 2026-11-19 — written with the change.
