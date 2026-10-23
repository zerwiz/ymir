## harness · 2026-10-23 — no errand tool can paint the terminal, not even by a dead branch

Reading #412's own fix showed the mend was half a mend:

```ts
const out = execFileSync(cmd, args, { encoding: "utf8",
  stdio: quiet ? ["ignore", "pipe", "ignore"] : "inherit" });   // quiet = true by default
```

No caller ever passes `quiet`, so the `"inherit"` branch was **unreachable — and still a painting path**:
one future `run(cmd, args, false)` and the terminal belongs to the child again, which is precisely the
fault of tonight (the child draws where its cursor is, pi never sees the bytes, and nothing in its
renderer can repair the damage).

**The branch is gone rather than defaulted.** `run(cmd, args)` always captures
(`stdio: ["ignore", "pipe", "ignore"]`), and the comment states the contract in one line: a tool RETURNS
text, pi renders it.

Verified: `bun build .pi/extensions/eindri.ts` bundles clean (6.60 KB, no errors); the only inherited
stdio left in the harness is `open-editor.ts`, which stops the TUI before handing over the terminal.
Owed: a seated session restarted after this merge is the proof the screen stays whole.
