Read when: committing, pushing, opening or repairing a pull request, writing a fix note or a feature page, or touching GitHub, worktrees or the gates.

# Delivery: how a change leaves the hall

Part of the Ymir contract. The prior text is kept verbatim in `docs/contract-history/AGENTS-2026-11-24.md`.

## Every change leaves by pull request

Work is done in a Yggdrasil worktree, committed on a branch, pushed, and opened as a **pull request**
(`gh pr create`) against the default branch. That PR is what **Glitnir's Reviews** surface seals. The Allfather's
approval *is* the merge, and Mjollnir never force-merges (RULES/08, law 4: code merges and production deploys need his
explicit approval).

Do **not** merge into `main` or push to it directly. A local merge on a verbal "word" is a decision, not a delivery, and
it leaves Glitnir with nothing to review. The road is: branch → worktree → tests → `gh pr create` → Glitnir review →
the Allfather seals → merge. If work is already sitting on local `main`, ship it as a PR (a branch at that commit)
before doing anything else.

The gate is enforced in git hooks, seated by the install step `gates`:

| Ward | What it refuses |
|---|---|
| `bin/gates/guards/branch-guard.sh` | a push to a protected branch (except the document road below) |
| `bin/gates/guards/fixes-guard.sh` | a push whose range carries no new fix note in `docs/fixes/` naming its component (`YMIR_SKIP_FIXES_GUARD=1` is the loud override) |
| `bin/gates/guards/identity-guard.sh` | a commit authored with a personal mailbox instead of the account's noreply address |

## Two more roads (2026-11-12, RULES/08)

At the Allfather's word: *"documents should be able to push on main"* · *"if multiple agents are sent out at the same
time, it's much better to merge the branches locally into one push … so everybody is going through the gates."*

- **Documents only may land on `main`.** A push whose every changed file is Markdown under `docs/` (a fix note added
  only, never `docs/features/_catalogue/`), or an append-only `RULES/*.md` change, may go straight to `main`.
  `branch-guard.sh` enforces the set, and a rule change still carries its fix note.
- **Errands sent out together ship as one batch.** Brief them with `--mode batch`; each commits on `eindri/<id>` and
  never pushes. The helm runs `bin/forge/gather.sh --finished` (or names the ids): one worktree, one gate run, one push,
  one PR. A lone errand may still push its own PR. The how-to is `docs/features/gather-a-batch.md`.

## The gate proves a change once (2026-11-09)

At the Allfather's word: *"if we need to fix a pr we dont need to push it thru the gates again, cuz it has already been
proven to be good."* A PR is judged **when it is first offered**, and that judgement stands. When a repair is pushed
into an approved or green PR (a stale woven catalogue, a register one line behind, a renamed guard, a typo in a fix
note, a rebase onto a moved main):

- the **pre-push wards still run**, because they are cheap and judge the tree the push comes from;
- the heavy **CI suite (`bin/gates/ci-verify.sh`) does not hold the merge** of the repair;
- the repair **still carries** its own fix note, and its own test when it changed behaviour.

A repair that changes behaviour beyond the fix (a new door, a new default, a new claim on the system, a new public
surface) is new work and earns its own proof. The word "fix" is not a licence to slip a feature in behind an approval.

## Fix notes: one file per fix

Recent runtime and policy changes are in `docs/fixes/<component>/`, **one file per fix**, never rewritten
(`bin/gates/fixes.sh list|show`). The component's directory is its history. The old `CHANGELOG.md` monolith is retired.
Every change carries one fix note, and a test when behaviour changed.

## Feature how-tos (RULES/14)

`FEATURES.md` (repo root) is the master, append-only catalogue of every feature and function Ymir has. `docs/features/`
is where a **person using Ymir** learns to use it: one plain-language page per feature, saying *what it is · what you
need · the commands · limits · if it does not work*, written for the operator. `README.md` links both, and the index
lists every page.

- A user-facing feature has a page under `docs/features/`. A feature with no page is not finished.
- The same change adds the row to its section fragment in `docs/features/_catalogue/` and the page (or updates them).
- `FEATURES.md` is **woven**, never hand-edited (RULES/06 · Þættir): add the row to a fragment, then run
  `bin/records/weave-features.sh`. Correct by a new entry, never by erasing.
- Keep them current: when a command, flag or limit moves, the page moves with it.

The deep reference stays where the code lives (the Galdr assets under `.agents/skills/galdr-ymirsystem/assets/`).
**When you build a feature, write its how-to before you call it done.** Before claiming done, run
`bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh`.

## GitHub, the registry and the engines

- The Allfather works with his **own GitHub login** (`gh` OAuth locally; a **GitHub App** per project root
  (`workspace/<project>`) on the server). Never a shared token.
- Every project's `host/owner/repo/remote/default_branch/auth` is recorded in the **master project registry**
  (`$YMIR_HOME/hodd/identity/projects.yaml`, a `git{}` block). It is consumed by `bin/forge/mjollnir.sh` (issue→PR),
  `bin/forge/yggdrasil.sh` (worktree) and `bin/forge/github-deploy.sh` (deploy). Auth is a **reference**, never a value:
  `GITHUB_TOKEN`, `GITHUB_APP_ID`, `GITHUB_APP_PRIVATE_KEY`, `GITHUB_INSTALLATION_ID`, resolved from
  `$YMIR_HOME/hodd/secrets/platform.env`. Never hardcode or commit a secret.
- **Engines (open-source first):** **treehouse** (`github.com/kunchenguid/treehouse`) powers **Yggdrasil** worktrees;
  **sandcastle** (`github.com/mattpocock/sandcastle`, `@ai-hero/sandcastle`) powers **Utgard** sandboxes;
  **no-mistakes** (`github.com/kunchenguid/no-mistakes`) powers the clean-PR gate behind the `no-mistakes` posture
  (`.no-mistakes.yaml`). A Norse shell over the OSS engine.
- **Mjollnir:** GitHub issues → Yggdrasil worktree + Utgard Eindri → tests → PR → Glitnir human review. It never
  force-merges; human approval is always required. GitHub webhooks are HMAC-verified before processing.

## Laws that ride every commit

- Stage named files; never `git add -A`.
- No AI attribution anywhere: no co-author trailer, no generated-by line.
- Never remove a feature, only the parts the task names.
- Output over process: always produce a tangible artifact (a file, a PR, a report, a commit), and log every significant
  action to Runes.
