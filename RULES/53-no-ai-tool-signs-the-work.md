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

- **2026-11-11** — written at the Allfather's word, the same day in Ymir and in the ForemanAI repository.
