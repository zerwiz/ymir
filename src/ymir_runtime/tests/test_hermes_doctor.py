"""`ymir doctor hermes` (plan 317 slice 8): a stale descriptor is red; an operator's surface never is;
and the packet list renders the pin (slice 1)."""

from __future__ import annotations

import importlib.util
import stat
import sys
from pathlib import Path

from ymir_runtime.hermes import doctor as D
from ymir_runtime.hermes import mcp_probe as M

REPO = Path(__file__).resolve().parents[3]


def fake_hermes(tmp_path: Path, version: str) -> str:
    f = tmp_path / "hermes"
    f.write_text(f"#!/bin/sh\necho 'Hermes Agent v{version} (fake)'\n")
    f.chmod(f.stat().st_mode | stat.S_IEXEC)
    return str(f)


def test_descriptor_row_compares_measured_against(tmp_path):
    root = tmp_path / "tree"
    (root / ".agents" / "harnesses").mkdir(parents=True)
    (root / ".agents" / "harnesses" / "hermes.yaml").write_text("measured_against: 0.22.6\n")
    ok = D.descriptor_row({"HERMES_BIN": fake_hermes(tmp_path, "0.22.6")}, root)
    assert ok.answering == M.YES and not ok.red
    stale = D.descriptor_row({"HERMES_BIN": fake_hermes(tmp_path, "0.23.0")}, root)
    assert stale.red and "stale descriptor" in stale.detail


def test_the_shipped_descriptor_tells_the_truth():
    import yaml
    d = yaml.safe_load((REPO / ".agents" / "harnesses" / "hermes.yaml").read_text())
    assert d["measured_against"] == "0.22.6"
    assert d["capabilities"]["hooks"] == "shell" and d["capabilities"]["mcp"] == "native"


def test_operator_and_not_owed_rows_are_never_red():
    assert not D.Row("mcp:hnoss", configured=M.NO, counted=False).red
    assert D.Row("mcp:ymir", configured=M.YES, listening=M.YES, answering=M.NO).red
    assert not D.Row("x", configured=M.YES, listening=M.YES, authenticated=M.NA, answering=M.YES).red


def test_the_packet_list_renders_the_pin(tmp_path, monkeypatch):
    pin = tmp_path / "ymir-runtime"
    (pin / "bin" / "mcp").mkdir(parents=True)
    (pin / "bin" / "mcp" / "ymir-mcp.py").write_text("# door\n")
    monkeypatch.setenv("YMIR_RUNTIME_DIR", str(pin))
    spec = importlib.util.spec_from_file_location("mcp_config_seat", REPO / "bin" / "bridge" / "mcp-config-seat.py")
    mod = importlib.util.module_from_spec(spec)
    monkeypatch.setattr(sys, "argv", ["mcp-config-seat.py"])
    spec.loader.exec_module(mod)
    door = {"command": "python3", "args": ["/src/ymir/bin/mcp/ymir-mcp.py"]}
    assert mod.door_on_pin(door)["args"] == [str(pin / "bin" / "mcp" / "ymir-mcp.py")]
    other = {"command": "npx", "args": ["-y", "firecrawl-mcp"]}
    assert mod.door_on_pin(other) == other
    assert mod.stable_root() == str(pin)
