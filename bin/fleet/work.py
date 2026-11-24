#!/usr/bin/env python3
"""work.py — `ymir work`: the one door to the work road (plan 365).

  ymir work                              where the road runs, the profile per role, lanes, the queue
  ymir work mode [solo|fleet|offline]    read or set where the road runs
  ymir work models                       each role -> harness/model/effort, and whether this machine can serve it
  ymir work models set <role> <model>    change one role (harness follows the model's provider)
  ymir work resolve <role> [--flags] [--avoid-model M]   the one resolver spawn, review and mender call
  ymir work repos [add|rm owner/name]    which repositories intake reads
  ymir work send "<ask>" [--repo R]      an ask becomes a labelled issue (the one way in)
  ymir work intake [--dry-run]           labelled issues enter the queue (a Nornir tick on the heart)
  ymir work dedupe [--apply]             name duplicate open errands dead (rows are kept, never deleted)

ONE config (Rule 07): the dispatch profile `eindri-dispatch.json` gains `mode`, `roles`, `modes` and `merge`.
The home's copy ($YMIR_HOME/hodd/config/) wins over the shipped template. Paid models are never a default.
"""
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROLES = ("triage", "worker", "judge", "mender")
MODES = ("solo", "fleet", "offline")
FREE = {"triage": "opencode/mimo-v2.6-flash-free", "worker": "opencode/deepseek-v4.1-flash-free",
        "judge": "opencode/nemotron-3.5-super-vl-free", "mender": "opencode/deepseek-v4.1-flash-free"}
EFFORT = {"triage": "low", "worker": "medium", "judge": "high", "mender": "medium"}
DEFAULTS = {
    "mode": "solo",
    "roles": {r: {"harness": "opencode", "model": FREE[r], "effort": EFFORT[r]} for r in ROLES},
    "modes": {
        "solo": {"about": "this machine runs the queue, the judge and the merges; heavy-slot lanes"},
        "fleet": {"about": "the heart runs the queue, the judge and the merges; workers on the heart and any seat that offers lanes",
                  "lanes": {"forge": {"harness": "pi", "model": "llama-swap/qwen3.6-35b-a3b@q4_k_xl-mtp", "for": "heavy and local-only work"}}},
        "offline": {"about": "this machine, local models only; the queue is journaled",
                    "roles": {"worker": {"harness": "pi", "model": "llama-swap/qwen3.6-35b-a3b@q4_k_xl-mtp", "effort": "medium"},
                              "mender": {"harness": "pi", "model": "llama-swap/qwen3.6-35b-a3b@q4_k_xl-mtp", "effort": "medium"},
                              "triage": {"harness": "pi", "model": "llama-swap/qwen3.6-35b-a3b@q4_k_xl-mtp", "effort": "low"},
                              "judge": {"harness": "pi", "model": "llama-swap/apodex-1.0-mini", "effort": "high"}}},
    },
    "merge": {"t0": "auto", "t1": "off", "t2": "allfather", "max_mend_rounds": 3},
    "intake": {"label": "ymir:work", "repos": []},
}


def home():
    return os.environ.get("YMIR_HOME") or os.path.expanduser("~/Documents/ymirhome")


def cfg_paths():
    """(read path, write path): the home's copy wins; the shipped template is only a seed."""
    w = os.environ.get("YMIR_WORK_CONFIG") or os.path.join(home(), "hodd", "config", "eindri-dispatch.json")
    return (w if os.path.exists(w) else os.path.join(ROOT, ".agents", "config", "eindri-dispatch.json")), w


def load():
    rp, _ = cfg_paths()
    try:
        return json.load(open(rp))
    except Exception:
        return {"version": 1, "rules": [], "default": []}


def merged(cfg, mode=None):
    """The profile in force: defaults < the file < the mode's own overrides."""
    out = json.loads(json.dumps(DEFAULTS))
    for k in ("mode", "merge", "intake"):
        if k in cfg:
            out[k] = {**out[k], **cfg[k]} if isinstance(out[k], dict) else cfg[k]
    for r, v in (cfg.get("roles") or {}).items():
        out["roles"][r] = {**out["roles"].get(r, {}), **v}
    for m, v in (cfg.get("modes") or {}).items():
        out["modes"][m] = {**out["modes"].get(m, {}), **v}
    mode = mode or os.environ.get("YMIR_WORK_MODE") or out["mode"]
    roles = {r: dict(v) for r, v in out["roles"].items()}
    for r, v in (out["modes"].get(mode, {}).get("roles") or {}).items():
        roles[r] = {**roles.get(r, {}), **v}
    return mode, roles, out


def save(mutate):
    _, wp = cfg_paths()
    cfg = load()
    mutate(cfg)
    os.makedirs(os.path.dirname(wp), exist_ok=True)
    tmp = wp + ".tmp"
    json.dump(cfg, open(tmp, "w"), indent=2)
    open(tmp, "a").write("\n")
    os.replace(tmp, wp)
    return wp


def family(model):
    m = (model or "").rsplit("/", 1)[-1].lower()
    m = re.sub(r"^(nemotron|deepseek|mimo|qwen|claude|gpt|gemma|llama|apodex|kimi|glm|minimax)\b.*", r"\1", m)
    return re.match(r"[a-z]+", m).group(0) if re.match(r"[a-z]+", m) else m


def servable(harness, model):
    """Can THIS machine run it? A harness binary must exist; opencode models are checked against its catalogue."""
    if not shutil.which(harness):
        return False, f"{harness} is not installed here"
    if harness == "opencode":
        try:
            out = subprocess.run(["opencode", "models"], capture_output=True, text=True, timeout=20).stdout
            return (model in out.split()), ("" if model in out.split() else "not in `opencode models`")
        except Exception:
            return True, "catalogue unread"
    return True, ""


def resolve(role, mode=None, avoid=None):
    mode, roles, _ = merged(load(), mode)
    if role not in roles:
        raise SystemExit(f"error: no role '{role}' (roles: {', '.join(ROLES)})")
    r = roles[role]
    if role == "judge":
        worker = avoid or roles["worker"].get("model")
        if family(r.get("model")) == family(worker):
            raise SystemExit(f"refused: the judge ({r.get('model')}) is the worker's model family ({family(worker)}) — "
                             f"the Rule of Two needs another family: ymir work models set judge <model>")
    return r


def queue():
    st = {"open": 0, "review": 0, "other": 0, "dupes": 0}
    bl = os.path.join(home(), "state", "data", "backlog.md")
    for p in (os.environ.get("YMIR_BACKLOG"), os.path.join(os.environ.get("BROKK_DATA_OVERRIDE", ""), "backlog.md"), os.path.join(ROOT, "data", "backlog.md"), bl):
        if p and os.path.exists(p):
            seen = set()
            for ln in open(p):
                f = [c.strip() for c in ln.strip().strip("|").split("|")]
                if len(f) < 4 or f[0] in ("id", "---") or set(f[0]) <= set("-"):
                    continue
                key = (f[0], f[4] if len(f) > 4 else "")
                st["open" if f[2] == "open" or f[3] == "open" else "review" if "review" in f else "other"] += 1
                if key in seen:
                    st["dupes"] += 1
                seen.add(key)
            break
    return st


def cmd_show(_):
    mode, roles, full = merged(load())
    print(f"work[1]{{mode,config,t0,t1,t2}}:\n  \"{mode}\",\"{cfg_paths()[0]}\",\"{full['merge']['t0']}\",\"{full['merge']['t1']}\",\"{full['merge']['t2']}\"")
    print("roles[4]{role,harness,model,effort}:")
    for r in ROLES:
        v = roles[r]
        print(f"  \"{r}\",\"{v.get('harness')}\",\"{v.get('model')}\",\"{v.get('effort', '')}\"")
    lanes = (full["modes"].get(mode, {}).get("lanes") or {})
    for n, v in lanes.items():
        print(f"lane \"{n}\": {v.get('harness')} {v.get('model')} — {v.get('for', '')}")
    rt = os.path.realpath(os.path.expanduser("~/ymir-runtime"))
    if os.path.exists(rt):
        print(f"runtime: {os.path.basename(rt)[:12]} — ymir release status says whether it follows main")
    ans = subprocess.run(["bash", os.path.join(ROOT, "bin", "agents", "answer.sh"), "pending"], capture_output=True, text=True).stdout.strip()
    if ans:
        print("answers:\n" + "\n".join("  " + x for x in ans.splitlines()))
    q = queue()
    print(f"queue: open {q['open']} · review {q['review']} · duplicates {q['dupes']}")
    sv = os.path.join(home(), "state", "research-saving.jsonl")
    if os.path.exists(sv):
        t = [json.loads(x) for x in open(sv) if x.strip()]
        hits = sum(1 for x in t if x.get("cache") == "hit")
        print(f"research: {len(t)} calls · {hits} kept answers reused · {sum(x.get('tokens_in', 0) for x in t)} tokens in / {sum(x.get('tokens_out', 0) for x in t)} out")
    return 0


def cmd_mode(a):
    if not a:
        print(merged(load())[0])
        return 0
    if a[0] not in MODES:
        print(f"error: mode is one of {', '.join(MODES)}", file=sys.stderr)
        return 2
    p = save(lambda c: c.__setitem__("mode", a[0]))
    print(f"mode: {a[0]}  ({p})")
    return 0


def cmd_models(a):
    if a[:1] == ["set"]:
        if len(a) != 3 or a[1] not in ROLES:
            print(f"usage: ymir work models set <{'|'.join(ROLES)}> <provider/model>", file=sys.stderr)
            return 2
        role, model = a[1], a[2]
        harness = "opencode" if model.startswith("opencode") else "pi" if "/" in model else "claude"
        if harness == "claude":
            print("refused: a paid Claude model is opt-in per errand, never a role default", file=sys.stderr)
            return 1
        if role == "judge" and family(model) == family(merged(load())[1]["worker"].get("model")):
            print("refused: the judge may not share the worker's model family (Rule of Two)", file=sys.stderr)
            return 1
        p = save(lambda c: c.setdefault("roles", {}).__setitem__(role, {"harness": harness, "model": model, "effort": EFFORT[role]}))
        print(f"{role}: {harness} {model}  ({p})")
        return 0
    mode, roles, _ = merged(load())
    print(f"models[4]{{role,harness,model,effort,servable_here}}:   # mode {mode}")
    for r in ROLES:
        v = roles[r]
        ok, why = servable(v.get("harness", ""), v.get("model", ""))
        print(f"  \"{r}\",\"{v.get('harness')}\",\"{v.get('model')}\",\"{v.get('effort', '')}\",\"{'yes' if ok else 'no — ' + why}\"")
    return 0


def cmd_resolve(a):
    role = a[0] if a else ""
    avoid = a[a.index("--avoid-model") + 1] if "--avoid-model" in a else None
    if "--explicit-only" in a and not load().get("roles"):
        return 4  # no chosen profile: the home's agents.yaml keeps naming this role
    r = resolve(role, avoid=avoid)
    if "--flags" in a:
        print(f"--harness {r['harness']} --model {r['model']} --effort {r.get('effort', 'medium')}")
    else:
        print(f"{r['harness']}\t{r['model']}\t{r.get('effort', 'medium')}")
    return 0


def gh(*args):
    return subprocess.run(["gh", *args], capture_output=True, text=True)


def cmd_send(a):
    repo = a[a.index("--repo") + 1] if "--repo" in a else None
    words = [x for i, x in enumerate(a) if x != "--repo" and (i == 0 or a[i - 1] != "--repo")]
    if not words:
        print('usage: ymir work send "<ask>" [--repo owner/name]', file=sys.stderr)
        return 2
    ask = " ".join(words)
    if not repo:
        repo = gh("repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner").stdout.strip()
    label = merged(load())[2]["intake"]["label"]
    # R1: the sender's own address rides in the issue, so the answer finds its way back (the issue itself is the fallback)
    me = subprocess.run(["bash", os.path.join(ROOT, "bin", "agents", "reply-to.sh"), "resolve"], capture_output=True, text=True).stdout.strip()
    if me:
        ask += f"\n\nReply-to: {me}"
    gh("label", "create", label, "--repo", repo, "--color", "C9974F", "--description", "work for the Ymir work road")
    r = gh("issue", "create", "--repo", repo, "--title", ask.splitlines()[0][:80], "--body", ask, "--label", label)
    print(r.stdout.strip() or r.stderr.strip())
    return r.returncode


def registry_repos(mode):
    """The repositories intake reads, derived from the project registry in the home (plan 345, never named in code):
    every project with a GitHub remote. Solo and offline read only the repos CLONED on this machine; fleet reads the
    whole registry. A repo is in the road by having an issue labelled `ymir:work`, nothing else."""
    path = os.path.join(home(), "hodd", "identity", "projects.yaml")
    try:
        import yaml
        projects = (yaml.safe_load(open(path)) or {}).get("projects") or []
    except Exception:
        return []
    out = []
    for pr in projects:
        g = pr.get("git") or {}
        if g.get("host") != "github.com" or not g.get("owner") or not g.get("repo"):
            continue
        if mode != "fleet":
            d = os.path.join(os.path.expanduser("~"), pr.get("repo") or "")
            if pr.get("repo") not in (".",) and not os.path.isdir(os.path.join(d, ".git")) and not os.path.isfile(os.path.join(d, ".git")):
                continue
        out.append(f"{g['owner']}/{g['repo']}")
    return sorted(set(out))


def cmd_intake(a):
    dry = "--dry-run" in a
    _, roles, full = merged(load())
    mode = merged(load())[0]
    label = full["intake"]["label"]
    repos = sorted(set((full["intake"].get("repos") or []) + registry_repos(mode)))
    if not repos:
        print("intake: no repositories — none cloned here and none named (the registry is hodd/identity/projects.yaml)")
        return 0
    claim = os.path.join(ROOT, "bin", "agents", "claim.sh")
    flags = f"--harness {roles['worker']['harness']} --model {roles['worker']['model']} --effort {roles['worker'].get('effort', 'medium')}".split()
    for repo in repos:
        r = gh("issue", "list", "--repo", repo, "--label", label, "--state", "open", "--json", "number,title,labels")
        try:
            issues = json.loads(r.stdout or "[]")
        except Exception:
            print(f"intake: {repo}: could not read issues ({r.stderr.strip()[:80]})")
            continue
        for it in issues:
            n, key = it["number"], f"issue:{repo}#{it['number']}"
            if any(x["name"] == "ymir:picked" for x in it.get("labels", [])):
                continue
            if dry:
                print(f"would pick {key} — {it['title'][:60]}")
                continue
            c = subprocess.run(["bash", claim, "take", key, "--role", "worker", "--errand", f"work-{repo.split('/')[-1]}-{n}"], capture_output=True, text=True)
            if c.returncode != 0:
                print(f"held {key} — {c.stdout.strip() or c.stderr.strip()}")
                continue
            gh("label", "create", "ymir:picked", "--repo", repo, "--color", "6B6250")
            gh("issue", "edit", str(n), "--repo", repo, "--add-label", "ymir:picked")
            m = subprocess.run(["bash", os.path.join(ROOT, "bin", "forge", "mjollnir.sh"), "run", "--project", repo.split("/")[-1],
                                "--issue", str(n), *flags], capture_output=True, text=True,
                               env=dict(os.environ, YMIR_REPLY_TO=f"issue:{repo}#{n}"))
            print(f"picked {key} → mjollnir rc={m.returncode} {(m.stdout or m.stderr).strip().splitlines()[-1:] }")
    return 0


def cmd_dedupe(a):
    apply = "--apply" in a
    bl = os.environ.get("YMIR_BACKLOG") or os.path.join(os.environ.get("BROKK_DATA_OVERRIDE") or os.path.join(ROOT, "data"), "backlog.md")
    if not os.path.exists(bl):
        print(f"dedupe: no backlog at {bl}")
        return 0
    seen, out, n = set(), [], 0
    for ln in open(bl).read().splitlines():
        f = [c.strip() for c in ln.strip().strip("|").split("|")]
        if len(f) >= 5 and f[0] not in ("id", "") and not set(f[0]) <= set("-"):
            key = (f[0], f[4])
            if key in seen and f[3] == "open":
                ln = "| " + " | ".join([f[0], f[1], f[2], "dead", "duplicate of the first row with this id and title — named dead by `ymir work dedupe`"]) + " |"
                n += 1
            seen.add(key)
        out.append(ln)
    print(f"dedupe: {n} duplicate open row(s) {'named dead' if apply else 'found (add --apply to name them dead; rows are kept)'}")
    if apply and n:
        open(bl, "w").write("\n".join(out) + "\n")
    return 0


def cmd_init(a):
    """Ask the two questions once (install): where the road runs, and which models. Defaults: solo, free models."""
    if load().get("mode"):
        print(f"work: already chosen — mode {load()['mode']} (ymir work mode / ymir work models to change)")
        return 0
    mode, profile = "solo", "free"
    if sys.stdin.isatty() and sys.stdout.isatty() and "--yes" not in a:
        print("Where should the work road run?\n  solo     this machine does everything (default)\n  fleet    a heart machine runs it for the house\n  offline  this machine, local models only")
        got = input("mode [solo]: ").strip().lower()
        mode = got if got in MODES else "solo"
        print("Which models?\n  free     free hosted models through opencode (default; no key needed)\n  local    local models through pi (needs a local rail)")
        got = input("models [free]: ").strip().lower()
        profile = got if got in ("free", "local") else "free"

    def put(c):
        c["mode"] = mode
        if profile == "local" or mode == "offline":
            c["roles"] = {r: dict(DEFAULTS["modes"]["offline"]["roles"][r]) for r in ROLES}
    p = save(put)
    print(f"work: mode {mode}, models {'local' if profile == 'local' or mode == 'offline' else 'free'}  ({p})")
    return 0


def cmd_repos(a):
    """Extra repositories intake reads beyond the registry: `repos`, `repos add owner/name`, `repos rm owner/name`.
    `repos --all` lists what intake reads now (the registry's repos for this mode, plus the extras)."""
    if a[:1] == ["--all"]:
        m, _, full = merged(load())
        print("\n".join(sorted(set((full["intake"].get("repos") or []) + registry_repos(m)))) or "none")
        return 0
    cur = list(merged(load())[2]["intake"].get("repos") or [])
    if len(a) == 2 and a[0] in ("add", "rm"):
        new = sorted(set(cur + [a[1]])) if a[0] == "add" else [x for x in cur if x != a[1]]
        save(lambda c: c.setdefault("intake", {}).__setitem__("repos", new))
        cur = new
    print("intake repos: " + (", ".join(cur) or "none"))
    return 0


def main():
    a = sys.argv[1:]
    verbs = {"repos": cmd_repos, "init": cmd_init, "mode": cmd_mode, "models": cmd_models, "resolve": cmd_resolve, "send": cmd_send, "intake": cmd_intake, "dedupe": cmd_dedupe}
    if not a:
        return cmd_show([])
    if a[0] in verbs:
        return verbs[a[0]](a[1:])
    print(__doc__)
    return 0 if a[0] in ("-h", "--help", "help") else 2


if __name__ == "__main__":
    sys.exit(main())
