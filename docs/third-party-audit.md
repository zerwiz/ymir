# Third-party audit — what we use, its licence, and its demands

> **Status:** audit of every external project Ymir uses, the demands each licence
> places on us, and where we comply. **Do not publish the npm package until every
> row below reads COMPLIANT.**
>
> Licences verified against the GitHub licence API (SPDX), not from memory.

## The rule

Ymir is **Apache-2.0**. We adopt validated OSS engines under Norse shells. Each
adopted project keeps its own licence — we never relicense it, and we carry its
demands forward: its copyright notice, its licence text, and (for Apache-2.0) a
`NOTICE` attribution and a statement of changes if we modified it.

## Engines (adopted, not vendored)

```
engines[6]{project,used_for,licence,demand}:
  "kunchenguid/treehouse","Yggdrasil worktrees","MIT","retain copyright + licence text"
  "mattpocock/sandcastle","Utgard sandboxes","MIT","retain copyright + licence text"
  "kunchenguid/no-mistakes","clean-PR gate","MIT","retain copyright + licence text"
  "NousResearch/hermes-agent","worker runtime","MIT","retain copyright + licence text"
  "earendil-works/pi","coding harness","MIT","retain copyright + licence text"
  "a2aproject/a2a","A2A 1.0 protocol","Apache-2.0","NOTICE + attribution + change statement"
```

## Vendored code (we ship it — highest obligation)

```
vendored[1]{project,where,licence,demand}:
  "FaqFirebase/pi-desktop","apps/sessrumnir (the Sessrúmnir desktop GUI)","Apache-2.0",
  "MUST ship the Apache-2.0 text, a NOTICE with their copyright, AND state that we modified it"
```

> Apache-2.0 §4: keep the licence, keep the `NOTICE`, mark modified files. If we
> patched pi-desktop, that must be written down. **This is the row to check first.**

## Studied, not shipped (reference only — no obligation)

```
studied[6]{project,why}:
  "can1357/oh-my-pi (MIT)","prior art for the pi surface"
  "microsoft/agent-framework (MIT)","multi-agent patterns"
  "langchain-ai/langgraph · langchain · deepagents","agent graphs, reference"
  "crewAIInc/crewAI","crew patterns, reference"
  "anthropics/claude-code · anthropic-sdk-python","harness + SDK reference"
  "openai/openai-python · stanfordnlp/dspy","SDK + prompting reference"
```

Reference study places **no** obligation; it is listed only so the record is whole.

## Where we comply (and where we do not yet)

```
compliance[5]{item,state,action}:
  "LICENSE (Apache-2.0) at the root","DONE","—"
  "NOTICE at the root","PARTIAL","must list every engine + pi-desktop, with copyright"
  "hermes-agent MIT text","DONE","bin/hermes-ensure.sh installs it from source; text carried"
  "pi-desktop (Sessrúmnir) Apache NOTICE + change statement","MISSING","write NOTICE entry + list our patches"
  "README credits section","MISSING","name every engine and link its repo, with its licence"
```

## The demands, plainly

1. **MIT (treehouse, sandcastle, no-mistakes, hermes-agent, pi, oh-my-pi, agent-framework)** —
   keep the copyright line and the licence text. That is the whole demand. Put
   them in `NOTICE` / a credits section.
2. **Apache-2.0 (pi-desktop *, a2a)** — keep the licence, include their `NOTICE`,
   and **state any changes we made**. \* pi-desktop is the one we actually ship.
3. **Nothing here is copyleft** — no GPL/AGPL — so we may license Ymir as
   Apache-2.0 and distribute the npm package, provided 1 and 2 hold.
4. **Trademark** — naming our shells after Norse figures is ours; we do **not**
   use any project's name or logo as if it were ours. The README must say
   "Norse shell over the OSS engine" and name the engine.

## Before `npm publish`

```
gate[4]{n,check}:
  "1","root NOTICE lists every engine + pi-desktop, each with its copyright line"
  "2","pi-desktop's Apache-2.0 text + NOTICE + our change statement are present in apps/sessrumnir"
  "3","README has a Credits section naming each engine, its repo, and its licence"
  "4","package.json has no \"license\" claiming more than Apache-2.0 for vendored code"
```
