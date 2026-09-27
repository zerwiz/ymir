"""The engine's unit suite entry for a bare `python3 -m unittest` from the repo.

The tests live BESIDE the modules (`src/ymir_runtime/tests/`, plan 58's rule).
This module is the discovery hinge: `python3 -m unittest` walks the repo root,
finds this package, and `load_tests` points the loader at the beside-modules
suite with `src/` as the top level. Both roads run the same tests:

    python3 -m unittest                                    # from the repo root
    PYTHONPATH=src python3 -m unittest discover -s src/ymir_runtime/tests -t src
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

SRC = Path(__file__).resolve().parents[1] / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))


def load_tests(loader: unittest.TestLoader, tests, pattern):  # noqa: ANN001 - the protocol
    return loader.discover(str(SRC / "ymir_runtime" / "tests"), top_level_dir=str(SRC))
