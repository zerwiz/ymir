"""The Hermes seat (plan 317 slices 1–3, 6): owned entries corrected, the operator's left alone,
values compared — proved against a sandbox HERMES_HOME and a fake `hermes` that writes like the CLI."""

from __future__ import annotations

import json
import os
import stat
import sys
from pathlib import Path

import pytest
import yaml

from ymir_runtime.hermes import seat as S

FAKE_HERMES = r'''#!{py}
import json, os, sys, yaml
a = sys.argv[1:]
if a[:1] == ["--version"]:
    print("Hermes Agent v0.22.6 (fake)"); sys.exit(0)
path = os.environ["HERMES_CONFIG"]
d = yaml.safe_load(open(path)) or {{}}
if a[:2] in (["config", "set"], ["config", "unset"]):
    keys = a[2].split(".")
    cur = d
    for k in keys[:-1]:
        cur = cur.setdefault(k, {{}})
    if a[1] == "set":
        cur[keys[-1]] = json.loads(a[3])
    else:
        cur.pop(keys[-1], None)
    yaml.safe_dump(d, open(path, "w"), sort_keys=False)
    sys.exit(0)
sys.exit(2)
'''

CHECKOUT_DOOR = {"command": "python3", "args": ["/src/ymir/bin/mcp/ymir-mcp.py"]}


@pytest.fixture()
def sandbox(tmp_path: Path):
    pin = tmp_path / "ymir-runtime"
    (pin / "bin" / "mcp").mkdir(parents=True)
    (pin / "bin" / "mcp" / "ymir-mcp.py").write_text("# door\n")
    (pin / ".agents" / "skills").mkdir(parents=True)
    hh = tmp_path / ".hermes"
    (hh / "scripts").mkdir(parents=True)
    fake = tmp_path / "bin" / "hermes"
    fake.parent.mkdir()
    fake.write_text(FAKE_HERMES.format(py=sys.executable))
    fake.chmod(fake.stat().st_mode | stat.S_IEXEC)
    adapter = tmp_path / "mcp-adapter.json"
    env = {
        "HOME": str(tmp_path), "PATH": f"{fake.parent}:{os.environ.get('PATH', '')}",
        "HERMES_HOME": str(hh), "HERMES_CONFIG": str(hh / "config.yaml"),
        "YMIR_MCP_ADAPTER": str(adapter), "YMIR_RUNTIME_DIR": str(pin), "HERMES_BIN": str(fake),
        "YMIR_HOME": str(tmp_path / "home"),
    }
    return env, pin, hh, adapter


def write(env, hh: Path, adapter: Path, config: dict, packets: dict) -> None:
    (hh / "config.yaml").write_text(yaml.safe_dump(config, sort_keys=False))
    adapter.write_text(json.dumps({"mcpServers": packets}))


def cfg(hh: Path) -> dict:
    return yaml.safe_load((hh / "config.yaml").read_text())


def lines(env, **kw) -> tuple[int, list[str]]:
    out: list[str] = []
    rc = S.seat(env, out=out.append, **kw)
    return rc, out


PACKETS = {
    "ymir": {"command": "python3", "args": ["PIN/bin/mcp/ymir-mcp.py"]},
    "well": {"url": "https://example.org/mcp/well"},
    "hnoss": {"command": "PIN/bin/pi/hnoss-mcp-launch.sh", "args": []},
    "firecrawl": {"command": "npx", "args": ["-y", "firecrawl-mcp"]},
}


def packets_for(pin: Path) -> dict:
    return json.loads(json.dumps(PACKETS).replace("PIN", str(pin)))


def test_the_ymir_door_is_corrected_onto_the_pin_and_hnoss_is_left_alone(sandbox):
    env, pin, hh, adapter = sandbox
    hand_hnoss = {"command": "/usr/local/bin/hnoss-mcp-launch.sh", "args": [], "enabled": True}
    write(env, hh, adapter, {"mcp_servers": {"ymir": {**CHECKOUT_DOOR, "enabled": True}, "hnoss": hand_hnoss}},
          packets_for(pin))
    rc, out = lines(env)
    assert rc == 0
    after = cfg(hh)["mcp_servers"]
    assert after["ymir"]["args"] == [str(pin / "bin" / "mcp" / "ymir-mcp.py")]
    assert after["hnoss"] == hand_hnoss
    assert any('"hnoss","operator-owned"' in ln for ln in out)
    ledger = json.loads((hh / ".ymir-owned.json").read_text())
    assert "ymir" in ledger["mcp_servers"] and "hnoss" not in ledger["mcp_servers"]
    assert list(hh.glob("config.yaml.bak-*")), "a dated backup is taken before the write"


def test_a_second_run_changes_nothing(sandbox):
    env, pin, hh, adapter = sandbox
    write(env, hh, adapter, {"mcp_servers": {}}, packets_for(pin))
    assert lines(env)[0] == 0
    rc, out = lines(env)
    assert rc == 0 and out[-1] == "hermes-seat: nothing to change"


def test_check_compares_values_and_names_the_drifted_entry(sandbox):
    env, pin, hh, adapter = sandbox
    write(env, hh, adapter, {"mcp_servers": {}}, packets_for(pin))
    assert lines(env)[0] == 0
    assert lines(env, check=True)[0] == 0
    doc = cfg(hh)
    doc["mcp_servers"]["ymir"]["args"] = ["/src/ymir/bin/mcp/ymir-mcp.py"]   # a hand swap
    (hh / "config.yaml").write_text(yaml.safe_dump(doc, sort_keys=False))
    rc, out = lines(env, check=True)
    assert rc == 1
    assert any('"ymir","drift"' in ln for ln in out)
    assert "ymir" in out[-2]


def test_dry_run_writes_nothing(sandbox):
    env, pin, hh, adapter = sandbox
    write(env, hh, adapter, {"mcp_servers": {"ymir": dict(CHECKOUT_DOOR)}}, packets_for(pin))
    before = (hh / "config.yaml").read_text()
    rc, out = lines(env, dry_run=True)
    assert rc == 0 and (hh / "config.yaml").read_text() == before
    assert not (hh / ".ymir-owned.json").exists()
    assert any(ln.startswith("would run: hermes config set mcp_servers.ymir.args") for ln in out)


def test_only_ymirs_own_doors_are_adopted():
    packets = {"firecrawl": {"command": "npx", "args": ["-y", "firecrawl-mcp"]},
               "well": {"url": "https://example.org/mcp/well"}}
    config = {"mcp_servers": {"firecrawl": {"command": "npx", "args": ["-y", "firecrawl-mcp"], "enabled": True},
                              "well": {"url": "https://example.org/mcp/well", "enabled": True}}}
    p = S.plan(config, packets, {}, Path(""), Path("/nonexistent"))
    states = {n: s for n, s, _ in p.rows}
    assert states["firecrawl"] == S.OPERATOR
    assert states["well"] == S.ADOPTED
    assert set(p.ledger["mcp_servers"]) == {"well"}


def test_a_correction_keeps_the_operators_extra_keys():
    packets = {"snotra": {"url": "https://new.example.org/mcp"}}
    config = {"mcp_servers": {"snotra": {"url": "https://old.example.org/mcp", "auth": "oauth", "enabled": False}}}
    ledger = {"mcp_servers": {"snotra": {"value": {"url": "https://old.example.org/mcp"}}}}
    p = S.plan(config, packets, ledger, Path(""), Path("/nonexistent"))
    assert p.config["mcp_servers"]["snotra"] == {"auth": "oauth", "enabled": False, "url": "https://new.example.org/mcp"}
    assert ("snotra", S.CORRECTED) in [(n, s) for n, s, _ in p.rows]


def test_an_owned_entry_gone_from_the_list_is_disabled_never_deleted():
    config = {"mcp_servers": {"old": {"url": "https://mcp.example.org", "enabled": True}}}
    ledger = {"mcp_servers": {"old": {"value": {"url": "https://mcp.example.org"}}}}
    p = S.plan(config, {}, ledger, Path(""), Path("/nonexistent"))
    assert p.config["mcp_servers"]["old"]["enabled"] is False
    assert p.ledger["mcp_servers"]["old"]["state"] == S.RETIRED


def test_skills_shelf_is_external_and_only_worktree_trust_is_pruned(tmp_path):
    pin = tmp_path / "ymir-runtime"
    config = {"skills": {"trusted_project_dirs": ["/src/ymir", "/src/ymir/.yggdrasil/x", str(pin)]}}
    p = S.plan(config, {}, {}, pin, tmp_path / "scripts")
    skills = p.config["skills"]
    assert skills["external_dirs"] == [str(pin / ".agents" / "skills")]
    assert skills["trusted_project_dirs"] == ["/src/ymir", str(pin)]


def test_a_packet_list_naming_a_tree_is_red(tmp_path):
    pin = tmp_path / "ymir-runtime"
    p = S.plan({}, {"ymir": dict(CHECKOUT_DOOR)}, {}, pin, tmp_path / "scripts")
    assert ("packet-list", S.RED) in [(n, s) for n, s, _ in p.rows]
    assert p.config["mcp_servers"]["ymir"]["args"] == [str(pin / "bin" / "mcp" / "ymir-mcp.py")]


def test_a_hand_edited_worker_script_is_left_alone(tmp_path):
    pin = tmp_path / "pin"
    scripts = tmp_path / "scripts"
    scripts.mkdir()
    (scripts / S.WORKERS_SCRIPT).write_text("print('mine')\n")
    led = {"scripts": {S.WORKERS_SCRIPT: "0000"}}
    p = S.plan({}, {}, led, pin, scripts)
    assert (f"script:{S.WORKERS_SCRIPT}", S.OPERATOR) in [(n, s) for n, s, _ in p.rows]
    assert not p.scripts


def test_config_ops_are_minimal_and_refuse_dotted_names():
    before = {"mcp_servers": {"ymir": {"command": "python3", "args": ["/a"], "enabled": True}}, "x": 1}
    after = {"mcp_servers": {"ymir": {"command": "python3", "args": ["/b"], "enabled": True},
                             "new": {"url": "u"}}, "x": 1}
    assert S.config_ops(before, after) == [("set", "mcp_servers.ymir.args", ["/b"]),
                                           ("set", "mcp_servers.new", {"url": "u"})]
    with pytest.raises(S.C.HermesError):
        S.config_ops({"a.b": 1}, {})
