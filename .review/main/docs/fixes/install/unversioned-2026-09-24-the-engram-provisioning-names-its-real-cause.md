## install · unversioned · 2026-09-24 — the engram provisioning names its real cause

### Why
`bin/prereq-ensure.sh engram` reported a version problem that was not a version problem:

```
"engram","absent","install failed (engdbram needs Python >=3.11) — try: uv python install 3.12"
```

Two confusions, both now written down in the script:

- **The install failed because the interpreter had no pip**, not because it was the
  wrong version. Debian's Python ships without pip (`python3 -m pip` →
  *No module named pip*), and the install line sends its output to `/dev/null`, so
  the real cause never surfaced. uv's CPython bundles pip, which is why fetching
  3.12 worked and looked like a version story.
- **The version ceiling in the comments was read from the wrong package.** The PyPI
  project *called* `engram` is a differentiable-rendering stack (`mitsuba`, `drjit`)
  declaring `<3.14,>=3.12`. Our engine is **`engdbram`** ("Embeddable cognitive memory
  layer for AI agents"), whose module is `engram`, and it declares `>=3.11`. There is
  no `<3.14` ceiling and no need for a lower Python.

### What
- **`engram_ensure_pip`** gives an interpreter its pip before blaming it: it tries
  `-m pip`, then stdlib `ensurepip`, then says so plainly. Where a distro disables
  ensurepip (Debian does), the message now reads *"no pip for Python 3.13.5, and
  ensurepip could not supply one"* rather than blaming the version.
- **The uv fallback stays**, and now runs only when the interpreter is genuinely too
  old or genuinely cannot install; it supplies a 3.12 that can do both.
- **The failure message names the real cause** from one of: too old, no pip, pip
  could not install, or installed but still unimportable.
- `engram_version_ok` and `engram_v` are small helpers, so the conditions read once.

### Files
- `bin/prereq-ensure.sh`
