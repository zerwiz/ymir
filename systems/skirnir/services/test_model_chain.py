#!/usr/bin/env python3
"""test_model_chain.py — Skírnir's mouth is a CHAIN: the primary, then the fallback.

His word, 2026-11-09: "give him the mtp model here and the q2 qwen3.6 on nidavellir". The chain was
first written by hand on the pinned runtime and carried to main on 2026-11-12. These tests hold
three promises, and none of them calls a real model — `urlopen` is replaced:

  1. the primary answers, and the fallback is never asked;
  2. the primary is silent, and the fallback answers — behind its own door when one is named;
  3. no model is configured, and nothing is sent: the honest None, not invented words.

Run: python3 -m unittest discover -s systems/skirnir/services -p 'test_*.py'
"""
import io
import json
import os
import sys
import tempfile
import unittest
from unittest.mock import patch

fixture = tempfile.TemporaryDirectory()
os.environ["YMIR_HOME"] = fixture.name
os.environ["SKIRNIR_NO_ESCALATE"] = "1"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import skirnir                                                        # noqa: E402

CLEAN = {k: "" for k in ("SKIRNIR_MODEL", "SKIRNIR_MODEL_URL", "OPENAI_BASE_URL",
                         "SKIRNIR_MODEL_FALLBACK", "SKIRNIR_MODEL_FALLBACK_URL")}


class FakeRail:
    """Answers for the aliases it knows; raises for the rest, as a dead rail does."""

    def __init__(self, answers):
        self.answers = answers
        self.calls = []

    def __call__(self, req, timeout=None):
        body = json.loads(req.data.decode())
        self.calls.append((body["model"], req.full_url))
        if body["model"] not in self.answers:
            raise OSError("connection refused")
        reply = {"choices": [{"message": {"content": self.answers[body["model"]]}}]}
        return io.BytesIO(json.dumps(reply).encode())


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def rail(answers):
    fake = FakeRail(answers)

    def opener(req, timeout=None):
        return FakeResponse(fake(req, timeout).getvalue())
    opener.calls = fake.calls
    return opener


class ModelChain(unittest.TestCase):
    def setUp(self):
        self.key = patch.object(skirnir, "_rail_key", return_value="test-key")
        self.cfg = patch.object(skirnir, "assistant_config", return_value={})
        self.key.start()
        self.cfg.start()

    def tearDown(self):
        patch.stopall()

    def test_primary_answers_and_the_fallback_is_not_asked(self):
        env = dict(CLEAN, SKIRNIR_MODEL_URL="https://rail.test/v1", SKIRNIR_MODEL_FALLBACK="small")
        opener = rail({"big": "from the primary"})
        with patch.dict(os.environ, env), patch("urllib.request.urlopen", opener):
            said = skirnir._rail("system", "hello", "big")
        self.assertEqual(said, "from the primary")
        self.assertEqual(opener.calls, [("big", "https://rail.test/v1/chat/completions")])

    def test_primary_fails_and_the_fallback_answers_behind_its_own_door(self):
        env = dict(CLEAN, SKIRNIR_MODEL_URL="https://rail.test/v1", SKIRNIR_MODEL_FALLBACK="small",
                   SKIRNIR_MODEL_FALLBACK_URL="https://other.test/v1/")
        opener = rail({"small": "from the fallback"})
        with patch.dict(os.environ, env), patch("urllib.request.urlopen", opener):
            said = skirnir._rail("system", "hello", "big")
        self.assertEqual(said, "from the fallback")
        self.assertEqual(opener.calls, [("big", "https://rail.test/v1/chat/completions"),
                                        ("small", "https://other.test/v1/chat/completions")])

    def test_fallback_without_its_own_door_uses_the_same_rail(self):
        env = dict(CLEAN, SKIRNIR_MODEL_URL="https://rail.test/v1", SKIRNIR_MODEL_FALLBACK="small")
        with patch.dict(os.environ, env):
            chain = skirnir._model_chain("big")
        self.assertEqual(chain, [("big", "https://rail.test/v1/chat/completions"),
                          ("small", "https://rail.test/v1/chat/completions")])

    def test_fallback_is_read_from_his_config_too(self):
        self.cfg.stop()
        cfg = {"model_fallback": "small", "model_fallback_url": "https://other.test/v1"}
        with patch.object(skirnir, "assistant_config", return_value=cfg), \
                patch.dict(os.environ, dict(CLEAN, SKIRNIR_MODEL_URL="https://rail.test/v1")):
            chain = skirnir._model_chain("big")
        self.assertEqual(chain[1], ("small", "https://other.test/v1/chat/completions"))
        self.cfg.start()

    def test_every_model_silent_is_none(self):
        env = dict(CLEAN, SKIRNIR_MODEL_FALLBACK="small")
        opener = rail({})
        with patch.dict(os.environ, env), patch("urllib.request.urlopen", opener):
            self.assertIsNone(skirnir._rail("system", "hello", "big"))
        self.assertEqual([alias for alias, _ in opener.calls], ["big", "small"])

    def test_no_model_configured_is_the_honest_none_and_nothing_is_sent(self):
        opener = rail({"": "an invented answer"})
        with patch.dict(os.environ, CLEAN), patch("urllib.request.urlopen", opener):
            self.assertEqual(skirnir._model_chain(""), [])
            self.assertIsNone(skirnir._rail("system", "hello", ""))
            self.assertEqual(skirnir.configured_mouth(""), ("", "none"))
        self.assertEqual(opener.calls, [])


if __name__ == "__main__":
    unittest.main()
