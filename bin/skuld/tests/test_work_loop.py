#!/usr/bin/env python3
"""The proofs for the work loop (bin/skuld/work_loop.py). The world is stood in for: a throwaway home, a fake
`gh`, fake boards and a fake spawner. Nothing is spawned, no board is touched."""
import argparse
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import work_loop as wl  # noqa: E402


class FakeBoard:
    def __init__(self, cards):
        self.cards, self.moved, self.links = cards, [], []

    def list_all(self):
        return self.cards

    def get_card(self, card):
        return next((c for c in self.cards if c["card"] == card), {"card": card, "title": ""})

    def update_card(self, card, group=None, **kw):
        self.moved.append((card, group))

    def add_link(self, card, url, title):
        self.links.append((card, url, title))


class FakeSpawner:
    def __init__(self, fail=()):
        self.spawned, self.fail = [], set(fail)

    def spawn(self, eid, pid, task):
        if pid in self.fail:
            raise wl.Refusal("no clone here")
        self.spawned.append((eid, pid, task))
        return f"/brief/{eid}.md"


class FakeGh:
    def __init__(self, prs):
        self.prs = prs

    def pr(self, repo, n):
        return self.prs.get((repo, str(n)))


def card(cid, title, group="unstarted", labels=(), priority=None, parent=None, created=None):
    return {"card": cid, "title": title, "group": group, "labels": list(labels), "priority": priority,
            "parent": parent, "created": created, "description": f"body of {cid}"}


class Home:
    """A throwaway home: registry, config, state."""

    def __init__(self, test, registry, config=""):
        self.tmp = tempfile.TemporaryDirectory()
        test.addCleanup(self.tmp.cleanup)
        self.home = self.tmp.name
        os.makedirs(os.path.join(self.home, "hodd", "identity"))
        os.makedirs(os.path.join(self.home, "config"))
        os.makedirs(os.path.join(self.home, "state", ".reviewed"))
        open(os.path.join(self.home, "hodd", "identity", "projects.yaml"), "w").write(registry)
        open(os.path.join(self.home, "config", "work-loop.yaml"), "w").write(config)
        self.state = os.path.join(self.home, "state")
        self._old = dict(os.environ)
        os.environ.update(YMIR_HOME=self.home, YMIR_WORK_LOOP_HOST="box", YMIR_WORK_LOOP_STATE=self.state)
        os.environ.pop("YMIR_WORK_LOOP_LIMIT", None)
        test.addCleanup(lambda: (os.environ.clear(), os.environ.update(self._old)))

    def errand(self, eid, kind="ship", status="working: x"):
        open(os.path.join(self.state, eid + ".meta"), "w").write(f"id={eid}\nkind={kind}\n")
        if status:
            open(os.path.join(self.state, eid + ".status"), "w").write(status + "\n")

    def judged(self, rid, repo, pr, head, verdict):
        d = os.path.join(self.state, ".reviewed")
        open(os.path.join(d, rid + ".judged"), "w").write(f"repo={repo}\npr={pr}\nhead={head}\ntask={rid}\n")
        open(os.path.join(d, f"{rid}.{head}.acted"), "w").write(verdict)


REGISTRY = """
projects:
  - id: alpha
    git: {owner: acme, repo: alpha}
    board: {adapter: mcp, place: acme/Alpha}
  - id: beta
    git: {owner: acme, repo: beta}
    board: {adapter: mcp, place: acme/Beta}
  - id: gamma
    loop: off
    git: {owner: acme, repo: gamma}
    board: {adapter: mcp, place: acme/Gamma}
"""


def run(h, boards=None, gh=None, spawner=None, live=None, load=1.0, arm=True, dry=False, review=False, all_=False):
    args = argparse.Namespace(dry_run=dry, no_review=not review, all=all_, json=False)
    sp = spawner or FakeSpawner()
    env = {"boards": boards if boards is not None else {}, "gh": gh or FakeGh({}), "spawner": sp,
           "load": lambda: load, "arm": lambda: arm, "keeper": lambda: "ok"}
    if live is not None:
        env["live"] = live
    return wl.cycle(args, env), sp


class LimitAndOrder(unittest.TestCase):
    def test_default_limit_is_one_with_no_config(self):
        h = Home(self, REGISTRY)
        self.assertEqual(wl.config(h.home, "box")["limit"], 1)

    def test_limit_by_host_then_role(self):
        h = Home(self, REGISTRY, "limits: {box: 4, dev: 2}\n")
        self.assertEqual(wl.config(h.home, "box")["limit"], 4)
        self.assertEqual(wl.config(h.home, "other")["limit"], 1)

    def test_judges_are_not_counted_against_coders(self):
        h = Home(self, REGISTRY, "limits: {box: 2}\n")
        h.errand("c1")
        h.errand("pr-1-review", kind="scout")
        h.errand("old", status="done: x")
        live = wl.live_errands(h.state)
        self.assertEqual(sorted(wl.coders(live)), ["c1"])
        b = {"alpha": FakeBoard([card("1", "Do a thing"), card("2", "Do another")])}
        rep, sp = run(h, boards=b)
        self.assertEqual(len(sp.spawned), 1)  # limit 2, one coder standing: exactly one slot

    def test_a_full_seat_gets_nothing(self):
        h = Home(self, REGISTRY, "limits: {box: 1}\n")
        h.errand("c1")
        rep, sp = run(h, boards={"alpha": FakeBoard([card("1", "Do a thing")])})
        self.assertEqual(sp.spawned, [])
        self.assertIn("nothing to top up", rep["notes"][-1])

    def test_priority_then_oldest(self):
        h = Home(self, REGISTRY, "limits: {box: 5}\nmax_per_cycle: 5\n")
        b = {"alpha": FakeBoard([card("10", "Low one", priority="low"), card("12", "Urgent late", priority="urgent"),
                                 card("11", "Urgent early", priority="urgent")])}
        rep, sp = run(h, boards=b)
        self.assertEqual([x[0].split("-")[-3:][0] for x in sp.spawned][:0], [])
        self.assertEqual([d["key"] for d in rep["dispatched"]], ["card:alpha:11", "card:alpha:12", "card:alpha:10"])


class Skips(unittest.TestCase):
    def test_decision_hold_plan_container_and_not_todo_are_skipped(self):
        h = Home(self, REGISTRY, "limits: {box: 9}\nmax_per_cycle: 9\n")
        b = {"alpha": FakeBoard([
            card("1", "His call", labels=["decision"]), card("2", "Held", labels=["hold"]),
            card("3", "335 · The plan", labels=["plan"]), card("4", "Phase one", labels=["plan"], parent="3"),
            card("5", "Already going", group="started"), card("6", "Backlog", group="backlog"),
            card("7", "Fix the door")])}
        rep, _ = run(h, boards=b)
        self.assertEqual(sorted(d["key"] for d in rep["dispatched"]), ["card:alpha:4", "card:alpha:7"])

    def test_loop_off_project_is_skipped(self):
        h = Home(self, REGISTRY, "limits: {box: 9}\n")
        b = {"gamma": FakeBoard([card("1", "Do it")])}
        rep, sp = run(h, boards=b)
        self.assertEqual(sp.spawned, [])

    def test_every_project_with_a_board_takes_part(self):
        h = Home(self, REGISTRY, "limits: {box: 9}\nmax_per_cycle: 9\n")
        b = {"alpha": FakeBoard([card("1", "Do a")]), "beta": FakeBoard([card("2", "Do b")])}
        rep, _ = run(h, boards=b)
        self.assertEqual(sorted(d["project"] for d in rep["dispatched"]), ["alpha", "beta"])

    def test_an_unreadable_board_is_named_not_empty(self):
        class Dead:
            def list_all(self):
                raise RuntimeError("the board did not answer")
        h = Home(self, REGISTRY, "limits: {box: 9}\n")
        rep, _ = run(h, boards={"alpha": Dead(), "beta": FakeBoard([card("2", "Do b")])})
        self.assertTrue(any("did not answer" in s["why"] for s in rep["skipped"]))
        self.assertEqual(len(rep["dispatched"]), 1)


class Brakes(unittest.TestCase):
    def test_load_at_the_ceiling_stops_the_spawns(self):
        h = Home(self, REGISTRY, "limits: {box: 9}\nload_ceiling: 8\n")
        rep, sp = run(h, boards={"alpha": FakeBoard([card("1", "Do a")])}, load=9.5)
        self.assertEqual(sp.spawned, [])
        self.assertTrue(any("ceiling" in n for n in rep["notes"]))

    def test_no_arm_spawns_nothing(self):
        h = Home(self, REGISTRY, "limits: {box: 9}\n")
        rep, sp = run(h, boards={"alpha": FakeBoard([card("1", "Do a")])}, arm=False)
        self.assertEqual(sp.spawned, [])
        self.assertEqual(rep["dispatched"][0]["verdict"], "would-dispatch")

    def test_the_seal_hold_stops_merging_not_working(self):
        h = Home(self, REGISTRY, "limits: {box: 9}\n")
        open(os.path.join(h.state, ".seal-hold"), "w").write("held\n")
        rep, sp = run(h, boards={"alpha": FakeBoard([card("1", "Do a")])})
        self.assertEqual(len(sp.spawned), 1)
        self.assertTrue(any("seal hold" in n for n in rep["notes"]))

    def test_dry_run_writes_nothing(self):
        h = Home(self, REGISTRY, "limits: {box: 9}\n")
        b = FakeBoard([card("1", "Do a")])
        rep, sp = run(h, boards={"alpha": b}, dry=True)
        self.assertEqual((sp.spawned, b.moved), ([], []))
        self.assertFalse(os.path.exists(os.path.join(h.state, "work-loop", "dispatch.jsonl")))

    def test_a_failed_spawn_is_ledgered_and_capped(self):
        h = Home(self, REGISTRY, "limits: {box: 9}\ncard_cap: 2\n")
        b = {"alpha": FakeBoard([card("1", "Do a")])}
        sp = FakeSpawner(fail={"alpha"})
        for _ in range(3):
            run(h, boards=b, spawner=sp)
        rows = wl.Ledger(h.state).rows()
        self.assertEqual([r["verdict"] for r in rows], ["failed", "failed"])  # the third cycle skipped it


class Dispatch(unittest.TestCase):
    def test_a_card_dispatch_moves_the_card_links_it_and_is_ledgered(self):
        h = Home(self, REGISTRY, "limits: {box: 3}\n")
        b = FakeBoard([card("1", "Add the thing")])
        rep, sp = run(h, boards={"alpha": b})
        eid = sp.spawned[0][0]
        self.assertEqual(b.moved, [("1", "started")])
        self.assertEqual(b.links[0][0], "1")
        self.assertIn(eid, b.links[0][2])
        row = wl.Ledger(h.state).rows()[0]
        self.assertEqual((row["verdict"], row["errand"], row["key"]), ("dispatched", eid, "card:alpha:1"))
        self.assertIn("Take card 1", sp.spawned[0][2])

    def test_a_card_held_by_a_live_errand_is_not_taken_twice(self):
        h = Home(self, REGISTRY, "limits: {box: 3}\nmax_per_cycle: 3\n")
        b = {"alpha": FakeBoard([card("1", "Add the thing")])}
        run(h, boards=b)
        eid = wl.Ledger(h.state).rows()[0]["errand"]
        h.errand(eid)
        rep, sp = run(h, boards=b)
        self.assertEqual(sp.spawned, [])


class Rework(unittest.TestCase):
    HEAD = "a" * 40

    def prs(self, **over):
        pr = {"state": "OPEN", "headRefName": "eindri/feature", "headRefOid": self.HEAD, "labels": [],
              "body": "Arm: box"}
        pr.update(over)
        return {("acme/alpha", "7"): pr}

    def test_needs_rework_comes_before_cards_and_goes_to_the_branch(self):
        h = Home(self, REGISTRY, "limits: {box: 1}\n")
        h.judged("pr-7-review", "acme/alpha", "7", self.HEAD, "needs-rework: 1. a test\n")
        rep, sp = run(h, boards={"alpha": FakeBoard([card("1", "Do a")])}, gh=FakeGh(self.prs()))
        self.assertEqual(rep["dispatched"][0]["kind"], "rework")
        self.assertIn("eindri/feature", sp.spawned[0][2])
        self.assertIn("1. a test", sp.spawned[0][2])

    def test_another_machines_pr_is_left_to_that_machine(self):
        h = Home(self, REGISTRY, "limits: {box: 1}\n")
        h.judged("pr-7-review", "acme/alpha", "7", self.HEAD, "needs-rework: 1. a test\n")
        rep, sp = run(h, gh=FakeGh(self.prs(body="Arm: elsewhere")))
        self.assertEqual(sp.spawned, [])

    def test_a_pr_no_machine_claims_is_taken_here(self):
        h = Home(self, REGISTRY, "limits: {box: 1}\n")
        h.judged("pr-7-review", "acme/alpha", "7", self.HEAD, "needs-rework: 1. a test\n")
        rep, sp = run(h, gh=FakeGh(self.prs(body="no arm line")))
        self.assertEqual(len(sp.spawned), 1)

    def test_a_head_that_moved_or_a_closed_pr_is_not_reworked(self):
        h = Home(self, REGISTRY, "limits: {box: 1}\n")
        h.judged("pr-7-review", "acme/alpha", "7", self.HEAD, "needs-rework: 1. a test\n")
        rep, sp = run(h, gh=FakeGh(self.prs(headRefOid="b" * 40)))
        self.assertEqual(sp.spawned, [])
        rep, sp = run(h, gh=FakeGh(self.prs(state="MERGED")))
        self.assertEqual(sp.spawned, [])

    def test_the_authors_own_live_worker_holds_it(self):
        h = Home(self, REGISTRY, "limits: {box: 3}\n")
        h.judged("pr-7-review", "acme/alpha", "7", self.HEAD, "needs-rework: 1. a test\n")
        h.errand("feature")
        rep, sp = run(h, gh=FakeGh(self.prs()))
        self.assertEqual(sp.spawned, [])

    def test_a_hold_label_and_an_approved_verdict_are_skipped(self):
        h = Home(self, REGISTRY, "limits: {box: 1}\n")
        h.judged("pr-7-review", "acme/alpha", "7", self.HEAD, "needs-rework: 1. a test\n")
        rep, sp = run(h, gh=FakeGh(self.prs(labels=[{"name": "hold"}])))
        self.assertEqual(sp.spawned, [])
        h2 = Home(self, REGISTRY, "limits: {box: 1}\n")
        h2.judged("pr-7-review", "acme/alpha", "7", self.HEAD, "merged\n")
        rep, sp = run(h2, gh=FakeGh(self.prs()))
        self.assertEqual(sp.spawned, [])

    def test_the_rework_cap_names_the_helm(self):
        h = Home(self, REGISTRY, "limits: {box: 9}\nrework_cap: 1\n")
        h.judged("pr-7-review", "acme/alpha", "7", self.HEAD, "needs-rework: 1. a test\n")
        gh = FakeGh(self.prs())
        run(h, gh=gh)
        rep, sp = run(h, gh=gh)
        self.assertEqual(sp.spawned, [])
        self.assertTrue(any("cap" in s["why"] for s in rep["skipped"]))


if __name__ == "__main__":
    unittest.main(verbosity=1)
