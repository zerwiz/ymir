"""landed.py — did this work LAND? The teardown gate, owned by the engine.

Discarding a worktree destroys unlanded work, so the gate that says yes or no
must be one implementation, and it must FAIL SAFE: a lookup that errors, a
default branch it cannot resolve, or a merge it cannot compute is a REFUSAL, not
a guess. The vendored teardown (`fm-teardown.sh`) carried this judgement in
shell — reachability, the merged-PR proof, and the content-in-default fallback —
and plan 58, Phase 5 moves it here, behind `stop --require-landed`, so the
lifecycle verb can never silently discard work.

What "landed" means, in the order the gate proves it:

    remote            HEAD is reachable from some remote-tracking ref (a fork
                      counts as a remote: an upstream-contribution PR pushed to
                      a fork satisfies this)
    merged-pr         the PR is MERGED and its head contains the current local
                      work — the exact commit, or the same patches replayed
                      (the squash-merge-then-delete-branch flow, where the
                      branch's commits live nowhere on a remote)
    content-in-default  a 3-way merge of the up-to-date default branch with HEAD
                      introduces nothing the default branch lacks — the change
                      is already there (also the no-PR and gh-error fallback)
    local-default     local-only mode: the commits are on the local default branch
    unlanded          none of the above: refuse, and say why
    inconclusive      a proof errored: refuse, and say which one

The git and gh argv are the vendored gate's own, so a shell door may be
repointed onto this module without changing a single call's meaning.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Sequence

from . import proc

LANDED = "landed"
UNLANDED = "unlanded"
INCONCLUSIVE = "inconclusive"

_PULL = re.compile(r"/pull/(\d+)")


@dataclass(frozen=True)
class Landed:
    """The verdict: may this work be discarded, and on what proof."""

    landed: bool
    how: str
    detail: str


def _git(
    worktree: str | Path,
    args: Sequence[str],
    *,
    runner: proc.Runner = proc.run,
    env: Mapping[str, str] | None = None,
) -> proc.Completed:
    return runner(["git", "-C", str(worktree), *args], env=dict(env) if env is not None else None)


def dirty(
    worktree: str | Path, *, runner: proc.Runner = proc.run, env: Mapping[str, str] | None = None
) -> bool | None:
    """Uncommitted changes? None when the worktree cannot be inspected."""
    result = _git(worktree, ["status", "--porcelain"], runner=runner, env=env)
    if not proc.ok(result):
        return None
    ignored = ("?? .claude/", "?? .fm-grok-turnend", "?? .fm-kimi-turnend")
    lines = [line for line in (result.stdout or "").splitlines() if line and line not in ignored]
    return bool(lines)


def commits_not_on_remote(
    worktree: str | Path, *, runner: proc.Runner = proc.run, env: Mapping[str, str] | None = None
) -> list[str] | None:
    """HEAD commits reachable from no remote-tracking ref; None when uninspectable."""
    result = _git(worktree, ["log", "--oneline", "HEAD", "--not", "--remotes", "--"], runner=runner, env=env)
    if not proc.ok(result):
        return None
    return [line for line in (result.stdout or "").splitlines() if line.strip()]


def default_branch(
    worktree: str | Path, *, runner: proc.Runner = proc.run, env: Mapping[str, str] | None = None
) -> str:
    """`origin/HEAD` first, then main, then master — the vendored gate's own order."""
    symbolic = _git(worktree, ["symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"], runner=runner, env=env)
    ref = proc.out(symbolic)
    if ref.startswith("origin/"):
        return ref[len("origin/") :]
    for branch in ("main", "master"):
        present = _git(worktree, ["show-ref", "--verify", "--quiet", f"refs/heads/{branch}"], runner=runner, env=env)
        if proc.ok(present):
            return branch
    return ""


def branch_of(
    worktree: str | Path, *, runner: proc.Runner = proc.run, env: Mapping[str, str] | None = None
) -> str:
    return proc.out(_git(worktree, ["rev-parse", "--abbrev-ref", "HEAD"], runner=runner, env=env)) or "HEAD"


def pr_number_from_target(target: str) -> str:
    """A PR number out of a URL, a `<n>` target, or "" when the shape is neither."""
    match = _PULL.search(target or "")
    if match:
        return match.group(1)
    return (target or "").split("!", 1)[0] if (target or "").isdigit() else ""


def patch_id_for_commit(
    worktree: str | Path,
    commit: str,
    *,
    runner: proc.Runner = proc.run,
    env: Mapping[str, str] | None = None,
) -> str:
    """`git patch-id --stable` of one commit — the patch, not the commit id."""
    shown = _git(worktree, ["show", "--pretty=medium", "--no-ext-diff", commit], runner=runner, env=env)
    if not proc.ok(shown):
        return ""
    identified = runner(
        ["git", "patch-id", "--stable"],
        cwd=str(worktree),
        env=dict(env) if env is not None else None,
        input_text=shown.stdout or "",
    )
    if not proc.ok(identified):
        return ""
    first = (identified.stdout or "").strip().splitlines()
    return first[0].split()[0] if first and first[0].split() else ""


def unpushed_patches_are_in_pr_head(
    worktree: str | Path,
    head: str,
    *,
    runner: proc.Runner = proc.run,
    env: Mapping[str, str] | None = None,
) -> bool:
    """Is every unpushed local patch also in the PR head, by patch id?"""
    current = proc.out(_git(worktree, ["rev-parse", "--verify", "HEAD"], runner=runner, env=env))
    base = proc.out(_git(worktree, ["merge-base", current, head], runner=runner, env=env)) if current else ""
    if not base:
        return False
    log = _git(worktree, ["log", "--format=%H", f"{base}..{head}", "--"], runner=runner, env=env)
    if not proc.ok(log):
        return False
    pr_patches = {
        patch
        for patch in (patch_id_for_commit(worktree, commit, runner=runner, env=env) for commit in _lines(log.stdout))
        if patch
    }
    if not pr_patches:
        return False
    unpushed = commits_of(_git(worktree, ["log", "--format=%H", "HEAD", "--not", "--remotes", "--"], runner=runner, env=env))
    if not unpushed:
        return False
    for commit in unpushed:
        patch = patch_id_for_commit(worktree, commit, runner=runner, env=env)
        if not patch or patch not in pr_patches:
            return False
    return True


def _lines(text: str | None) -> list[str]:
    return [line.strip() for line in (text or "").splitlines() if line.strip()]


def commits_of(result: proc.Completed) -> list[str]:
    return _lines(result.stdout) if proc.ok(result) else []


def pr_is_merged(
    worktree: str | Path,
    branch: str,
    pr_url: str = "",
    *,
    runner: proc.Runner = proc.run,
    env: Mapping[str, str] | None = None,
) -> Landed:
    """Is the branch's PR MERGED with the current local work inside its head?

    Resolved from the recorded `pr=` first, then by branch. Any gh failure, a
    non-merged state, or a head that does not contain the local work returns
    `unlanded`/`inconclusive` — never a guess.
    """
    target = pr_url
    if not target:
        listed = runner(["gh-axi", "pr", "list", "--state", "all", "--head", branch, "--limit", "1"], cwd=str(worktree), env=dict(env) if env is not None else None)
        if not proc.ok(listed):
            return Landed(False, INCONCLUSIVE, "no PR is recorded and the branch lookup failed")
        numbers = [line.split(",")[0].strip() for line in _lines(listed.stdout)]
        target = next((number for number in numbers if number.isdigit()), "")
    if not target:
        return Landed(False, UNLANDED, "no PR found for the branch")
    viewed = runner(
        ["gh", "pr", "view", target, "--json", "state,headRefOid,url", "-q", '.state + "\t" + .headRefOid + "\t" + .url'],
        cwd=str(worktree),
        env=dict(env) if env is not None else None,
    )
    if not proc.ok(viewed):
        return Landed(False, INCONCLUSIVE, f"gh could not read PR {target}")
    parts = (viewed.stdout or "").strip().split("\t")
    if len(parts) < 3:
        return Landed(False, INCONCLUSIVE, f"gh returned an unreadable row for PR {target}")
    state, head, url = (part.strip() for part in parts[:3])
    if state.upper() != "MERGED":
        return Landed(False, UNLANDED, f"PR {target} is {state or 'unknown'}, not MERGED")
    if not head:
        return Landed(False, INCONCLUSIVE, f"PR {target} reported no head")
    if not ensure_commit_object(worktree, target, head, runner=runner, env=env):
        return Landed(False, INCONCLUSIVE, f"PR {target}'s head {head[:10]} is not a local object")
    current = proc.out(_git(worktree, ["rev-parse", "--verify", "HEAD"], runner=runner, env=env))
    if current:
        ancestor = _git(worktree, ["merge-base", "--is-ancestor", current, head], runner=runner, env=env)
        if proc.ok(ancestor):
            return Landed(True, "merged-pr", f"PR {target} is merged and contains HEAD ({url or target})")
    if unpushed_patches_are_in_pr_head(worktree, head, runner=runner, env=env):
        return Landed(True, "merged-pr", f"PR {target} is merged and every unpushed patch is in its head")
    return Landed(False, UNLANDED, f"PR {target} is merged but does not contain the current local work")


def ensure_commit_object(
    worktree: str | Path,
    target: str,
    commit: str,
    *,
    runner: proc.Runner = proc.run,
    env: Mapping[str, str] | None = None,
) -> bool:
    """Is `commit` a local object? Fetch `refs/pull/<n>/head` once if it is not."""
    present = _git(worktree, ["cat-file", "-e", f"{commit}^{{commit}}"], runner=runner, env=env)
    if proc.ok(present):
        return True
    number = pr_number_from_target(target)
    if not number:
        return False
    if not proc.ok(_git(worktree, ["remote", "get-url", "origin"], runner=runner, env=env)):
        return False
    _git(worktree, ["fetch", "--quiet", "origin", f"refs/pull/{number}/head"], runner=runner, env=env)
    return proc.ok(_git(worktree, ["cat-file", "-e", f"{commit}^{{commit}}"], runner=runner, env=env))


def content_in_default(
    worktree: str | Path,
    *,
    runner: proc.Runner = proc.run,
    env: Mapping[str, str] | None = None,
) -> Landed:
    """Is the branch's content already in the up-to-date default branch?

    Fetch first, then 3-way merge: when HEAD introduces nothing the default branch
    does not already contain (a squash merge), the merged tree EQUALS the default
    tree. Inconclusive counts as a refusal — never a discard.
    """
    name = default_branch(worktree, runner=runner, env=env)
    if not name:
        return Landed(False, INCONCLUSIVE, "the default branch could not be resolved")
    if proc.ok(_git(worktree, ["remote", "get-url", "origin"], runner=runner, env=env)):
        fetched = _git(worktree, ["fetch", "--quiet", "origin", f"+refs/heads/{name}:refs/remotes/origin/{name}"], runner=runner, env=env)
        if not proc.ok(fetched):
            return Landed(False, INCONCLUSIVE, f"could not fetch origin/{name}")
        ref = f"refs/remotes/origin/{name}"
    else:
        present = _git(worktree, ["rev-parse", "--quiet", "--verify", f"refs/heads/{name}"], runner=runner, env=env)
        if not proc.ok(present):
            return Landed(False, INCONCLUSIVE, f"neither origin/{name} nor a local {name} exists")
        ref = f"refs/heads/{name}"
    default_tree = proc.out(_git(worktree, ["rev-parse", "--quiet", "--verify", f"{ref}^{{tree}}"], runner=runner, env=env))
    if not default_tree:
        return Landed(False, INCONCLUSIVE, f"{ref} has no tree")
    merged = _git(worktree, ["merge-tree", "--write-tree", ref, "HEAD"], runner=runner, env=env)
    if not proc.ok(merged):
        return Landed(False, INCONCLUSIVE, "the default branch and HEAD do not merge cleanly")
    merged_tree = _lines(merged.stdout)[0] if _lines(merged.stdout) else ""
    if merged_tree and merged_tree == default_tree:
        return Landed(True, "content-in-default", f"HEAD introduces nothing {name} lacks")
    return Landed(False, UNLANDED, f"HEAD still introduces content {name} lacks")


def work_is_landed(
    worktree: str | Path,
    branch: str = "",
    pr_url: str = "",
    *,
    runner: proc.Runner = proc.run,
    env: Mapping[str, str] | None = None,
) -> Landed:
    """The whole proof: remote reachability, then the merged PR, then the content."""
    on_remote = commits_not_on_remote(worktree, runner=runner, env=env)
    if on_remote is None:
        return Landed(False, INCONCLUSIVE, "the worktree could not be inspected for remote reachability")
    if not on_remote:
        return Landed(True, "remote", "HEAD is reachable from a remote-tracking ref")
    merged = pr_is_merged(worktree, branch or branch_of(worktree, runner=runner, env=env), pr_url, runner=runner, env=env)
    if merged.landed:
        return merged
    content = content_in_default(worktree, runner=runner, env=env)
    if content.landed:
        return content
    if merged.how == INCONCLUSIVE:
        return merged
    return content


def gate(
    worktree: str | Path,
    *,
    branch: str = "",
    pr_url: str = "",
    mode: str = "",
    force: bool = False,
    runner: proc.Runner = proc.run,
    env: Mapping[str, str] | None = None,
) -> Landed:
    """The teardown gate as a whole: clean, landed, or refused by name.

    `--force` is the approved-discard path and short-circuits; everything else
    refuses on any doubt, because the next step removes the worktree.
    """
    if force:
        return Landed(True, "forced", "the caller asked to discard this work")
    if not Path(worktree).is_dir():
        return Landed(True, "absent", "there is no worktree to guard")
    unclean = dirty(worktree, runner=runner, env=env)
    if unclean is None:
        return Landed(False, INCONCLUSIVE, "the worktree could not be inspected for uncommitted changes")
    if unclean:
        return Landed(False, "dirty", "the worktree holds uncommitted changes")
    unpushed = commits_not_on_remote(worktree, runner=runner, env=env)
    if unpushed is None:
        return Landed(False, INCONCLUSIVE, "the worktree could not be inspected for commits not on a remote")
    if not unpushed:
        return Landed(True, "remote", "HEAD is reachable from a remote-tracking ref")
    if mode == "local-only":
        name = default_branch(worktree, runner=runner, env=env)
        if not name:
            return Landed(False, INCONCLUSIVE, "the default branch could not be resolved for a local-only seat")
        unmerged = _git(worktree, ["log", "--oneline", "HEAD", "--not", name, "--"], runner=runner, env=env)
        if not proc.ok(unmerged):
            return Landed(False, INCONCLUSIVE, f"the worktree could not be inspected for commits not on {name}")
        if not _lines(unmerged.stdout):
            return Landed(True, "local-default", f"the commits are on the local {name}")
        return Landed(False, UNLANDED, f"local-only work is not merged into {name} and is on no remote")
    return work_is_landed(worktree, branch, pr_url, runner=runner, env=env)
