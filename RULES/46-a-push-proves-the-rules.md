# 46 — A push proves the rules, for everyone who pushes

**Appended 2026-11-05** at the Allfather's word:

> *"make a rule for ymir on pushes to validate thet ymir are following the rules. we need to make a hook or a guard for this"*
> *"all usres that pusch need to make sure ymir are following the rules. not just us"*

## The law

```
push_law[5]{rule,what_it_means}:
  "THE CHECK IS ON THE PUSH, NOT ON THE PERSON","a rule that depends on who is pushing is not a rule. Every branch that reaches this repository is judged by the same wards, in the same order"
  "CI IS THE BINDING HALF","`.github/workflows/ymir-gates.yml` runs `bin/gates/ci-verify.sh` → `bin/gates/guards.sh` for every pull request, including one from a fork whose author never installed a hook. A collaborator cannot be asked to run what they cannot install"
  "THE HOOK IS THE CONVENIENCE","`.githooks/pre-push` runs the same one list in the author's own terminal, so a refusal costs seconds instead of a round trip. Seated by `git config core.hooksPath .githooks` (install step `gates`)"
  "ONE LIST, ONE ORDER","`bin/gates/guards.sh`'s `WARDS` array is the only list. A ward absent from it runs nowhere; a ward in it runs everywhere"
  "A REFUSAL NAMES FILE AND LINE","a gate that prints a summary is a gate nobody can act on. Every ward refuses with the file, the line and the rule it enforces"
```

## What the new ward asks — `bin/gates/guards/rules-compliance-guard.sh`

It judges **only what the push adds**, so a legacy tree is never re-litigated:

```
asks[4]{rule,question,refusal}:
  "RULES/06 · home RULES/changelog","does a NEW document carry its history?","`<file>: a new document has no CHANGE LOG section`"
  "RULES/README","does a new rule name itself and appear in the index?","`<file>:1 the first line must be '# NN — <title>'` · `a new rule is not named in RULES/README.md`"
  "home RULES/network.md N1/N7 · RULES/39","does a new line carry an internal address or a plain-HTTP cross-host URL?","`<file>: address or plain-HTTP URL in a new line`"
  "RULES/12 · RULES/23","is a new door executable and does it have a shebang?","`a new door is not executable (chmod +x)`"
```

## What it deliberately does not do

- It does not judge the whole tree — only the range `origin/<base>..HEAD`.
- It does not fix anything; a silent fix hides the habit that caused it.
- It does not replace the specific wards (numbering, weave, language, the ward's list); it asks the cheap universal
  questions those wards leave to a human to remember.

## CI IS THE GATE, AND A RED MAIN SHOUTS — appended 2026-11-11

At the Allfather's word (*"how can you make this more stable so we dont have this problem … and it dont
take 20 min per push"* · *"WE NEED TO MAKE A NEW SYSTEM FOR THIS!!"*), plan 243. The law above said CI
is the binding half. **It was not, because nothing required it and nothing announced it.**

Measured that night on `main`: four consecutive red runs — `10m37s`, `10m16s`, `7m30s`, `10m19s` — and no
issue, no rune, no voice said so. Every hand pushed into a red floor and every push failed for drift it
had not caused.

```
ci_law[5]{rule,what_it_means}:
  "A CHECK THAT IS NOT REQUIRED IS ADVICE","branch protection must require the `whole-tree` job in .github/workflows/ymir-gates.yml. A job renamed is a check that no longer exists, and GitHub reads a missing check as satisfied"
  "THE GATE RUNS WHERE A DELIVERY HAPPENS","every pull_request, and push on main. A branch with no PR is not delivered and does not owe a ten-minute run"
  "A RED MAIN IS ANNOUNCED IN ONE PLACE","bin/gates/main-red.sh opens ONE issue labelled main-red naming the failing gate, the ward's own finding and the commit that broke it; it updates it while red and closes it on the first green run. A red pull request opens nothing"
  "THE COMMIT IS NAMED, NOT GUESSED","the range is the last green main run to this one, narrowed by the paths the findings name. When several commits touched them, all are named rather than one invented"
  "A SUPERSEDED RUN PROVES NOTHING","concurrency cancels a PR run its own next push has replaced; a main run is never cancelled, because last-green is what attributes the next red"
```

**The law that stays:** the pre-push is the filter and CI is the gate, one list, one order
(`bin/gates/guards.sh`). The bypass is not a speed-up — it is the red that becomes permanent, because the
next hand pushes into a floor it cannot see.

## CHANGE LOG

- **2026-11-05** — appended (Hœnir, heimdall) with the ward, the hook and the CI path in the same change.
- **2026-11-11** — appended (Eindri `ci-is-the-gate`, plan 243 part E) after measuring four silent red
  `main` runs that night: CI becomes a REQUIRED, named check; a red `main` files one self-closing
  `main-red` issue naming the ward and the breaking commit.
