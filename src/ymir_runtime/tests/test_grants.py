"""grants/ — the realm law: a cross-operator share is signed by each Heimdall.

Plan 58, *Several Ymirs, one company*. The data lives in the hoard
(`hodd/identity/grants.yaml`); this suite judges the law the validator enforces.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import yaml

from ymir_runtime.config import ConfigError, ConfigValidationError, available, spec_for
from ymir_runtime.grants import (
    default_registry,
    is_cross_operator,
    load_registry,
    required_signers,
)

REPO = Path(__file__).resolve().parents[3]
EXAMPLES = REPO / "config" / "grants.yaml.example"
HAS_VALIDATOR = available()


def _write(doc: dict) -> Path:
    directory = Path(tempfile.mkdtemp(prefix="ymir-grants-test-"))
    path = directory / "grants.yaml"
    path.write_text(yaml.safe_dump(doc, sort_keys=False), encoding="utf-8")
    return path


def _party(ymir: str, operator: str, heimdall: str, *, signed: bool) -> dict:
    return {
        "ymir": ymir,
        "operator": operator,
        "heimdall": heimdall,
        "card": {"protocol": "a2a/1.0", "endpoint": f"http://{ymir}:8301/", "signed": signed},
    }


def _signature(signer: str) -> dict:
    return {"signer": signer, "alg": "ed25519", "key_id": f"{signer}-key", "sig": "c2ln"}


def _grant(**overrides) -> dict:
    grant = {
        "grant_id": "11111111-1111-4111-8111-111111111111",
        "namespace": "example-project",
        "role": "member",
        "state": "active",
        "grantor": _party("ymir-a", "operator-a", "heimdall-a", signed=True),
        "grantee": _party("ymir-b", "operator-b", "heimdall-b", signed=True),
        "signatures": [_signature("heimdall-a"), _signature("heimdall-b")],
    }
    grant.update(overrides)
    return grant


class PureLawTest(unittest.TestCase):
    """The helpers need no validator — the boundary and the required signers."""

    def test_cross_operator_is_recognised(self) -> None:
        self.assertTrue(is_cross_operator(_grant()))

    def test_one_operator_is_not_cross(self) -> None:
        grant = _grant(grantee=_party("ymir-a2", "operator-a", "heimdall-a2", signed=False), signatures=[])
        self.assertFalse(is_cross_operator(grant))

    def test_cross_operator_requires_both_heimdalls_in_order(self) -> None:
        self.assertEqual(required_signers(_grant()), ("heimdall-a", "heimdall-b"))

    def test_a_signed_card_is_required_even_within_one_operator(self) -> None:
        grant = _grant(
            grantor=_party("ymir-a", "operator-a", "heimdall-a", signed=False),
            grantee=_party("ymir-a2", "operator-a", "heimdall-a2", signed=True),
            signatures=[],
        )
        self.assertEqual(required_signers(grant), ("heimdall-a2",))

    def test_the_default_registry_is_the_hoard(self) -> None:
        class Roots:
            hoard = Path("/tmp/hoard")

        self.assertEqual(default_registry(Roots()), Path("/tmp/hoard/identity/grants.yaml"))


class KindsTest(unittest.TestCase):
    def test_the_registry_has_a_registered_kind(self) -> None:
        self.assertEqual(spec_for("grants.yaml").kind, "grants")


@unittest.skipUnless(HAS_VALIDATOR, "jsonschema not installed — bin/ymir-engine-ensure.sh ensure")
class RegistryTest(unittest.TestCase):
    """The whole road: YAML -> schema -> the realm law."""

    def test_the_shipped_example_loads_clean(self) -> None:
        data = load_registry(EXAMPLES, root=REPO)
        self.assertEqual(len(data["grants"]), 1)

    def test_a_signed_cross_operator_grant_loads(self) -> None:
        data = load_registry(_write({"version": 1, "grants": [_grant()]}), root=REPO)
        self.assertEqual(data["grants"][0]["namespace"], "example-project")

    def test_a_cross_operator_grant_missing_a_signature_is_refused(self) -> None:
        grant = _grant(signatures=[_signature("heimdall-a")])
        with self.assertRaises(ConfigValidationError) as caught:
            load_registry(_write({"version": 1, "grants": [grant]}), root=REPO)
        self.assertIn("no signature from Heimdall 'heimdall-b'", str(caught.exception))
        self.assertIn("realm law requires the signature", str(caught.exception))

    def test_a_same_operator_grant_needs_no_signature(self) -> None:
        grant = _grant(
            grantor=_party("ymir-a", "operator-a", "heimdall-a", signed=False),
            grantee=_party("ymir-a2", "operator-a", "heimdall-a2", signed=False),
            signatures=[],
        )
        data = load_registry(_write({"version": 1, "grants": [grant]}), root=REPO)
        self.assertEqual(len(data["grants"]), 1)

    def test_a_card_claiming_signed_without_one_is_refused(self) -> None:
        grant = _grant(
            grantor=_party("ymir-a", "operator-a", "heimdall-a", signed=False),
            grantee=_party("ymir-a2", "operator-a", "heimdall-a2", signed=True),
            signatures=[],
        )
        with self.assertRaises(ConfigValidationError) as caught:
            load_registry(_write({"version": 1, "grants": [grant]}), root=REPO)
        self.assertIn("'heimdall-a2'", str(caught.exception))

    def test_a_foreign_signer_is_refused(self) -> None:
        grant = _grant(signatures=[_signature("heimdall-a"), _signature("heimdall-b"), _signature("intruder")])
        with self.assertRaises(ConfigValidationError) as caught:
            load_registry(_write({"version": 1, "grants": [grant]}), root=REPO)
        self.assertIn("foreign to grant", str(caught.exception))

    def test_a_duplicate_grant_id_is_refused(self) -> None:
        with self.assertRaises(ConfigValidationError) as caught:
            load_registry(_write({"version": 1, "grants": [_grant(), _grant()]}), root=REPO)
        self.assertIn("declared twice", str(caught.exception))

    def test_a_grant_to_oneself_is_refused(self) -> None:
        grant = _grant(grantee=_party("ymir-a", "operator-a", "heimdall-a", signed=True))
        with self.assertRaises(ConfigValidationError) as caught:
            load_registry(_write({"version": 1, "grants": [grant]}), root=REPO)
        self.assertIn("one Heimdall on both sides", str(caught.exception))

    def test_a_card_without_the_signed_flag_breaks_the_schema(self) -> None:
        grant = _grant()
        del grant["grantor"]["card"]["signed"]
        with self.assertRaises(ConfigValidationError) as caught:
            load_registry(_write({"version": 1, "grants": [grant]}), root=REPO)
        self.assertIn("signed", str(caught.exception))

    def test_a_bad_namespace_breaks_the_schema(self) -> None:
        with self.assertRaises(ConfigValidationError):
            load_registry(_write({"version": 1, "grants": [_grant(namespace="Bad Namespace")]}), root=REPO)

    def test_a_registry_with_no_grants_key_is_refused(self) -> None:
        with self.assertRaises(ConfigError):
            load_registry(_write({"version": 1}), root=REPO)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
