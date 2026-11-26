#!/usr/bin/env python3
"""test_pitch.py — the Ymir pitch explains, and an archived record never answers.

Both faults measured 2026-11-26: "what is ymir" returned a pile of document titles, and "what is gimle"
was answered from a record of something that had left the house.

Run: python3 -m unittest discover -s systems/skirnir/services -p 'test_*.py'
"""
import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import test_mind                                                      # noqa: E402  (sets the fixture home)
import skirnir                                                        # noqa: E402


def fact(claim, klass="public"):
    return {"claim": claim, "hash": str(abs(hash(claim))), "class": klass, "audience": "public"}


FACTS = {
    "learned-aaa": fact("Ymir is the house itself: one machine and many realms around one operator."),
    "feature-eindri-isolated-sub-agents": fact("Ymir has a feature: Eindri. Work forged in isolation."),
    "lore-yggdrasil": fact("Yggdrasil: worktree manager"),
    "home-doc-homes-md": fact("Eindri-homes — persistent worker homes and where they are kept.", "internal"),
    "home-doc-public-md": fact("Ymir — a document title that explains nothing at all to anyone."),
    "site-abc": fact("guidance and the first steps a new hand takes inside Ymir, shaped to meet"),
    "capabilities": fact("What the assistant can do for the house, in five numbered things here."),
}


def ask(question, facts, tier="owner", model=""):
    rail = test_mind.RailRecorder("Ymir is the house, and Eindri do the work.")
    with patch.object(skirnir, "load_digest", return_value=facts), \
            patch.object(skirnir, "ledger"), \
            patch.object(skirnir, "escalate", return_value="suppressed"), \
            patch.object(skirnir, "history", return_value=[]), \
            patch.object(skirnir, "summary_maybe_update"), \
            patch.object(skirnir, "_rail", side_effect=rail):
        return skirnir.answer(question, tier, "console", model=model, chat="t2"), rail


class Pitch(unittest.TestCase):
    def test_only_public_sentences_in_telling_order(self):
        result, _ = ask("what is ymir", FACTS)
        self.assertEqual(result["facts"], ["learned-aaa", "feature-eindri-isolated-sub-agents"])
        self.assertNotIn("worker homes", result["answer"])

    def test_the_mouth_is_given_the_facts(self):
        _, rail = ask("what is ymir", FACTS, model="fixture-model")
        self.assertIn("one machine and many realms", rail.prompts)
        self.assertNotIn("persistent worker homes", rail.prompts)

    def test_a_stranger_never_reaches_the_mouth(self):
        _, rail = ask("what is ymir", FACTS, tier="stranger", model="fixture-model")
        self.assertEqual(rail.calls, [])


class Archived(unittest.TestCase):
    def test_an_archived_record_never_answers(self):
        facts = {
            "home-doc-hodd-reference-ymir-moved-zeta-readme-md": fact("zeta — moved out.", "internal"),
            "home-doc-hodd-reference-retired-zeta-md": fact("zeta, retired.", "internal"),
            "home-doc-hodd-saves-assistant-zeta-md": fact("zeta in a backup.", "internal"),
        }
        result, _ = ask("what is zeta", facts)
        self.assertEqual(result["intent"], "unknown")

    def test_a_living_record_still_answers(self):
        facts = {"home-doc-hodd-docs-zeta-md": fact("zeta — the desk behind the door.", "internal")}
        result, _ = ask("what is zeta", facts)
        self.assertEqual(result["facts"], ["home-doc-hodd-docs-zeta-md"])


if __name__ == "__main__":
    unittest.main()
