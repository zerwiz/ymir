#!/usr/bin/env python3
"""speech-text.py — what Kokoro is allowed to be given.

    printf '%s' "I don't have that" | python3 speech-text.py

MEASURED 2026-10-22: the Allfather heard **"do n,,,, t"** from the voice. Kokoro's phonemiser splits a
contraction's `n't` and inserts pauses, so the mouth stumbles on the commonest English negative.
The written answer is never touched — only what is SPOKEN is normalised:

  * curly quotes, dashes and ellipses folded to plain ASCII;
  * contractions expanded to their full words (don't → do not, it's → it is, …);
  * a DASH becomes a full stop, because Kokoro rushes a comma and pauses at a period;
  * a long clause is cut at its commas into short sentences — measured 2026-10-22: the Allfather
    heard "…when he is available, normally within a short time" run together, the adverb clipped
    onto the end of the previous word. A comma is not a breath; a full stop is.

This is a rendering rule, not a policy: it runs after the gate, on the string handed to the synthesiser.
"""
from __future__ import annotations

import re
import sys

PAIRS = [
    ("cannot", r"\bcan't\b"), ("will not", r"\bwon't\b"), ("do not", r"\bdon't\b"),
    ("does not", r"\bdoesn't\b"), ("did not", r"\bdidn't\b"), ("is not", r"\bisn't\b"),
    ("are not", r"\baren't\b"), ("was not", r"\bwasn't\b"), ("were not", r"\bweren't\b"),
    ("have not", r"\bhaven't\b"), ("has not", r"\bhasn't\b"), ("had not", r"\bhadn't\b"),
    ("would not", r"\bwouldn't\b"), ("could not", r"\bcouldn't\b"), ("should not", r"\bshouldn't\b"),
    ("must not", r"\bmustn't\b"), ("I am", r"\bI'm\b"), ("I will", r"\bI'll\b"),
    ("I have", r"\bI've\b"), ("I would", r"\bI'd\b"), ("it is", r"\bit's\b"),
    ("that is", r"\bthat's\b"), ("there is", r"\bthere's\b"), ("here is", r"\bhere's\b"),
    ("he is", r"\bhe's\b"), ("she is", r"\bshe's\b"), ("we are", r"\bwe're\b"),
    ("they are", r"\bthey're\b"), ("you are", r"\byou're\b"), ("we will", r"\bwe'll\b"),
    ("they will", r"\bthey'll\b"), ("you will", r"\byou'll\b"), ("let us", r"\blet's\b"),
    ("who is", r"\bwho's\b"), ("what is", r"\bwhat's\b"),
]


def spoken(text: str) -> str:
    t = (text or "")
    t = (t.replace("\u2019", "'").replace("\u2018", "'")
          .replace("\u201c", '"').replace("\u201d", '"')
          .replace("\u2013", ". ").replace("\u2014", ". ")
          .replace("\u2026", "."))
    for full, pattern in PAIRS:
        t = re.sub(pattern, full, t, flags=re.I)
    t = re.sub(r"\s+,", ",", t)
    t = re.sub(r"[,]{2,}", ",", t)
    t = re.sub(r"\s+", " ", t).strip()
    # a clause longer than a breath is cut at its commas: Kokoro does not pause at a comma, so a
    # long comma-spliced sentence arrives as one rushed breath with the adverb jammed on.
    out: list[str] = []
    for sentence in re.split(r"(?<=[.!?])\s+", t):
        sentence = sentence.strip()
        if not sentence:
            continue
        if len(sentence) <= 90:
            out.append(sentence)
            continue
        buf = ""
        for part in sentence.split(", "):
            if buf and len(buf) + len(part) > 80:
                out.append(buf.strip().rstrip(",") + ".")
                buf = part
            else:
                buf = f"{buf}, {part}" if buf else part
        if buf.strip():
            tail = buf.strip().rstrip(",")
            out.append(tail if tail.endswith((".", "!", "?")) else tail + ".")
    return " ".join(out)


if __name__ == "__main__":
    sys.stdout.write(spoken(sys.stdin.read()))
