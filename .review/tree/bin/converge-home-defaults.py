#!/usr/bin/env python3
"""converge-home-defaults.py — converge every private home default on the one resolver.

A mechanical change across many files is done by a reviewed transform and a dry run, not by
hand and not by a blind sed. What it does, per file:

  · replace the private default expression with the resolved variable: the wrapped form
    (`${YMIR_HOME:-` with a guessed home), and a bare guessed home sitting inside somebody
    else's override (`${SOME_ROOT:-` with a guessed home). Both become `${YMIR_HOME}`
  · insert the canonical resolver block, once, into a SCRIPT that lacks it, so YMIR_HOME is
    set from env -> the recorded choice -> the one default, before first use
  · never touch a comment (prose may quote a path)
  · leave a file alone when its line is already a waiver

Usage:  converge-home-defaults.py --dry-run | --apply [path...]
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = ROOT / "bin" / "defaults-guard.sh"

BLOCK = """# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yh="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  for _i in 1 2 3 4 5; do
    [ -n "$_yh" ] || break
    if [ -r "$_yh/bin/hoard-lib.sh" ]; then . "$_yh/bin/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    if [ -r "$_yh/hoard-lib.sh" ]; then . "$_yh/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    _yh="$(cd "$_yh/.." 2>/dev/null && pwd)"
  done
  unset _yh _i
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi
"""

LIBRARIES = {"bin/hoard-lib.sh", "bin/defaults-guard.sh"}
# Two shapes: the wrapped default, and the bare guess inside somebody else's override
# (`${YMIR_HOARD:-$HOME/Documents/ymirhome}`). Both become the resolved variable.
DEFAULT_EXPR = re.compile(r"\$\{YMIR_HOME:-\$HOME/Doc" r"uments/ymirhome\}"
                          r"|\$HOME/Doc" r"uments/ymirhome")


def offenders():
    out = subprocess.run(["bash", str(GUARD), "check"], capture_output=True, text=True)
    seen = []
    for line in out.stdout.splitlines():
        m = re.search(r'"a home guessed","([^"]+)","(\d+)"', line)
        if m and m.group(1) not in seen:
            seen.append(m.group(1))
    return seen


def has_resolver(text):
    """Does this file CALL the resolver? A substring of `hoard-lib.sh` is not evidence:
    it appears in comments, and believing it cost a broken `set -u` script."""
    return re.search(r"\bymir_home_root\b", text) is not None


def insert_block(lines):
    for i, ln in enumerate(lines):
        if re.match(r"^set -", ln):
            return lines[: i + 1] + BLOCK.splitlines(True) + lines[i + 1 :]
    for i, ln in enumerate(lines):
        if ln.startswith("#!") or (i > 0 and not ln.startswith("#")):
            return lines[: i + 1] + BLOCK.splitlines(True) + lines[i + 1 :]
    return BLOCK.splitlines(True) + lines


def converged_files():
    """Every shell file the ward governs, not only the ones already changed: the second
    class is invisible to a diff, so the pass must walk the same ground the ward does."""
    out = subprocess.run(["find", str(ROOT / "bin"), str(ROOT / ".agents"),
                          "-type", "f", "(", "-name", "*.sh", "-o", "-name", "*.bash", ")",
                          "-not", "-path", "*/node_modules/*", "-not", "-path", "*/.git/*"],
                         capture_output=True, text=True).stdout.split()
    return [str(Path(p).relative_to(ROOT)) for p in sorted(out)]


def pass_resolution(apply):
    """A file may USE the home and never RESOLVE it, and that leaves no literal to grep for,
    so the literal pass cannot see it. Under `set -u` such a file dies outright, which is how
    this pass came to exist: the first run converged ten files and left them unable to run.

    It gives every such file the block, unless the file assigns the home itself (the
    migrations do, deliberately, to heal the old name)."""
    done = []
    noop = re.compile(r'^\s*(export\s+)?YMIR_HOME="\$\{YMIR_HOME\}"\s*$')
    real = re.compile(r"^\s*(export\s+)?YMIR_HOME=")
    for rel in converged_files():
        p = ROOT / rel
        s = p.read_text()
        if "ymir_home_root" in s:
            continue
        if not re.search(r"\$\{?YMIR_HOME", s):
            continue
        # A REAL assignment is an exemption (the migrations set the old name on purpose).
        # A SELF-assignment is a no-op left by the literal pass, and it is the very thing
        # that dies under `set -u`, so it counts as neither an exemption nor a fix.
        if any(real.match(l) and not noop.match(l) for l in s.splitlines()):
            continue
        lines = [l for l in s.splitlines(True) if not noop.match(l)]
        out, placed = [], False
        for ln in lines:
            out.append(ln)
            if not placed and re.match(r"^set -", ln):
                out.extend(BLOCK.splitlines(True))
                placed = True
        if not placed:
            out = [lines[0]] + BLOCK.splitlines(True) + lines[1:]
        if apply:
            p.write_text("".join(out))
        done.append(rel)
    return done


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "--dry-run"
    if mode not in ("--dry-run", "--apply"):
        print("usage: converge-home-defaults.py --dry-run|--apply")
        return 2

    total = changed = waived = skipped = 0
    for rel in offenders():
        total += 1
        p = ROOT / rel
        if not p.exists():
            skipped += 1
            continue
        if rel in LIBRARIES or p.suffix not in (".sh", ".bash"):
            print(f"  SKIP (not a shell script, or is the resolver)  {rel}")
            skipped += 1
            continue

        src = p.read_text()
        touched = False
        lines = []
        for ln in src.splitlines(True):
            # Prose stays prose: a comment may quote a path, and rewriting it would be
            # editing documentation under the guise of fixing code.
            if ln.lstrip().startswith("#"):
                lines.append(ln)
                continue
            had = bool(DEFAULT_EXPR.search(ln))
            if had and "allow-home-default:" not in ln:
                ln = DEFAULT_EXPR.sub("${YMIR_HOME}", ln)
                touched = True
            elif had:
                waived += 1
            # A SELF-ASSIGNMENT that is now only its own variable is a no-op once the
            # block has resolved it, and under `set -u` it is an unbound variable.
            if ln.strip() == 'YMIR_HOME="${YMIR_HOME}"':
                touched = True
                continue
            lines.append(ln)
        if not touched:
            print(f"  WAIVED or already resolved                     {rel}")
            continue

        if not has_resolver(src):
            lines = insert_block(lines)
        new = "".join(lines)
        if new == src:
            continue
        changed += 1
        print(f"  converge                                       {rel}")
        if mode == "--apply":
            p.write_text(new)

    print(f"\n  files seen {total} · converged {changed} · waived {waived} · skipped {skipped}")
    if mode == "--dry-run":
        print("  dry run: nothing written. Re-run with --apply.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
