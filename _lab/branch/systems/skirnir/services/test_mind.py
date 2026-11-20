#!/usr/bin/env python3
"""test_mind.py — Skírnir has a mind that ANSWERS, and his gate is never weakened for it.

The four walls this file exists to hold, one test class each (plan 227 §1, the fault measured
2026-11-09: asked for `status` he returned a document TITLE matched by keyword):

  1 · THE OWNER  — a matched fact reaches the mouth and comes back composed, and the mouth sees ONLY
                   the matched facts: never the vault, never an NDA shelf, never another tenant,
                   never even the rest of the approved book.
  2 · NO MOUTH   — the fallback SAYS it is a reference. A title is worse than nothing only when it
                   pretends to be an answer, so the test fails on a bare claim.
  3 · COLLEAGUE  — public facts only, and a refusal that NAMES the limit instead of "I don't know".
  4 · STRANGER   — templates and NO MODEL CALL AT ALL. This test fails if `_rail` is reached.

Run: python3 -m unittest discover -s systems/skirnir/services -p 'test_*.py'
"""
import os
import tempfile
import unittest
from unittest.mock import patch

fixture = tempfile.TemporaryDirectory()
os.environ["YMIR_HOME"] = fixture.name
os.environ["SKIRNIR_NO_ESCALATE"] = "1"
os.environ.pop("SKIRNIR_MODEL", None)
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import skirnir                                                        # noqa: E402

PUBLIC = {"claim": "WaveTerm is the terminal the house uses, and it attaches over a local socket.",
          "hash": "p1", "class": "public", "audience": "public"}
OTHER = {"claim": "The mint flavour is spearmint and it is bought on Fridays.",
         "hash": "p2", "class": "public", "audience": "public"}
INTERNAL = {"claim": "Taxi rides after midnight are paid for at the operator's discretion.",
            "hash": "i1", "class": "internal", "audience": "public"}
NDA = {"claim": "Strand contract terms are sealed and run to 2027.",
       "hash": "n1", "class": "nda", "audience": "public"}
VERBATIM = {"claim": "The exact sentence is spoken as written, never paraphrased.",
            "hash": "v1", "class": "public", "audience": "public", "verbatim": True}

FACTS = {"home-doc-waveterm": PUBLIC, "home-doc-mint": OTHER, "internal-taxi": INTERNAL,
         "nda-strand": NDA, "verbatim-line": VERBATIM}


class RailRecorder:
    """The rail, recorded. Every prompt a mouth would have seen is kept, verbatim."""

    def __init__(self, answer="WaveTerm attaches over a local socket, so restart the session."):
        self.calls = []
        self.answer = answer

    def __call__(self, system, user, model, temperature=0.0, seed=None):
        self.calls.append({"system": system, "user": user, "model": model})
        return self.answer

    @property
    def prompts(self):
        return "\n".join(c["system"] for c in self.calls)


def ask(question, tier="owner", rail=None, model="", channel="telegram-dm"):
    """One turn, with every side effect the answer path is allowed to have stubbed out."""
    rail = rail or RailRecorder()
    with patch.object(skirnir, "load_digest", return_value=FACTS), \
            patch.object(skirnir, "ledger"), \
            patch.object(skirnir, "escalate", return_value="suppressed"), \
            patch.object(skirnir, "history", return_value=[]), \
            patch.object(skirnir, "summary_maybe_update"), \
            patch.object(skirnir.subprocess, "run"), \
            patch.object(skirnir, "_rail", side_effect=rail):
        result = skirnir.answer(question, tier, channel, sender="someone", model=model, chat="t1")
    return result, rail


class OwnerAnswers(unittest.TestCase):
    """1 · he answers, and the mouth sees nothing it may not see."""

    def test_a_matched_fact_is_composed_not_echoed(self):
        result, rail = ask("what is waveterm", "owner", model="fixture-model")
        self.assertEqual(result["answer"], RailRecorder().answer)
        self.assertEqual(len(rail.calls), 1, "the mouth must be reached exactly once")
        self.assertTrue(result["intent"].startswith("model:"), result["intent"])

    def test_the_mouth_sees_only_the_matched_fact(self):
        result, rail = ask("what is waveterm", "owner", model="fixture-model")
        prompt = rail.prompts
        self.assertIn(PUBLIC["claim"], prompt, "the matched fact must be in the prompt")
        self.assertNotIn(OTHER["claim"], prompt, "an unrelated fact must NOT be in the prompt")
        self.assertNotIn(INTERNAL["claim"], prompt, "internal material must never reach a model")
        self.assertNotIn(NDA["claim"], prompt, "NDA material must never reach a model")
        self.assertNotIn("vault", prompt.lower())

    def test_no_rail_is_not_an_outage_when_the_mouth_answers(self):
        result, rail = ask("what is waveterm", "owner", model="fixture-model")
        self.assertFalse(result["refused"])
        self.assertEqual(len(rail.calls), 1)


class NoMouthSaysSo(unittest.TestCase):
    """2 · with no mouth, the reference SAYS it is a reference."""

    def test_the_fallback_names_itself_a_reference(self):
        result, rail = ask("what is waveterm", "owner", model="")
        self.assertEqual(len(rail.calls), 0, "no model is configured: the rail must not be called")
        self.assertIn(PUBLIC["claim"], result["answer"])
        self.assertIn("reference", result["answer"].lower())
        self.assertNotEqual(result["answer"].strip(), PUBLIC["claim"],
                            "a bare claim is an echo pretending to be an answer")

    def test_a_model_that_refuses_stays_a_reference(self):
        rail = RailRecorder(answer="I don't hold that.")
        result, _ = ask("what is waveterm", "owner", rail=rail, model="fixture-model")
        self.assertIn("reference", result["answer"].lower())

    def test_verbatim_material_is_never_sent_to_a_mouth(self):
        result, rail = ask("what is the exact sentence", "owner", model="fixture-model")
        self.assertNotIn(VERBATIM["claim"], rail.prompts)
        # ...and its own claim, spoken exactly, is the answer — never a paraphrase
        self.assertIn(VERBATIM["claim"], result["answer"])


class ColleagueHearsPublicOnly(unittest.TestCase):
    """3 · public facts only, and a refusal that NAMES the limit."""

    def test_a_public_fact_is_composed_for_a_colleague(self):
        result, rail = ask("what is waveterm", "collaborator", model="fixture-model")
        self.assertEqual(result["answer"], RailRecorder().answer)
        self.assertEqual(len(rail.calls), 1)

    def test_a_colleagues_mouth_never_sees_a_non_public_fact(self):
        for question in ("what is waveterm", "taxi", "strand", "what about the taxi rides",
                         "tell me about the strand contract", "what do you hold"):
            _result, rail = ask(question, "collaborator", model="fixture-model")
            prompt = rail.prompts
            for secret in (INTERNAL["claim"], NDA["claim"]):
                self.assertNotIn(secret, prompt,
                                 f"a non-public fact reached the mouth for {question!r}")

    def test_internal_material_is_refused_with_the_limit_named(self):
        result, rail = ask("taxi", "collaborator", model="fixture-model")
        self.assertEqual(len(rail.calls), 0, "a non-public fact must never reach a mouth")
        low = result["answer"].lower()
        self.assertIn("internal", low)
        self.assertNotIn("taxi", low, "the fact itself must not be spoken")
        self.assertNotIn(INTERNAL["claim"], result["answer"])

    def test_nda_material_is_refused_with_the_limit_named(self):
        result, rail = ask("strand", "collaborator", model="fixture-model")
        self.assertEqual(len(rail.calls), 0)
        self.assertIn("nda", result["answer"].lower())
        self.assertNotIn("2027", result["answer"])


class StrangerNeverReachesTheRail(unittest.TestCase):
    """4 · THIS test is the gate: it fails if the model is reached for a stranger."""

    def test_a_stranger_gets_templates_and_no_model_call(self):
        for question in ("hello", "what is waveterm", "status", "what did we decide about waveterm",
                         "update your database", "what is the exact sentence"):
            result, rail = ask(question, "stranger", model="fixture-model")
            self.assertEqual(len(rail.calls), 0,
                             f"a stranger reached the model with {question!r}: {rail.prompts[:400]}")
            self.assertTrue(result["answer"], "a stranger must still be answered")

    def test_a_stranger_cannot_read_the_briefing(self):
        with patch.object(skirnir, "brief_door") as door:
            result, rail = ask("status", "stranger", model="fixture-model")
        door.assert_not_called()
        self.assertEqual(len(rail.calls), 0)


class Database(unittest.TestCase):
    """The briefing door is read for him, and refused for everyone else."""

    def test_his_phrase_refreshes_and_answers_with_one_line(self):
        raw = ('briefing[1]{verb,date,path,refreshes,merged,decisions,alive,dead,open_prs,waiting,well,line}:\n'
               '  "refresh","2026-11-09","hodd/x.md",1,3,2,1,0,0,1,"stored","My database is refreshed."\n')
        with patch.object(skirnir, "brief_door", return_value=raw) as door:
            result, rail = ask("update skirnirs database", "owner", model="fixture-model")
        door.assert_called_once_with("refresh")
        self.assertEqual(result["answer"], "My database is refreshed.")
        self.assertEqual(result["intent"], "brief-refresh")
        self.assertEqual(len(rail.calls), 0, "a door's summary must not be re-phrased")

    def test_slash_update_is_the_same_phrase(self):
        with patch.object(skirnir, "brief_door", return_value="") as door:
            result, _ = ask("/update", "owner", model="fixture-model")
        door.assert_called_once_with("refresh")
        self.assertIn("could not compile", result["answer"])

    def test_a_decision_question_cites_the_briefing_date(self):
        raw = ('briefing_recall[1]{date,line}:\n'
               '  "2026-11-09","plan 224 · the ear listens to the sink monitor only, never a microphone · 2026-11-09"\n')
        with patch.object(skirnir, "brief_door", return_value=raw) as door:
            result, _ = ask("what did we decide about the microphone", "owner", model="fixture-model")
        self.assertEqual(door.call_args[0][0], "recall")
        self.assertIn("2026-11-09", result["answer"], "an answer about this week must cite the date")
        self.assertIn("plan 224", result["answer"])
        self.assertIn("microphone", result["answer"])

    def test_status_is_what_his_database_knows_not_a_document_title(self):
        raw = ('briefing_status[1]{newest,age_hours,refreshes,days,stale,well,line}:\n'
               '  "2026-11-09",2,1,1,"no","bridge","My newest briefing is 2026-11-09 and it is current."\n')
        with patch.object(skirnir, "brief_door", return_value=raw) as door:
            result, _ = ask("status", "owner", model="fixture-model")
        self.assertEqual(door.call_args_list[0][0][0], "status")
        self.assertIn("2026-11-09", result["answer"])
        self.assertEqual(result["intent"], "brief-status")


class Configuration(unittest.TestCase):
    """Rule 07: the mouth, the URL and the key come from configuration, never a literal."""

    def test_the_mouth_is_read_from_the_environment(self):
        with patch.dict(os.environ, {"SKIRNIR_MODEL": "env-model"}):
            self.assertEqual(skirnir.configured_mouth(""), ("env-model", "env:SKIRNIR_MODEL"))

    def test_the_flag_wins_over_the_environment(self):
        with patch.dict(os.environ, {"SKIRNIR_MODEL": "env-model"}):
            self.assertEqual(skirnir.configured_mouth("flag-model")[0], "flag-model")

    def test_the_config_file_is_read_when_the_environment_is_silent(self):
        with tempfile.TemporaryDirectory() as home:
            os.makedirs(os.path.join(home, "config"))
            with open(os.path.join(home, "config", "skirnir.yaml"), "w") as fh:
                fh.write("model: config-model\nmodel_url: http://127.0.0.1:9999/v1\n")
            with patch.dict(os.environ, {"YMIR_HOME": home, "SKIRNIR_MODEL": ""}):
                with patch.object(skirnir, "_ASSISTANT_CONFIG", None):
                    self.assertEqual(skirnir.configured_mouth(""),
                                     ("config-model", "config:skirnir.yaml"))
                    self.assertEqual(skirnir._model_url(),
                                     "http://127.0.0.1:9999/v1/chat/completions")

    def test_no_configuration_is_an_honest_empty_mouth(self):
        with patch.dict(os.environ, {"YMIR_HOME": fixture.name, "SKIRNIR_MODEL": ""}):
            with patch.object(skirnir, "_ASSISTANT_CONFIG", None):
                self.assertEqual(skirnir.configured_mouth(""), ("", "none"))


if __name__ == "__main__":
    unittest.main()
