#!/usr/bin/env python3
"""judge-carry.py — may the judge's approval of one head carry over to a newer head?

WHY (review of #863, 2026-11-21, measured by the helm): approvals kept dying because the head moved
AFTER the judge approved. An automation pushes two kinds of commit into PR branches: a change-log
commit (a `## CHANGE LOG` section added to a Markdown file) and a merge of the base branch. Neither
changes what the judge read, yet each moved the head, and a moved head is new work — so the approval
was thrown away and the PR waited for another judge.

THE LAW. An approval of head A carries to head B only when A is an ancestor of B and EVERY commit
between them (those not already on the base branch) is one of:

  (a) a MERGE of the base branch: two parents, the second already on the base, and the merge's tree
      is EXACTLY the tree git computes for merging those two parents (git merge-tree --write-tree).
      Approved tree + the base's changes, nothing hand-edited inside the merge.
  (b) a CHANGE-LOG commit: every file it touches is an EXISTING Markdown file (modified, never added
      or deleted) whose copy in the APPROVED head already carries a `## CHANGE LOG` heading; it removes
      no non-blank line, adds no `## ` heading line of any kind, and every non-blank line it adds lies
      below that heading (inside the section, up to the next `## ` heading).

      Review of #863 (2026-11-21): the first form of this rule accepted a `## CHANGE LOG` heading added
      in the same commit, and whole new Markdown files, so any unjudged text could be dressed as a
      change log and carry the approval to a merge with no judge. A section the judge never saw cannot
      be opened after the approval.

Anything else — a line of code, a line of prose outside a CHANGE LOG section, a merge with a manual
resolution, a merge of a branch that is not the base — needs a new judgement. A history that cannot
be read (a missing object, a failed fetch) carries nothing.

Usage:
  judge-carry.py <clone> <approved-sha> <current-sha> <base-sha>

Prints one TOON row per commit and a verdict line. Exit: 0 carries · 1 does not · 2 usage or unreadable.
"""
from __future__ import annotations

import re
import subprocess
import sys

HEADING = re.compile(r"^##\s+CHANGE LOG\s*$", re.IGNORECASE)
NEXT = re.compile(r"^##\s")
HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")


def git(clone: str, *args: str, ok: tuple[int, ...] = (0,)) -> str:
    p = subprocess.run(["git", "-C", clone, *args], capture_output=True, text=True)
    if p.returncode not in ok:
        raise RuntimeError(f"git {' '.join(args)}: {p.stderr.strip() or p.returncode}")
    return p.stdout


def is_ancestor(clone: str, a: str, b: str) -> bool:
    return subprocess.run(["git", "-C", clone, "merge-base", "--is-ancestor", a, b],
                          capture_output=True).returncode == 0


def changelog_lines(text: str) -> set[int]:
    """1-based line numbers that lie inside a `## CHANGE LOG` section (the heading included)."""
    inside, out = False, set()
    for i, line in enumerate(text.splitlines(), 1):
        if HEADING.match(line):
            inside = True
        elif NEXT.match(line):
            inside = False
        if inside:
            out.add(i)
    return out


def show(clone: str, rev: str, path: str) -> str:
    p = subprocess.run(["git", "-C", clone, "show", f"{rev}:{path}"], capture_output=True, text=True)
    return p.stdout if p.returncode == 0 else ""


def changelog_only(clone: str, commit: str, parent: str, approved: str) -> tuple[bool, str]:
    names = git(clone, "diff", "--name-status", "--no-renames", parent, commit).splitlines()
    if not names:
        return True, "an empty commit"
    for row in names:
        status, path = row.split("\t", 1)
        if status != "M":
            kind = {"A": "added", "D": "deleted"}.get(status[:1], f"status {status}")
            return False, f"{path} is {kind}, not an existing file's change log"
        if not path.lower().endswith(".md"):
            return False, f"{path} is not Markdown"
        if not any(HEADING.match(l) for l in show(clone, approved, path).splitlines()):
            return False, f"{path} had no CHANGE LOG heading in the approved head"
        old_lines = show(clone, parent, path).splitlines()
        new_txt = show(clone, commit, path)
        new_ok, new_lines = changelog_lines(new_txt), new_txt.splitlines()
        diff = git(clone, "diff", "-U0", "--no-renames", parent, commit, "--", path)
        for line in diff.splitlines():
            m = HUNK.match(line)
            if not m:
                continue
            o, oc = int(m.group(1)), int(m.group(2) if m.group(2) is not None else 1)
            n, nc = int(m.group(3)), int(m.group(4) if m.group(4) is not None else 1)
            for k in range(o, o + oc):
                if old_lines[k - 1].strip():
                    return False, f"{path}:{k} removes a line (a change log only adds)"
            for k in range(n, n + nc):
                text = new_lines[k - 1]
                if not text.strip():
                    continue
                if NEXT.match(text):
                    return False, f"{path}:{k} adds a heading ({text.strip()[:40]})"
                if k in new_ok:
                    continue
                return False, f"{path}:{k} lies outside the CHANGE LOG section"
    return True, "change-log lines only"


def clean_base_merge(clone: str, commit: str, parents: list[str], base: str) -> tuple[bool, str]:
    if len(parents) != 2:
        return False, f"a merge of {len(parents)} parents"
    p1, p2 = parents
    if not is_ancestor(clone, p2, base):
        return False, f"its second parent {p2[:12]} is not on the base branch"
    p = subprocess.run(["git", "-C", clone, "merge-tree", "--write-tree", p1, p2], capture_output=True, text=True)
    if p.returncode != 0:
        return False, "the merge has conflicts, so its resolution was made by hand"
    want = p.stdout.splitlines()[0].strip()
    got = git(clone, "rev-parse", f"{commit}^{{tree}}").strip()
    if want != got:
        return False, "the merge's tree differs from the clean merge of its parents (edited inside the merge)"
    return True, "a clean merge of the base branch"


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    clone, approved, current, base = argv
    try:
        approved, current, base = (git(clone, "rev-parse", "--verify", f"{rev}^{{commit}}").strip()
                                   for rev in (approved, current, base))
        if approved == current:
            print('carry[1]{verdict,why}:\n  "carries","the head did not move"')
            return 0
        if not is_ancestor(clone, approved, current):
            print('carry[1]{verdict,why}:\n  "refused","the approved head is not an ancestor of the new head (a rewrite)"')
            return 1
        commits = git(clone, "rev-list", "--reverse", "--topo-order", current, f"^{approved}", f"^{base}").split()
        rows, verdict = [], ("carries", "every commit since the approval is a base merge or change-log lines")
        allowed = {approved, *commits}
        for c in commits:
            parents = git(clone, "rev-list", "--parents", "-n1", c).split()[1:]
            if len(parents) > 1:
                ok, why = clean_base_merge(clone, c, parents, base)
                if ok and parents[0] not in allowed:
                    ok, why = False, "its first parent is not the approved line"
            elif len(parents) == 1:
                ok, why = changelog_only(clone, c, parents[0], approved)
            else:
                ok, why = False, "a root commit"
            rows.append((c[:12], "ok" if ok else "new work", why))
            if not ok:
                verdict = ("refused", f"{c[:12]}: {why} — a new judgement is needed")
                break
    except (RuntimeError, IndexError, ValueError) as exc:
        print(f'carry[1]{{verdict,why}}:\n  "refused","the history cannot be read: {exc}"')
        return 2
    print(f"commits[{len(rows)}]{{commit,kind,why}}:")
    for r in rows:
        print('  "{}","{}","{}"'.format(*[x.replace('"', "'") for x in r]))
    print(f'carry[1]{{verdict,why}}:\n  "{verdict[0]}","{verdict[1]}"')
    return 0 if verdict[0] == "carries" else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
