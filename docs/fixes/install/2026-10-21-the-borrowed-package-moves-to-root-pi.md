# A borrowed pi package belongs in root pi, not in a public repo's project settings

**Component:** install · **Seat:** heimdall · **Date:** 2026-10-21

## What was wrong

`~/ymir/.pi/settings.json` declared `@juicesharp/rpiv-ask-user-question` at **project scope**. Two
consequences, both measured:

- **A clone inherits the declaration.** A user who grants project trust then installs and runs a
  third-party extension inside Ymir's directory — Ymir's npm tree, not their own pi home.
- **It loads only after trust, and only in a session whose cwd resolves that file** — so the
  operator's own tool went missing everywhere else, while the repo carried an obligation it cannot
  honour.

## The law this applies (plan 97 §5.1, verified against pi.dev `packages.md`)

> A borrowed pi package lives in **root pi** and is declared in the repo's manifest; an extension
> Ymir wrote itself lives in the repo's `.pi/extensions/` and is named by one path in root pi's
> settings. **The repo never declares a package it does not own.**

## What was done

```sh
pi install npm:@juicesharp/rpiv-ask-user-question            # root (~/.pi/agent/settings.json)
cd ~/ymir && pi remove --local npm:@juicesharp/rpiv-ask-user-question   # project
```

`pi remove` without `--local` writes **global** settings — the first attempt removed the root
install instead of the project one, which is how that flag was learned.

## Proof

```
root settings packages: [pi-mcp-adapter, pi-web-access, pi-lmstudio, @llblab/pi-telegram,
                         @juicesharp/rpiv-ask-user-question]
~/ymir/.pi/settings.json packages: []
cd /tmp && pi list  → the package is a USER package
cd ~/ymir && pi list → no Project packages section
```
