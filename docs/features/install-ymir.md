# Install Ymir

## What it is

Ymir installs into a **prefix you own** — no sudo, no writing to system
directories. It writes the PATH into your shell, runs the first setup, and then
**proves it** by answering to its own name. Everything after that is a door on one
command: `ymir`.

## What you need

- **Node 20+**. The installer does not install Node for you.

## Do it

```bash
curl -fsSL https://raw.githubusercontent.com/zerwiz/ymir/main/install.sh | bash
```

**Run it without installing anything:**

```bash
npx @zerwiz/ymir
```

**Manage Node yourself:**

```bash
npm install -g @zerwiz/ymir     # then: ymir
```

It puts **two** commands on your PATH: `ymir` and `ymir-install`. Then take the
first step:

```bash
ymir            # first setup: it prints the PLAN, then waits for your word
```

Ymir computes the plan from *your* machine and prints what it would change; nothing
changes until you accept. Afterwards, the doors are all on `ymir`:

```
ymir raise | lower       lift the hall, or lay it down
ymir hlidskjalf          the control plane's window
ymir smidja              the smithy's board
ymir eir · groa          what stands and mending · take the latest and mend forward
ymir mimir · plan        memory, and the plan ledger
ymir heimdall · invite   the way in, and letting someone else in
```

## Notes and limits

- **Your home, your data.** Private data lives at `$YMIR_HOME` (default
  `~/Documents/ymirhome`), never in the installed tree. The tree is code; the home is
  yours; a fresh clone and a package are the same tree.
- **No sudo, no system files.** The prefix is yours (default `~/.npm-global`).
- **It proves itself.** The install ends by running `ymir --version`; if that fails,
  the install failed.
- **A name without a home still answers once** and names its door: `ymir doctor`
  replies *the door is named `ymir eir` now*.

## If it does not work

| What you see | What to do |
|---|---|
| `ymir: command not found` | npm put it in its global bin, which your shell does not look at. `export PATH="$(npm prefix -g)/bin:$PATH"`, or just use `npx @zerwiz/ymir`. |
| `npm: command not found` | Install Node 20+, then run the installer again. |
| It wants a directory | The first setup asks where your home should be; answer it, or pass `--yes` to accept the recorded/default home. |
| The version never changes | The installed copy is older than the registry — `groa` takes the latest: `ymir groa`. |
