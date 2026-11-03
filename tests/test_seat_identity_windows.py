"""Exercise Git Bash/native Python without changing the user's seat."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


@unittest.skipUnless(sys.platform == 'win32', 'native Windows integration')
class WindowsSeat(unittest.TestCase):
    def test_private_reinstall_and_missing_profile_are_safe(self):
        bash = shutil.which('bash', path=r'C:\Program Files\Git\bin')
        if not bash:
            self.skipTest('Git Bash not installed')
        with tempfile.TemporaryDirectory(prefix='seat identity ') as tmp:
            base = Path(tmp)
            home, ymir = base/'home', base/'ymir'
            identity = ymir/'hodd/identity'
            identity.mkdir(parents=True)
            profile = ymir/'.agents/agents/private-test.md'
            profile.parent.mkdir(parents=True)
            profile.write_text('Private test role', encoding='utf-8')
            # Obtain the actual Windows host, with no Unix-only flags.
            host = subprocess.check_output(['hostname'], text=True).strip()
            (identity/'seats.yaml').write_text(
                f'seats:\n  {host}: {{primary: private-test, status: sealed}}\n',
                encoding='utf-8')
            env = dict(os.environ, SEAT_TEST_HOME=home.as_posix(),
                       YMIR_HOME=ymir.as_posix(),
                       SEAT_TEST_DOOR=(Path(__file__).resolve().parents[1]/
                                       'bin/agents/seat-identity.sh').as_posix())
            # Use the running Python, not a Store alias or changed global PATH.
            env['YMIR_PYTHON'] = Path(sys.executable).as_posix()
            def run(verb):
                return subprocess.run([bash, '-c',
                    'export HOME="$SEAT_TEST_HOME"; bash "$SEAT_TEST_DOOR" "$1"',
                    'seat-test', verb], env=env, capture_output=True, text=True,
                    timeout=30)
            for verb in ('--install', '--ensure', '--check'):
                result = run(verb)
                self.assertEqual(result.returncode, 0, result.stderr+result.stdout)
            seat = home/'.pi/agent/extensions/.ymir-seat'
            original = seat.read_bytes()
            self.assertIn(profile.as_posix(), original.decode())
            profile.unlink()
            self.assertNotEqual(run('--install').returncode, 0)
            self.assertEqual(original, seat.read_bytes())


if __name__ == '__main__':
    unittest.main()
