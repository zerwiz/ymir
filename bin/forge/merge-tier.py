#!/usr/bin/env python3
"""merge-tier.py — which merge tier does a pull request fall in? (plan 365 phase 4, plan 338)

  merge-tier.py <n> --repo owner/name        read the PR's files from GitHub
  merge-tier.py --files a.md b.md [--deleted x]   classify a list (tests)

Prints `T0|T1|T2<TAB>reason<TAB>act` where act is `merge` (arm the merge) or `wait` (the Allfather seals).
  T0  documents and fix notes only, or a lock-file bump          merges by itself once the judge approves and checks are green
  T1  ordinary code and tests                                    merges by itself ONLY when config merge.t1 is "auto" (default off)
  T2  rules, config, gates, secrets, identity, releases, deletions  always waits for the Allfather
The switches live in the one dispatch config (`ymir work`), never here.
"""
import json
import os
import re
import subprocess
import sys

T2 = [r"^RULES/", r"^\.agents/config/", r"^\.agents/migrations/", r"^bin/gates/", r"^\.github/", r"(^|/)\.env", r"secret",
      r"^AGENTS\.md$", r"^CLAUDE\.md$", r"^package\.json$", r"^bin/engine/release", r"^bin/engine/npm", r"^hodd/", r"identity"]
T0 = [r"^docs/.*\.md$", r"^package-lock\.json$", r"^[^/]+\.md$"]


def tier(files, deleted=()):
    for f in list(files) + list(deleted):
        for pat in T2:
            if re.search(pat, f, re.I):
                return "T2", f"{f} is a rule, config, gate, secret, identity or release path"
    if deleted:
        return "T2", f"deletes {deleted[0]}"
    if files and all(any(re.search(p, f) for p in T0) for f in files):
        return "T0", "documents, fix notes or a lock file only"
    return "T1", "ordinary code or tests"


def switches():
    cfg = {}
    for p in (os.environ.get("YMIR_WORK_CONFIG"), os.path.join(os.environ.get("YMIR_HOME") or os.path.expanduser("~/Documents/ymirhome"),
                                                                "hodd", "config", "eindri-dispatch.json")):
        if p and os.path.exists(p):
            try:
                cfg = json.load(open(p)).get("merge", {})
            except Exception:
                pass
            break
    return {"t0": "auto", "t1": "off", **cfg}


def main(a):
    if "--files" in a:
        i = a.index("--files")
        dels = a[a.index("--deleted") + 1:] if "--deleted" in a else []
        files = [x for x in a[i + 1:] if x != "--deleted" and x not in dels]
    else:
        n = a[0]
        repo = a[a.index("--repo") + 1] if "--repo" in a else ""
        r = subprocess.run(["gh", "pr", "view", n, *(["--repo", repo] if repo else []), "--json", "files"], capture_output=True, text=True)
        try:
            fl = json.loads(r.stdout)["files"]
        except Exception:
            print("T2\tcould not read the PR's files\twait")
            return 0
        files = [f["path"] for f in fl if not (f["additions"] == 0 and f["deletions"] > 0)]
        dels = [f["path"] for f in fl if f["additions"] == 0 and f["deletions"] > 0]
    t, why = tier(files, dels)
    sw = switches()
    act = "wait" if t == "T2" or (t == "T0" and sw["t0"] != "auto") or (t == "T1" and sw["t1"] != "auto") else "merge"
    print(f"{t}\t{why}\t{act}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
