#!/usr/bin/env python3
"""test_kit.py — the proofs for kit 2.0.0 (plan 267 K-1…K-13 and RULES/24). Fixtures only: throwaway git repos,
a bare remote per fixture, a fake container engine on PATH, a fake disk and a fake product host by environment.

  python3 bin/collab/tests/test_kit.py -v
"""
from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest
from pathlib import Path

COLLAB = Path(__file__).resolve().parents[1]
KIT = COLLAB / "kit"
sys.path.insert(0, str(KIT / "scripts"))
sys.path.insert(0, str(COLLAB))
from kitlib import miniyaml  # noqa: E402


def sh(cmd, cwd, env=None, check=False, input=None):
    e = dict(os.environ)
    e.update({"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.invalid", "GIT_COMMITTER_NAME": "t",
              "GIT_COMMITTER_EMAIL": "t@example.invalid", "KIT_FAKE_DISK": "500/1000", "KIT_PRODUCT_HOST": "0",
              "KIT_MACHINE_FILE": "/nonexistent"})
    e.update(env or {})
    r = subprocess.run(cmd, cwd=str(cwd), env=e, text=True, capture_output=True, shell=isinstance(cmd, str), input=input)
    if check and r.returncode != 0:
        raise AssertionError(f"{cmd} → {r.returncode}\n{r.stdout}\n{r.stderr}")
    return r


class Fixture:
    """A bare remote, a clone with one commit on main, and the kit applied with a profile."""

    def __init__(self, tmp: Path, profile="node", register="plain", languages="en:sv", setup=None, apply=True):
        self.tmp = tmp
        self.remote = tmp / "remote.git"
        self.repo = tmp / "repo"
        sh(["git", "init", "-q", "--bare", "-b", "main", str(self.remote)], tmp, check=True)
        sh(["git", "init", "-q", "-b", "main", str(self.repo)], tmp, check=True)
        if setup:
            setup(self.repo)
        if profile == "node" and not (self.repo / "package.json").exists():
            (self.repo / "package.json").write_text("{}\n")
        (self.repo / "README.md").write_text("# fixture\n")
        sh("git add -A && git commit -qm 'first commit of the fixture' --no-verify", self.repo, check=True)
        sh(["git", "remote", "add", "origin", str(self.remote)], self.repo, check=True)
        sh("git push -q --no-verify origin main && git remote set-head origin main", self.repo, check=True)
        if apply:
            self.apply(profile, register, languages)

    def apply(self, profile, register="plain", languages="en:sv", extra=()):
        r = sh([sys.executable, str(COLLAB / "standardise.py"), "--apply", str(self.repo), "--profile", profile,
                "--register", register, "--languages", languages, *extra], self.tmp)
        assert r.returncode == 0, r.stdout + r.stderr
        sh("git add -A && git commit -qm 'install the collaboration kit' --no-verify && git push -q --no-verify origin main",
           self.repo, check=True)
        return r.stdout

    def config(self, patch: str):
        p = self.repo / "project.yaml"
        p.write_text(p.read_text() + "\n" + textwrap.dedent(patch))

    def kit(self, *args, env=None, cwd=None):
        return sh([sys.executable, "scripts/kit.py", *args], cwd or self.repo, env=env)

    def new(self, wid, *extra, env=None):
        return self.kit("worktree", "new", wid, *extra, env=env)


def set_yaml(repo: Path, dotted: str, value: str):
    """Replace one scalar in project.yaml (the fixtures' own small editor)."""
    p = repo / "project.yaml"
    lines = p.read_text().splitlines()
    parts = dotted.split(".")
    depth, out, done = 0, [], False
    for line in lines:
        stripped = line.split("#", 1)[0].rstrip()
        key = parts[depth] if depth < len(parts) else None
        if not done and key and stripped.strip().startswith(key + ":") and (len(line) - len(line.lstrip())) == 2 * depth:
            if depth == len(parts) - 1:
                line = " " * (2 * depth) + f"{key}: {value}"
                done = True
            else:
                depth += 1
        out.append(line)
    assert done, f"{dotted} not found"
    p.write_text("\n".join(out) + "\n")


class Base(unittest.TestCase):
    def setUp(self):
        self.tmpd = tempfile.mkdtemp(prefix="kit-test-")
        self.tmp = Path(self.tmpd)

    def tearDown(self):
        shutil.rmtree(self.tmpd, ignore_errors=True)

    def fake_engine(self, images=None, containers=None, volumes=None) -> dict:
        """A fake podman on PATH that answers from fixtures and logs every call."""
        bindir = self.tmp / "bin"
        bindir.mkdir(exist_ok=True)
        data = self.tmp / "engine"
        data.mkdir(exist_ok=True)
        (data / "images.json").write_text(json.dumps(images or []))
        (data / "ps.json").write_text(json.dumps(containers or []))
        (data / "volumes.json").write_text(json.dumps(volumes or []))
        script = bindir / "podman"
        script.write_text(textwrap.dedent(f"""\
            #!/usr/bin/env bash
            echo "$*" >> {data}/calls.log
            case "$1" in
              images) cat {data}/images.json ;;
              ps) cat {data}/ps.json ;;
              volume) [ "$2" = ls ] && cat {data}/volumes.json ;;
              build) sleep "${{FAKE_BUILD_SECONDS:-0}}" ;;
            esac
            exit 0
            """))
        script.chmod(0o755)
        return {"PATH": f"{bindir}:{os.environ['PATH']}", "_log": str(data / "calls.log")}


# ---- K-1 · the plain register, and the house register as a rendering of the same facts -------------------------
class K01PlainRegister(Base):
    def test_installed_repo_carries_no_house_words(self):
        f = Fixture(self.tmp)
        import standardise
        found = standardise.plain_findings(f.repo, standardise.kit_files())
        self.assertEqual(found, [], "\n".join(found[:20]))

    def test_house_register_renders_the_same_facts(self):
        (self.tmp / "p").mkdir()
        (self.tmp / "h").mkdir()
        plain = Fixture(self.tmp / "p")
        house = Fixture(self.tmp / "h", register="house")
        rule = "RULES/17-one-agent-one-worktree.md"
        p, h = (plain.repo / rule).read_text(), (house.repo / rule).read_text()
        self.assertIn(".worktrees/", p)
        self.assertIn(".yggdrasil/", h)
        self.assertNotIn(".worktrees/", h)
        import re
        for rel in ("RULES/17-one-agent-one-worktree.md", "RULES/24-leave-no-leftovers.md", "docs/gates.md"):
            a, b = (plain.repo / rel).read_text(), (house.repo / rel).read_text()
            self.assertEqual(len(a.splitlines()), len(b.splitlines()), rel)
            self.assertEqual(re.findall(r"\d+", a), re.findall(r"\d+", b), f"{rel}: the numbers differ")
        self.assertIn("worktrees: .yggdrasil", (house.repo / "project.yaml").read_text())


# ---- K-2 · names from the register, declared once in project.yaml ---------------------------------------------
class K02Names(Base):
    def test_plain_names(self):
        f = Fixture(self.tmp)
        r = f.new("a1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue((f.repo / ".worktrees" / "a1").is_dir())
        self.assertEqual(sh("git branch --show-current", f.repo / ".worktrees" / "a1").stdout.strip(), "work/a1")
        self.assertEqual(sh("git status --porcelain", f.repo).stdout.strip(), "", "the worktree folder is ignored")

    def test_house_names(self):
        f = Fixture(self.tmp, register="house")
        r = f.new("a1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue((f.repo / ".yggdrasil" / "a1").is_dir())
        self.assertEqual(sh("git branch --show-current", f.repo / ".yggdrasil" / "a1").stdout.strip(), "yggdrasil/a1")

    def test_record_is_written(self):
        f = Fixture(self.tmp)
        f.new("a1", "--purpose", "the list screen", "--owner", "ada")
        rec = json.loads(sh("cat \"$(git rev-parse --git-dir)/kit.json\"", f.repo / ".worktrees" / "a1").stdout)
        self.assertEqual((rec["owner"], rec["purpose"], rec["branch"]), ("ada", "the list screen", "work/a1"))
        self.assertGreater(rec["expires_epoch"], rec["created_epoch"])


# ---- K-3 · stack profiles: link the dependencies, never the outputs -------------------------------------------
class K03Profiles(Base):
    def test_every_profile_parses(self):
        import standardise
        f = Fixture(self.tmp, apply=False)
        profiles = sorted(p.stem for p in (COLLAB / "profiles").glob("*.yaml"))
        self.assertGreaterEqual(len(profiles), 6)
        for name in profiles:
            d = miniyaml.loads(standardise.render_project(f.repo, name, "plain", "en:sv"))
            self.assertIn("stack", d, name)
            self.assertEqual(d["languages"]["project"], "en")
            self.assertEqual(d["names"]["worktrees"], ".worktrees")

    def test_node_links_node_modules_and_stays_small(self):
        def setup(repo):
            (repo / "package.json").write_text("{}")
            (repo / ".gitignore").write_text("node_modules/\ndist/\n")
            (repo / "node_modules" / "big").mkdir(parents=True)
            (repo / "node_modules" / "big" / "blob.bin").write_bytes(os.urandom(5_000_000))
        f = Fixture(self.tmp, profile="node", setup=setup)
        f.new("n1")
        wt = f.repo / ".worktrees" / "n1"
        self.assertTrue((wt / "node_modules").is_symlink())
        self.assertEqual(sh("git status --porcelain", wt).stdout.strip(), "", "the link is not a change")
        du = int(sh(["du", "-sxm", str(wt)], wt).stdout.split()[0])
        self.assertLess(du, 300)
        f.kit("worktree", "done", "n1")
        self.assertTrue((f.repo / "node_modules" / "big" / "blob.bin").is_file(), "closing never follows the link")

    def test_monorepo_keeps_a_tracked_link_and_links_parts(self):
        def setup(repo):
            for d in ("web", "ui", "server", "identity"):
                (repo / d).mkdir()
            (repo / "web" / "package.json").write_text("{}")
            (repo / "server" / "pyproject.toml").write_text("")
            (repo / "identity" / "mix.exs").write_text("")
            (repo / ".gitignore").write_text("node_modules/\ndeps/\n_build/\n")
            (repo / "web" / "node_modules").mkdir()
            (repo / "identity" / "deps").mkdir()
            (repo / "identity" / "_build").mkdir()
            os.symlink("../web/node_modules", repo / "ui" / "node_modules")
        f = Fixture(self.tmp, profile="monorepo-bun-uv-mix", setup=setup)
        f.new("m1")
        wt = f.repo / ".worktrees" / "m1"
        # web uses link_mode reflink (Turbopack refuses a link out of the root): a real folder, or a link where
        # the filesystem cannot reflink — either way it is shared, never a fresh install
        self.assertTrue((wt / "web" / "node_modules").is_dir())
        self.assertEqual(sh("git status --porcelain", wt).stdout.strip(), "", "the shared folder is not a change")
        self.assertTrue((wt / "identity" / "deps").is_symlink())
        self.assertFalse((wt / "identity" / "_build").exists(), "a build output is never shared")
        self.assertEqual(os.readlink(wt / "ui" / "node_modules"), "../web/node_modules", "the tracked link stays")

    def test_elixir_umbrella_links_deps(self):
        def setup(repo):
            (repo / "mix.exs").write_text("")
            (repo / "apps").mkdir()
            (repo / "apps" / ".keep").write_text("")
            (repo / ".gitignore").write_text("/deps/\n/_build/\n")
            (repo / "deps").mkdir()
            (repo / "_build").mkdir()
        f = Fixture(self.tmp, profile="elixir-umbrella", setup=setup)
        f.new("e1")
        wt = f.repo / ".worktrees" / "e1"
        self.assertTrue((wt / "deps").is_symlink())
        self.assertFalse((wt / "_build").exists())


# ---- K-4 · languages ------------------------------------------------------------------------------------------
class K04Languages(Base):
    def test_swedish_commit_is_refused_english_passes(self):
        f = Fixture(self.tmp)
        (f.repo / "a.txt").write_text("x\n")
        sh("git add a.txt", f.repo, check=True)
        r = sh(["git", "commit", "-qm", "Lägg till en ny vy för fakturor och kunder"], f.repo)
        self.assertNotEqual(r.returncode, 0, "a Swedish subject is refused")
        self.assertIn("reads as 'sv'", r.stderr)
        r = sh(["git", "commit", "-qm", "Add the invoices view for a client"], f.repo)
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_client_words_in_their_path_pass_and_elsewhere_are_reported(self):
        f = Fixture(self.tmp)
        set_yaml(f.repo, "languages.client_paths", '["ui/**/words.*.json"]')
        (f.repo / "ui" / "x").mkdir(parents=True)
        (f.repo / "ui" / "x" / "words.sv.json").write_text('"Dina fakturor väntar på ett beslut från dig"\n')
        (f.repo / "notes.txt").write_text("Dina fakturor väntar på ett beslut från dig\n")
        r = f.kit("lang", "files", "ui/x/words.sv.json")
        self.assertEqual(r.returncode, 0, r.stderr)
        r = f.kit("lang", "files", "notes.txt")
        self.assertEqual(r.returncode, 0, "report mode does not refuse")
        self.assertIn("outside the client paths", r.stderr)
        set_yaml(f.repo, "languages.files", "refuse")
        self.assertEqual(f.kit("lang", "files", "notes.txt").returncode, 1)

    def test_detector(self):
        from kitlib.languages import tongue_of
        self.assertEqual(tongue_of("Det här är inte klart än, vi måste göra mer"), "sv")
        self.assertIsNone(tongue_of("The office is in Malmö and the team meets on Fridays"))
        self.assertIsNone(tongue_of("const x = { a: 1 };"))


# ---- K-5 · the cap --------------------------------------------------------------------------------------------
class K05Cap(Base):
    def test_ninth_is_refused_naming_the_oldest_merged(self):
        f = Fixture(self.tmp)
        set_yaml(f.repo, "worktrees.max", "2")
        set_yaml(f.repo, "worktrees.max_leftovers", "9")
        set_yaml(f.repo, "worktrees.close_merged_on_new", "false")
        sh("git commit -qam 'tighten the cap for the test' --no-verify", f.repo, check=True)
        self.assertEqual(f.new("w1").returncode, 0)
        self.assertEqual(f.new("w2").returncode, 0)
        r = f.new("w3")
        self.assertEqual(r.returncode, 1)
        self.assertIn("the cap is 2", r.stdout)
        self.assertRegex(r.stdout, r"oldest merged is w[12]")


# ---- K-6 · the disk gate --------------------------------------------------------------------------------------
class K06Disk(Base):
    def test_new_below_the_floor_exits_1_and_says_how_much_is_free(self):
        f = Fixture(self.tmp)
        r = f.new("d1", env={"KIT_FAKE_DISK": "30/1000"})
        self.assertEqual(r.returncode, 1)
        self.assertIn("30 GB free", r.stdout)
        self.assertFalse((f.repo / ".worktrees" / "d1").exists())

    def test_build_below_the_floor_is_refused(self):
        f = Fixture(self.tmp)
        env = self.fake_engine()
        env["KIT_FAKE_DISK"] = "100/1000"  # 10 % — below 15 %
        r = f.kit("containers", "build", "--tag", "app:1", "--purpose", "product", "--release", "1", ".", env=env)
        self.assertEqual(r.returncode, 1)
        self.assertIn("below the floor", r.stdout)


# ---- K-7 · gc after merge -------------------------------------------------------------------------------------
class K07Gc(Base):
    def test_merged_and_clean_go_dirty_stays(self):
        f = Fixture(self.tmp)
        set_yaml(f.repo, "worktrees.max", "20")
        set_yaml(f.repo, "worktrees.max_leftovers", "20")
        set_yaml(f.repo, "worktrees.close_merged_on_new", "false")
        sh("git commit -qam 'raise the limits for the test' --no-verify && git push -q --no-verify origin main", f.repo, check=True)
        for i in range(5):
            self.assertEqual(f.new(f"m{i}").returncode, 0)
        (f.repo / ".worktrees" / "m4" / "wip.txt").write_text("unfinished\n")
        r = f.kit("worktree", "gc")
        self.assertIn("report only", r.stderr)
        self.assertEqual(len(list((f.repo / ".worktrees").iterdir())), 5, "a report removes nothing")
        r = f.kit("worktree", "gc", "--apply")
        left = sorted(p.name for p in (f.repo / ".worktrees").iterdir())
        self.assertEqual(left, ["m4"], r.stdout)
        self.assertIn("work in progress", r.stdout)
        self.assertEqual(sh("git branch --list 'work/m0'", f.repo).stdout.strip(), "", "the merged branch went too")

    def test_busy_worktree_is_kept(self):
        f = Fixture(self.tmp)
        set_yaml(f.repo, "worktrees.close_merged_on_new", "false")
        f.new("b1")
        r = f.kit("worktree", "gc", "--apply", env={"KIT_FAKE_BUSY": str(f.repo / ".worktrees" / "b1")})
        self.assertTrue((f.repo / ".worktrees" / "b1").is_dir())
        self.assertIn("a process works in it", r.stdout)

    def test_new_closes_merged_worktrees_first(self):
        f = Fixture(self.tmp)
        f.new("old")
        r = f.new("next")
        self.assertIn("closed\told", r.stdout)
        self.assertFalse((f.repo / ".worktrees" / "old").exists())


# ---- K-8 · salvage before removal -----------------------------------------------------------------------------
class K08Salvage(Base):
    def test_dead_workers_files_reach_the_remote_before_the_folder_goes(self):
        f = Fixture(self.tmp)
        set_yaml(f.repo, "worktrees.stale_hours", "0")
        set_yaml(f.repo, "worktrees.close_merged_on_new", "false")
        f.new("dead")
        wt = f.repo / ".worktrees" / "dead"
        for i in range(26):
            (wt / f"new{i}.txt").write_text(f"work {i}\n")
        r = f.kit("worktree", "salvage")
        self.assertIn("salvage", r.stdout)
        self.assertTrue(wt.is_dir(), "a report removes nothing")
        r = f.kit("worktree", "gc", "--apply")
        self.assertFalse(wt.exists(), r.stdout)
        log = sh(["git", "--git-dir", str(f.remote), "log", "-1", "--format=%s", "work/dead"], self.tmp)
        self.assertEqual(log.stdout.strip(), "WIP (worker gone): saved as found, not reviewed")
        files = sh(["git", "--git-dir", str(f.remote), "ls-tree", "--name-only", "work/dead"], self.tmp).stdout.split()
        self.assertEqual(len([x for x in files if x.startswith("new")]), 26)

    def test_done_refuses_to_lose_work(self):
        f = Fixture(self.tmp)
        f.new("w")
        (f.repo / ".worktrees" / "w" / "x.txt").write_text("x\n")
        r = f.kit("worktree", "done", "w")
        self.assertEqual(r.returncode, 1)
        self.assertTrue((f.repo / ".worktrees" / "w").is_dir())
        r = f.kit("worktree", "done", "w", "--salvage")
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertFalse((f.repo / ".worktrees" / "w").exists())


# ---- K-9 · hooks chain, never steal ---------------------------------------------------------------------------
class K09Hooks(Base):
    def _marker_hook(self, d: Path, name: str, marker: Path):
        d.mkdir(parents=True, exist_ok=True)
        h = d / name
        h.write_text(f"#!/usr/bin/env bash\necho ran >> {marker}\n")
        h.chmod(0o755)

    def test_an_existing_hooks_path_keeps_running_regression(self):
        marker = self.tmp / "marker"

        def setup(repo):
            self._marker_hook(repo / "myhooks", "pre-commit", marker)
        f = Fixture(self.tmp, setup=setup, apply=False)
        sh("git config core.hooksPath myhooks", f.repo, check=True)
        out = f.apply("node")
        self.assertIn("keep running after the kit", out)
        self.assertEqual(sh("git config core.hooksPath", f.repo).stdout.strip(), ".githooks")
        self.assertEqual(sh("git config --local core.hooksPath", f.repo).stdout.strip(), "myhooks",
                         "the shared setting other checkouts read is not taken")
        marker.unlink(missing_ok=True)
        (f.repo / "b.txt").write_text("b\n")
        sh("git add b.txt", f.repo, check=True)
        r = sh(["git", "commit", "-qm", "Add a file to prove the chain"], f.repo)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(marker.is_file(), "the repository's own pre-commit ran after the kit's")
        r = sh([sys.executable, str(COLLAB / "standardise.py"), "--uninstall", str(f.repo)], self.tmp)
        self.assertEqual(sh("git config core.hooksPath", f.repo).stdout.strip(), "myhooks", r.stdout)

    def test_real_git_hooks_keep_running(self):
        marker = self.tmp / "marker2"
        f = Fixture(self.tmp, apply=False)
        self._marker_hook(f.repo / ".git" / "hooks", "prepare-commit-msg", marker)
        f.apply("node")
        (f.repo / "c.txt").write_text("c\n")
        sh("git add c.txt", f.repo, check=True)
        sh(["git", "commit", "-qm", "Add another file for the chain"], f.repo, check=True)
        self.assertTrue(marker.is_file(), "a hook the kit has no check for still runs")

    def test_tracked_hook_folder_and_no_double_run(self):
        marker = self.tmp / "marker3"

        def setup(repo):
            d = repo / "scripts" / "hooks"
            d.mkdir(parents=True)
            # the repository's hook calls back into .githooks, as a chaining installer of its own would
            (d / "pre-commit").write_text(f"#!/usr/bin/env bash\necho ran >> {marker}\n"
                                          f"[ -x .githooks/pre-commit ] && .githooks/pre-commit\nexit 0\n")
            (d / "pre-commit").chmod(0o755)
        f = Fixture(self.tmp, setup=setup, apply=False)
        f.apply("monorepo-bun-uv-mix")
        (f.repo / "d.txt").write_text("d\n")
        sh("git add d.txt", f.repo, check=True)
        r = sh(["git", "commit", "-qm", "Add a third file for the chain"], f.repo)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(marker.read_text().count("ran"), 1, "ran once, no loop")


# ---- K-10 · containers: who may build, who may remove ---------------------------------------------------------
class K10ContainerDoor(Base):
    def test_rmi_on_a_product_host_is_refused(self):
        f = Fixture(self.tmp)
        env = self.fake_engine()
        env["KIT_PRODUCT_HOST"] = "1"
        r = f.kit("containers", "rmi", "app:1", env=env)
        self.assertEqual(r.returncode, 1)
        self.assertIn("product host", r.stdout)
        self.assertFalse(Path(env["_log"]).exists(), "the engine was never called")
        r = f.kit("containers", "ps", env=env)
        self.assertEqual(r.returncode, 0, "read-only passes")
        r = f.kit("containers", "build", "--tag", "a:1", "--purpose", "p", "--release", "1", env=env)
        self.assertEqual(r.returncode, 1, "no builds on a product host")

    def test_prune_removes_nothing_on_a_product_host(self):
        f = Fixture(self.tmp)
        env = self.fake_engine(images=[{"Id": "abc" * 5, "Names": [], "Labels": {"project": "repo"}, "Created": 1}])
        env["KIT_PRODUCT_HOST"] = "1"
        r = f.kit("prune", "--class", "images", "--apply", env=env)
        self.assertIn("product host", r.stdout)
        log = Path(env["_log"]).read_text() if Path(env["_log"]).exists() else ""
        self.assertNotIn("rmi", log)


# ---- K-11 · one builder, labels, retention --------------------------------------------------------------------
class K11Builds(Base):
    def test_build_carries_labels_and_takes_the_lock(self):
        f = Fixture(self.tmp)
        env = self.fake_engine()
        env["KIT_LOCK_DIR"] = str(self.tmp)
        r = f.kit("containers", "build", "--tag", "app:2", "--purpose", "product", "--release", "2", ".", env=env)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        log = Path(env["_log"]).read_text()
        for label in ("project=repo", "purpose=product", "release=2"):
            self.assertIn(label, log)
        env["FAKE_BUILD_SECONDS"] = "3"
        first = subprocess.Popen([sys.executable, "scripts/kit.py", "containers", "build", "--tag", "app:3", "--purpose",
                                  "p", "--release", "3", "."], cwd=f.repo, env={**os.environ, **env, "KIT_FAKE_DISK": "500/1000",
                                  "KIT_PRODUCT_HOST": "0"}, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        time.sleep(1)
        r = f.kit("containers", "build", "--tag", "app:4", "--purpose", "p", "--release", "4", ".", env=env)
        first.wait()
        self.assertEqual(r.returncode, 1)
        self.assertIn("one build at a time", r.stdout)

    def test_retention_keeps_current_and_previous(self):
        f = Fixture(self.tmp)
        lab = {"project": "repo", "purpose": "product", "release": "x"}
        imgs = [{"Id": f"{i}" * 12, "Names": [f"localhost/app:{i}"], "Labels": lab, "Created": 1000 + i} for i in range(1, 5)]
        imgs.append({"Id": "d" * 12, "Names": [], "Labels": lab, "Created": 1})
        env = self.fake_engine(images=imgs)
        r = f.kit("containers", "retain", env=env)
        self.assertIn("localhost/app:1", r.stdout)
        self.assertIn("localhost/app:2", r.stdout)
        self.assertNotIn("localhost/app:4\t", r.stdout.replace("remove\tlocalhost/app:4", "X"))
        self.assertIn("dangling", r.stdout)
        f.kit("containers", "retain", "--apply", env=env)
        log = Path(env["_log"]).read_text()
        self.assertIn("rmi localhost/app:1", log)
        self.assertIn("rmi localhost/app:2", log)
        self.assertNotIn("rmi localhost/app:3", log)
        self.assertNotIn("rmi localhost/app:4", log)


# ---- K-12 · check-host ----------------------------------------------------------------------------------------
class K12CheckHost(Base):
    def test_strict_fails_below_the_floor_and_over_retention(self):
        f = Fixture(self.tmp)
        imgs = [{"Id": "1" * 12, "Names": [], "Labels": {}, "Created": 1}]
        env = self.fake_engine(images=imgs, containers=[{"Id": "c" * 12, "Names": ["old"], "State": "exited",
                                                         "ExitedAt": int(time.time()) - 3 * 86400, "Labels": {}}])
        env["KIT_FAKE_DISK"] = "150/1000"  # 15 % used would be 85 %: at the line, ok
        r = f.kit("check-host", "--strict", "--repo", str(f.repo), env=env)
        self.assertEqual(r.returncode, 1, "untagged, unlabelled and a stopped container are over")
        self.assertIn("untagged", r.stdout)
        self.assertIn("older than a day", r.stdout)
        env2 = self.fake_engine()
        env2["KIT_FAKE_DISK"] = "140/1000"  # 86 % used — the day before the crash
        r = f.kit("check-host", "--strict", "--repo", str(f.repo), env=env2)
        self.assertEqual(r.returncode, 1)
        self.assertRegex(r.stdout, r"OVER\tdisk")
        env2["KIT_FAKE_DISK"] = "500/1000"
        r = f.kit("check-host", "--strict", "--repo", str(f.repo), env=env2)
        self.assertEqual(r.returncode, 0, r.stdout)


# ---- K-13 · documents straight to main, code by pull request --------------------------------------------------
class K13Roads(Base):
    def test_docs_push_reaches_main_code_does_not(self):
        f = Fixture(self.tmp)
        (f.repo / "docs").mkdir(exist_ok=True)
        (f.repo / "docs" / "a-note.md").write_text("# a note\n")
        sh("git add -A && git commit -qm 'Write a note for the next person' --no-verify", f.repo, check=True)
        r = sh("git push -q origin main", f.repo)
        self.assertEqual(r.returncode, 0, r.stderr)
        (f.repo / "app.py").write_text("print(1)\n")
        sh("git add -A && git commit -qm 'Add the first line of code' --no-verify", f.repo, check=True)
        r = sh("git push -q origin main", f.repo)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("app.py", r.stderr)


# ---- RULES/24 · every leftover class ----------------------------------------------------------------------------
class Leftovers(Base):
    def test_branches_merged_go_unmerged_stay(self):
        f = Fixture(self.tmp)
        sh("git branch done-thing && git checkout -q -b open-thing && echo x > o.txt && git add o.txt && "
           "git commit -qm 'Some unfinished work here' --no-verify && git checkout -q main", f.repo, check=True)
        r = f.kit("prune", "--class", "branches", "--apply")
        self.assertIn("done-thing", r.stdout)
        branches = sh("git branch --format='%(refname:short)'", f.repo).stdout.split()
        self.assertNotIn("done-thing", branches)
        self.assertIn("open-thing", branches)

    def test_remote_refs_gone_from_the_remote_are_pruned(self):
        f = Fixture(self.tmp)
        sh("git push -q --no-verify origin main:gone-branch && git fetch -q origin", f.repo, check=True)
        sh(["git", "--git-dir", str(f.remote), "branch", "-D", "gone-branch"], self.tmp, check=True)
        r = f.kit("prune", "--class", "remote_refs", "--apply")
        self.assertIn("origin/gone-branch", r.stdout)
        self.assertEqual(sh("git branch -r --list origin/gone-branch", f.repo).stdout.strip(), "")

    def test_caches_in_idle_worktrees_go_tracked_folders_stay(self):
        def setup(repo):
            (repo / "package.json").write_text("{}")
            (repo / ".gitignore").write_text("dist/\n")
            (repo / "build").mkdir()
            (repo / "build" / "tracked.txt").write_text("tracked\n")
        f = Fixture(self.tmp, setup=setup)
        set_yaml(f.repo, "worktrees.close_merged_on_new", "false")
        sh("git commit -qam 'adjust the fixture limits' --no-verify", f.repo, check=True)
        f.new("c1")
        wt = f.repo / ".worktrees" / "c1"
        (wt / "dist").mkdir()
        (wt / "dist" / "out.js").write_text("x")
        set_yaml(f.repo, "leftovers.caches", "{apply: true, idle_hours: 0}")
        r = f.kit("prune", "--class", "caches", "--apply")
        self.assertFalse((wt / "dist").exists(), r.stdout)
        self.assertTrue((wt / "build" / "tracked.txt").is_file())

    def test_scratch_old_goes_new_stays_broad_refused(self):
        f = Fixture(self.tmp)
        scratch = self.tmp / "scratch" / "kit"
        scratch.mkdir(parents=True)
        old, new = scratch / "old.txt", scratch / "new.txt"
        old.write_text("o")
        new.write_text("n")
        t = time.time() - 3 * 86400
        os.utime(old, (t, t))
        set_yaml(f.repo, "leftovers.scratch", f'{{apply: true, dir: "{scratch}", older_than_hours: 24}}')
        f.kit("prune", "--class", "scratch", "--apply")
        self.assertFalse(old.exists())
        self.assertTrue(new.exists())
        set_yaml(f.repo, "leftovers.scratch", '{apply: true, dir: "~", older_than_hours: 24}')
        r = f.kit("prune", "--class", "scratch")
        self.assertIn("too broad", r.stdout + r.stderr)

    def test_test_databases_with_declared_commands(self):
        f = Fixture(self.tmp)
        log = self.tmp / "dropped"
        set_yaml(f.repo, "leftovers.test_databases",
                 f'{{apply: true, pattern: "app_test_*", list: "printf \'app_test_1\\\\napp_prod\\\\napp_test_2\\\\n\'", drop: "echo {{name}} >> {log}"}}')
        r = f.kit("prune", "--class", "test_databases", "--apply")
        self.assertEqual(sorted(log.read_text().split()), ["app_test_1", "app_test_2"], r.stdout + r.stderr)

    def test_volumes_and_stopped_containers(self):
        f = Fixture(self.tmp)
        env = self.fake_engine(
            containers=[{"Id": "a" * 12, "Names": ["old-run"], "State": "exited", "ExitedAt": int(time.time()) - 2 * 86400,
                         "Labels": {"project": "repo"}},
                        {"Id": "b" * 12, "Names": ["fresh"], "State": "exited", "ExitedAt": int(time.time()) - 60,
                         "Labels": {"project": "repo"}},
                        {"Id": "c" * 12, "Names": ["other"], "State": "exited", "ExitedAt": 1, "Labels": {"project": "else"}}],
            volumes=[{"Name": "repo-data", "Labels": {"project": "repo"}}])
        f.kit("prune", "--class", "volumes,stopped_containers", "--apply", env=env)
        log = Path(env["_log"]).read_text()
        self.assertIn("volume rm repo-data", log)
        self.assertIn("rm old-run", log)
        self.assertNotIn("rm fresh", log)
        self.assertNotIn("rm other", log)

    def test_doctor_refuses_over_the_budget_and_summary_counts(self):
        f = Fixture(self.tmp)
        set_yaml(f.repo, "worktrees.close_merged_on_new", "false")
        set_yaml(f.repo, "worktrees.max_leftovers", "0")
        set_yaml(f.repo, "worktrees.stale_hours", "0")
        sh("git commit -qam 'adjust the fixture limits' --no-verify", f.repo, check=True)
        f.new("l1")
        r = f.kit("doctor")
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("STOP leftovers", r.stdout)
        r = f.new("l2")
        self.assertEqual(r.returncode, 1, "new refuses over the leftover budget")
        f.kit("prune", "--apply")
        self.assertEqual(f.kit("doctor").returncode, 0)
        s = f.kit("summary").stdout
        self.assertIn("new: 1", s)
        self.assertIn("close: 1", s)

    def test_post_merge_hook_closes_merged_worktrees(self):
        f = Fixture(self.tmp)
        set_yaml(f.repo, "worktrees.close_merged_on_new", "false")
        sh("git commit -qam 'adjust the fixture limits' --no-verify && git push -q --no-verify origin main", f.repo, check=True)
        f.new("pm")
        wt = f.repo / ".worktrees" / "pm"
        (wt / "f.txt").write_text("f\n")
        sh("git add f.txt && git commit -qm 'A change that will be merged' --no-verify && git push -q --no-verify origin work/pm", wt, check=True)
        sh("git merge -q --no-ff --no-edit work/pm", f.repo, check=True)
        self.assertFalse(wt.exists(), "post-merge closed the merged worktree")


# ---- standardise: upgrade an older kit without losing local rules ----------------------------------------------
class Standardise(Base):
    def test_older_kit_files_upgrade_local_ones_stay_and_renames_move(self):
        import standardise
        hist = standardise.history()
        root = COLLAB.parents[1]
        f = Fixture(self.tmp, apply=False)
        current = standardise.blob((KIT / "scripts" / "worktree.sh").read_bytes())
        old_blob = sorted(hist["scripts/worktree.sh"] - {current})[0]
        old = sh(["git", "cat-file", "-p", old_blob], root, check=True).stdout
        (f.repo / "scripts").mkdir()
        (f.repo / "scripts" / "worktree.sh").write_text(old)
        (f.repo / "scripts" / "checks.sh").write_text("#!/bin/sh\necho my own checks\n")
        arm = sorted(hist["scripts/notify-arm.sh"])[0]
        (f.repo / "scripts" / "notify-arm.sh").write_text(sh(["git", "cat-file", "-p", arm], root, check=True).stdout)
        r = sh([sys.executable, str(COLLAB / "standardise.py"), "--check", str(f.repo), "--profile", "node"], self.tmp)
        self.assertIn("older kit files (upgraded by --apply): 1", r.stdout)
        self.assertIn("scripts/checks.sh", r.stdout)
        out = f.apply("node")
        self.assertEqual((f.repo / "scripts" / "worktree.sh").read_bytes(), (KIT / "scripts" / "worktree.sh").read_bytes())
        self.assertEqual((f.repo / "scripts" / "checks.sh").read_text(), "#!/bin/sh\necho my own checks\n", "a local rule wins")
        self.assertFalse((f.repo / "scripts" / "notify-arm.sh").exists())
        self.assertTrue((f.repo / "scripts" / "notify.sh").exists())
        self.assertIn("1 local kept", out)

    def test_existing_project_yaml_is_never_replaced(self):
        f = Fixture(self.tmp)
        p = f.repo / "project.yaml"
        p.write_text(p.read_text() + "\n# mine\n")
        before = p.read_text()
        f.apply("node")
        self.assertEqual(p.read_text(), before)


class MiniYaml(unittest.TestCase):
    def test_subset(self):
        d = miniyaml.loads(textwrap.dedent("""\
            a: 1  # c
            b: "x # not a comment"
            c: [p, "q r", 3]
            d: {k: v, n: 2}
            e:
              - path: web
                link: [node_modules]
              - plain
            f:
            - one
            g: true
            """))
        self.assertEqual(d["a"], 1)
        self.assertEqual(d["b"], "x # not a comment")
        self.assertEqual(d["c"], ["p", "q r", 3])
        self.assertEqual(d["d"], {"k": "v", "n": 2})
        self.assertEqual(d["e"], [{"path": "web", "link": ["node_modules"]}, "plain"])
        self.assertEqual(d["f"], ["one"])
        self.assertIs(d["g"], True)


if __name__ == "__main__":
    unittest.main()
