# The capability register was double-encoded, and it turned every push red

**Date:** 2026-11-07 · **Component:** gate · **Status:** fixed — the register is regenerated clean, and the ward
it tripped is now green

## The fault

`bin/gates/guards/language-guard.sh` refused every push with one finding:

```
"a letter that is not English, Old Norse or runic",".agents/assets/agents/capabilities.md","a Latin-1 letter x460"
```

The register was **mojibake**: an em dash had been written as the three bytes `0xE2 0x80 0x94` read as Latin-1 and
written back out as three characters — the classic double-encode. Four hundred and sixty of them, on 466 lines — the whole file.

It is not a language fault. It is an encoding fault that the language ward happened to catch, and it was blocking
every branch in the house from pushing, because the ward reads a file that no branch had touched.

## Why it happened, as far as the record can prove

The file is **generated** by `bin/gates/capabilities.sh` from `bin/README.md` and the surfaces themselves, and
`bin/README.md` is clean — its em dashes are correct UTF-8. So the corruption happened in a generation run whose
locale or reader lost the encoding, and it was committed because nothing compares the generated file to a
regeneration in the language ward's terms. A generated file that is only ever *read* is a file whose encoding is
never proved.

## The fix

Regenerate it — the generator, run under this shell's UTF-8 locale, writes correct bytes:

```
bash bin/gates/capabilities.sh     →  wrote .agents/assets/agents/capabilities.md — 700 door rows
grep -c $'\xe2\x80\x94' .agents/assets/agents/capabilities.md   →  0   (no ASCII-quoted sample here on purpose)
```

`git diff --stat` is 465 insertions and 466 deletions on one file: the mojibake, corrected, and the row counts it
carries. Nothing else changed.

## What is still unproven, and said rather than hidden

The register being *generated* means this can happen again the moment another hand regenerates it under a
non-UTF-8 locale. The durable fix is a line in the generator that pins the encoding (`LC_ALL=C.UTF-8`, or Python
with `encoding="utf-8"`) — that belongs to whoever owns `capabilities.sh`, and is named here rather than half-done
inside a Gimlé branch.

## Measured

```
before: language-guard FAIL — a Latin-1 letter x460 in .agents/assets/agents/capabilities.md
after:  language-guard PASS — 0 findings, and the push proceeds
```

## Files

- `.agents/assets/agents/capabilities.md` — regenerated.

## CHANGE LOG

- **2026-11-07** — the mojibake measured (460 × a three-character double-encode), traced to a generation run rather than to any hand, the
  register regenerated clean, and the language ward turned green. The generator's encoding is named as the durable
  fix and left to its owner.
