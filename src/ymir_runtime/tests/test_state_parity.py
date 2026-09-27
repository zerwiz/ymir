"""state/ PARITY — the shim against the shell it replaced, byte for byte.

This is the proof the errand rests on: a lock cycle, a rune append, and a queue
op each produce EXACTLY the same outcome through `bin/gleipnir-lock-lib.sh` /
`bin/runes-append.sh` / `bin/brokk-wake-lib.sh` as through the implementation
they replaced. The old shell is kept (verbatim) under
`tests/fixtures/state/`, and the old queue algorithm is re-stated verbatim in
the test as the oracle, so the comparison is against the real predecessor,
never a paraphrase.

A mismatch here is a REFUSAL: the ledger's history and the harness's lock reads
must not move.
"""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
FIXTURES = REPO / "src" / "ymir_runtime" / "tests" / "fixtures" / "state"
LEGACY_LOCK = FIXTURES / "gleipnir-lock-lib.legacy.sh"
SHIM_LOCK = REPO / "bin" / "gleipnir-lock-lib.sh"
LEGACY_RUNES = FIXTURES / "runes-append.legacy.sh"
SHIM_RUNES = REPO / "bin" / "runes-append.sh"
SHIM_WAKE = REPO / "bin" / "brokk-wake-lib.sh"

FIXED_EPOCH = "1700000000"
FIXED_STAMP = "2026-01-02T03:04:05Z"


def _base_env(work: Path, **extra: str) -> dict[str, str]:
    env = {
        "PATH": f"{work / 'fakebin'}:{os.environ.get('PATH', '/usr/bin:/bin')}",
        "HOME": str(work / "home"),
        "BROKK_STATE_OVERRIDE": str(work / "state"),
        "BROKK_MACHINE_STATE_DIR": str(work / "machine"),
        "BROKK_RUNES_TIMESTAMP": FIXED_STAMP,
    }
    env.update(extra)
    return env


def _fake_date(work: Path) -> None:
    fakebin = work / "fakebin"
    fakebin.mkdir(parents=True, exist_ok=True)
    script = fakebin / "date"
    script.write_text(
        "#!/usr/bin/env bash\n"
        "if [ \"${1-}\" = \"-u\" ] && [ \"${2-}\" = \"+%Y-%m-%dT%H:%M:%SZ\" ]; then\n"
        f"  printf '%s\\n' '{FIXED_STAMP}'; exit 0\n"
        "fi\n"
        "if [ \"${1-}\" = \"+%s\" ]; then\n"
        f"  printf '%s\\n' '{FIXED_EPOCH}'; exit 0\n"
        "fi\n"
        "exec /usr/bin/date \"$@\"\n",
        encoding="utf-8",
    )
    script.chmod(0o755)


def _run_script(
    script: str,
    work: Path,
    lib: Path,
    extra: dict[str, str] | None = None,
    mode: str = "",
) -> subprocess.CompletedProcess:
    """Run `script` with `$1=work $2=lib [$3=mode]` under a controlled env."""
    env = _base_env(work, **(extra or {}))
    args = ["bash", "-c", script, "bash", str(work), str(lib)]
    if mode:
        args.append(mode)
    work.mkdir(parents=True, exist_ok=True)
    _fake_date(work)
    Path(env["HOME"]).mkdir(parents=True, exist_ok=True)
    return subprocess.run(args, env=env, capture_output=True, text=True, check=False)


LOCK_SCRIPT = r"""
set -u
lib="$2"
. "$lib"
gleipnir_state_dir s; echo "state=$s"
gleipnir_lock_path l; echo "lock=$l"
gleipnir_lock_pointer_path p; echo "pointer=$p"
gleipnir_lock_owner o; echo "owner0=$o"
gleipnir_lock_acquire; echo "acquire=$? acquired=$GLEIPNIR_LOCK_ACQUIRED"
gleipnir_lock_owner o; echo "owner=$o"
gleipnir_lock_owned; echo "owned=$?"
echo "starttime=$(cat "$l.starttime")"
echo "pointerbody=$(cat "$p")"
gleipnir_lock_release; echo "release=$?"
gleipnir_lock_owner o; echo "owner2=$o"
[ -e "$l" ] && echo "after=present" || echo "after=absent"
printf '999999\n' > "$l"
gleipnir_lock_reap 2>"$BROKK_STATE_OVERRIDE/reap.err"
[ -e "$l" ] && echo "reaped=present" || echo "reaped=absent"
echo "reaperr=$(cat "$BROKK_STATE_OVERRIDE/reap.err")"
"""


RUNES_SCRIPT = r"""
set -u
lib="$2"
. "$lib"
runes_append alpha first --message "hello world"
runes_append beta second --order W0042 --realm work --message 'quote " and \ backslash'
runes_append gamma third --message "multi
line"
echo "last=$RUNES_LAST_CHECKSUM"
"""


QUEUE_SCRIPT = r"""
set -u
work="$1" lib="$2" mode="$3"
. "$lib"
legacy_fm_wake_append() {
  local kind=$1 key=$2 payload=$3 clean_key clean_payload epoch seq seq_file status recovery_marker
  clean_key=$(printf '%s' "$key" | fm_wake_clean_field)
  clean_payload=$(printf '%s' "$payload" | fm_wake_clean_field)
  epoch=$(date +%s)
  seq_file="$STATE/.wake-queue.seq"
  recovery_marker="$STATE/.watcher-down"
  status=0
  fm_lock_acquire_wait "$BROKK_WAKE_QUEUE_LOCK"
  _fm_recovery_marker_publish "$recovery_marker" downtime || status=$?
  if [ "$status" -eq 0 ]; then
    seq=$(cat "$seq_file" 2>/dev/null || echo 0)
    case "$seq" in ''|*[!0-9]*) seq=0 ;; esac
    seq=$((seq + 1))
    printf '%s\n' "$seq" > "$seq_file" || status=$?
  fi
  if [ "$status" -eq 0 ]; then
    printf '%s\t%s\t%s\t%s\t%s\n' "$epoch" "$seq" "$kind" "$clean_key" "$clean_payload" >> "$BROKK_WAKE_QUEUE" || status=$?
  fi
  fm_lock_release "$BROKK_WAKE_QUEUE_LOCK"
  return "$status"
}
if [ "$mode" = legacy ]; then
  legacy_fm_wake_append check K1 "payload one"
else
  fm_wake_append check K1 "payload one"
fi
"""


class LockParityTest(unittest.TestCase):
    def test_lock_cycle_is_byte_identical(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pid = str(os.getpid())
            legacy_work = root / "legacy"
            shim_work = root / "shim"
            legacy = _run_script(LOCK_SCRIPT, legacy_work, LEGACY_LOCK, {"BROKK_SESSION_PID": pid})
            shim = _run_script(LOCK_SCRIPT, shim_work, SHIM_LOCK, {"BROKK_SESSION_PID": pid})
            self.assertEqual(legacy.returncode, 0, legacy.stderr)
            self.assertEqual(shim.returncode, 0, shim.stderr)
            legacy_body = legacy.stdout.replace(str(legacy_work), "W")
            shim_body = shim.stdout.replace(str(shim_work), "W")
            self.assertEqual(legacy_body, shim_body)
            self.assertIn("acquire=0 acquired=1", shim_body)
            self.assertIn("after=absent", shim_body)
            self.assertIn("reaped=absent", shim_body)
            self.assertIn("gleipnir: reaped stale lock (dead pid 999999)", shim_body)

    def test_pointer_shape_is_unchanged(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            result = _run_script(
                LOCK_SCRIPT, work, SHIM_LOCK, {"BROKK_SESSION_PID": str(os.getpid())}
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            # The pointer body is read inside the script, before release drops it.
            body = {}
            for line in result.stdout.splitlines():
                key, _, value = line.partition("=")
                body[key] = value
            self.assertEqual(body["pointerbody"], str(work / "machine" / "brokk.lock"))
            self.assertTrue(body["pointer"].endswith("/state/.lock-path"))


class RunesParityTest(unittest.TestCase):
    def test_rune_append_is_byte_identical(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            outputs = []
            ledgers = []
            for name, lib in (("legacy", LEGACY_RUNES), ("shim", SHIM_RUNES)):
                work = root / name
                extra = {
                    "BROKK_HOME": str(work / "home"),
                    "BROKK_RUNES_FILE": str(work / "runes_audit.md"),
                    "BROKK_RUNES_LOCK": str(work / "runes.lock"),
                }
                result = _run_script(RUNES_SCRIPT, work, lib, extra)
                self.assertEqual(result.returncode, 0, result.stderr)
                outputs.append(result.stdout)
                ledgers.append((work / "runes_audit.md").read_text(encoding="utf-8"))
            self.assertEqual(outputs[0], outputs[1])
            self.assertEqual(ledgers[0], ledgers[1])
            self.assertIn("order=W0042", outputs[1])

    def test_rune_shape_chains(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            extra = {
                "BROKK_HOME": str(work / "home"),
                "BROKK_RUNES_FILE": str(work / "runes_audit.md"),
                "BROKK_RUNES_LOCK": str(work / "runes.lock"),
            }
            _run_script(RUNES_SCRIPT, work, SHIM_RUNES, extra)
            from ymir_runtime.state import runes as runes_mod

            ok, tip = runes_mod.verify(work / "runes_audit.md")
            self.assertTrue(ok, tip)


class QueueParityTest(unittest.TestCase):
    def _both(self, root: Path) -> tuple[Path, Path]:
        legacy = root / "legacy"
        shim = root / "shim"
        legacy_result = _run_script(QUEUE_SCRIPT, legacy, SHIM_WAKE, mode="legacy")
        shim_result = _run_script(QUEUE_SCRIPT, shim, SHIM_WAKE, mode="shim")
        self.assertEqual(legacy_result.returncode, 0, legacy_result.stderr)
        self.assertEqual(shim_result.returncode, 0, shim_result.stderr)
        return legacy, shim

    def test_queue_append_is_byte_identical(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            legacy, shim = self._both(Path(tmp))
            legacy_queue = (legacy / "state" / ".wake-queue").read_text(encoding="utf-8")
            shim_queue = (shim / "state" / ".wake-queue").read_text(encoding="utf-8")
            self.assertEqual(legacy_queue, shim_queue)
            self.assertEqual(shim_queue, f"{FIXED_EPOCH}\t1\tcheck\tK1\tpayload one\n")

    def test_seq_file_matches(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            legacy, shim = self._both(Path(tmp))
            legacy_seq = (legacy / "state" / ".wake-queue.seq").read_text(encoding="utf-8")
            shim_seq = (shim / "state" / ".wake-queue.seq").read_text(encoding="utf-8")
            self.assertEqual(legacy_seq, shim_seq)
            self.assertEqual(shim_seq.strip(), "1")


class QueueKeysParityTest(unittest.TestCase):
    def test_keys_match_the_old_awk(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            (work / "state").mkdir(parents=True, exist_ok=True)
            (work / "state" / ".wake-queue").write_text(
                "1\t1\tcheck\ta\tp\n"
                "2\t2\tcheck\tb\tp\n"
                "3\t3\tcheck\ta\tp\n"
                "4\t4\tstale\ta\tp\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                ["bash", "-c", f'set -u\n. "{SHIM_WAKE}"\nfm_wake_queued_keys check\n'],
                env=_base_env(work),
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "a\nb\n")


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
