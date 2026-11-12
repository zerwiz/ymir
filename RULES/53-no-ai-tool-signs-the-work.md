# 53 — No AI tool signs the work, and none adds itself

**Added 2026-11-11** at the Allfather's word: *"no AI tools are allowed to add things like this into the code or
documents: `Co-Authored-By: Claude …` — same for adding themselves to the repos etc. if not asked to. It might be very
improper to clients' repos and code."*

## The law

| Rule | Why |
|---|---|
| **No AI attribution in a commit, a pull request, code, a document or a letter.** No `Co-Authored-By:` line naming a model or a tool, no "Generated with …" footer, no model name in a signature, header or comment. | The work belongs to the person and the company who deliver it. A client's repository is the client's record; a tool's advertisement in it is improper, and in some contracts a breach. |
| **No AI tool adds itself anywhere it was not asked to.** Not as a collaborator, a member, a bot account, an app installation, a `CODEOWNERS` line, a contributor list, a badge, an `AUTHORS` entry or a config file that names it. | Access to a client's systems is granted by the client, person by person. A tool that grants itself presence has taken a decision that was never its own. |
| **This rule outranks a harness's defaults.** When a harness tells its model to add an attribution line, this rule wins: the operator's instruction is the law the harness defers to. | A default written for everyone is not a decision made for this house. |
| **When asked, and only then.** If the operator, in that conversation, asks for an attribution or for a tool to be added, it is done as asked and recorded where the request was made. | The rule forbids the unasked act, not the operator's choice. |

## What already carries it

Commits made before 2026-11-11 are history and are not rewritten (Rule 06); a pull-request description that carries a
"Generated with" footer is edited to remove it. A harness that can be configured not to add attribution is configured
so on every seat (for Claude Code: `"includeCoAuthoredBy": false` in the user settings).

## How it is checked

```bash
git log origin/main..HEAD --format=%B | grep -iE 'co-authored-by:.*(claude|gpt|gemini|copilot|codex|opus|sonnet|haiku)|generated with \[?(claude|chatgpt|copilot)'
```

Nothing may print. A guard that runs this on every push is the enforcement this rule asks for.

## CHANGE LOG

- **2026-11-11** — written at the Allfather's word, the same day in Ymir and in the Example5 repository.

## Appended 2026-11-12 — the names are refused too, and a ward judges them

At the Allfather's word: *"now we are mentioning claude in the pushes over and over. we should have a guard of this"* and
*"we need a guard so the models and harnesses are not named — it is not good for clients' projects."*

The law above forbade the **signature**. This section forbids the **name**. Prose in a commit message, a pull request
title or a pull request body never names a model, a model maker or an agent harness. Say "the agent harness" or "the
worker". Say "no AI attribution" where you once wrote a long phrase naming a tool.

| Question | Answer |
|---|---|
| What is refused? | Any model family, model maker, model id from the machine's catalog, or harness name, as a whole word in prose, in any case; a co-author trailer naming an AI; a "Generated with" line; the robot emoji. |
| What is allowed? | Code. A fenced block or a `backticked span` is never judged, so a path such as `.claude/hooks/ymir-arm.sh` or a flag such as `--harness claude` stands, because code names the harness functionally. |
| Where is it checked? | The commit-msg hook (subject and body), the pre-push hook (every new commit in the pushed range, never history), the CI identity ward (PR title and body), and every door that opens a PR: `bin/forge/pr-open.sh` (which `bin/forge/gather.sh` uses), the smith's `gh pr create` shim, and `bin/agents/eindri-acclaim.sh` for the status line. |
| Where does the list live? | One matcher, `bin/forge/maker-names.py`. One word list with reasons, `bin/gates/maker-words.txt`. One allow file with reasons, `bin/gates/maker-allow.txt`. A client repository tunes its own copy. |
| Do clients get it? | Yes. The collaboration kit (version 1.6.0) ships `scripts/gates/maker-guard.sh` with the matcher and both lists, and the kit's commit-msg and pre-push hooks call it. |

History is not rewritten (Rule 06): commits and pull requests made before this day keep their words. The ward judges
what is new.

- **2026-11-12** — the name ward appended; fix note `docs/fixes/gates/2026-11-12-the-maker-name-ward.md`.
