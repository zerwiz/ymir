## desktop · 2026-11-24 — the terminal cloth gets progress, and the plain scripts are dressed

### Why

The cloth (`bin/desktop/ymir-style.sh`) had a title, lines and a next-step block, but nothing for the long hour:
a download, a clone, an install or a build. Those printed raw npm and git noise, or nothing at all. Nine
user-facing scripts, the curl-piped installer and the release road were still plain.

### What changed

| file | change |
|---|---|
| `bin/desktop/ymir-style.sh` | new primitives `style_step`, `style_steps`, `style_download`, `style_bar`; `CI` now counts as "no human" |
| `install.sh` | an inline, minimal copy of the primitives (it runs before the package exists) |
| `bin/agents/groa-update.sh`, `bin/desktop/smidja-board.sh`, `bin/engine/ymir-config.sh`, `bin/engine/ymir-migrate.sh`, `bin/host/host-sense.sh`, `bin/records/mimir.sh`, `scripts/electron.sh`, `scripts/stop.sh` | title, one line per result, steps around npm and bun calls |
| `bin/apps/apps.sh` | `install`, `update` and `rollback` run under `style_step --data`; the rows still reach stdout |
| `bin/engine/release.sh`, `bin/engine/release-build.sh`, `bin/fleet/fleet-deploy.sh` | the build and `npm ci` run under a step; fleet-deploy prints one marked line per refresh |

> [!IMPORTANT]
> Off a terminal, under `NO_COLOR`, or in CI the output is plain: no escape byte, no carriage return, one line
> per step. A step always returns the command's own exit code. `groa-update.sh` keeps its old stamped step
> lines off a terminal because `bin/gates/tests/test_groa_steps.sh` pins them.

### Proof

`bash .agents/tests/style-progress.test.sh` (18 checks), `bash bin/gates/tests/test_groa_steps.sh` (17),
`bash bin/engine/tests/test_release_borrow_closure.sh` (10). A scripted terminal run of `install.sh` against a
stand-in `npm` ended ✓ on success and ✕ with the log tail on failure.
