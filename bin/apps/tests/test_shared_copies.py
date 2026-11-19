"""An app that leaves carries its own copy of what it shared with Ymir; the copy stays the source.

The smithy's viewer imported Ymir's hearth (`midgard/design-system/ember.js`) by climbing five folders
up, which finds nothing once the app builds in its own repo — the seam that broke on 2026-09-18. It now
imports its own byte-identical copy. This keeps the copy equal to the source wherever both can be read:
in Ymir's tree while the app is here, and from the installed app (`app-path.sh`) once it has left.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

# (source in Ymir, app, path inside the app's own folder)
PAIRS = [
    ("midgard/design-system/ember.js", "smidja", "apps/visualizer/src/lib/ember.js"),
]


def app_dir(app: str) -> Path | None:
    out = subprocess.run(["bash", str(ROOT / "bin/apps/app-path.sh"), app], capture_output=True, text=True)
    return Path(out.stdout.strip()) if out.returncode == 0 and out.stdout.strip() else None


class SharedCopies(unittest.TestCase):
    def test_every_copy_equals_its_source(self):
        for source, app, rel in PAIRS:
            where = app_dir(app)
            if where is None or not (where / rel).is_file():
                continue          # the app is not on this machine: nothing to compare
            self.assertEqual((ROOT / source).read_bytes(), (where / rel).read_bytes(),
                             f"{app}:{rel} has drifted from {source} — copy the source over it")


if __name__ == "__main__":
    unittest.main()
