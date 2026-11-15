# Fix: the whiteboard door's two tools are named for the whiteboard

Plan 284 §21 renames the product's user-facing surfaces; the ticket ledger records
the reasoning. This is the Ymir half: the two tool names an agent calls.

`.pi/extensions/excalidraw/index.ts` registered `excalidraw_tickets` and
`excalidraw_servers`. They are now `whiteboard_tickets` and `whiteboard_servers`,
and each retired name is registered beside its new one with a description that
starts `DEPRECATED` and says to call the new name — so a saved prompt or a habit
keeps answering for one release before the alias is removed.

What did **not** change, and why:

- `excalidraw_diagram` and `excalidraw_app` keep their names. They name a file
  format (`.excalidraw`, which saved boards depend on) and the upstream desktop
  app; the licence and the format's name stay (plan 284 §21, "what stays").
- The extension's directory, module names and internal identifiers are unchanged.
  Renaming them rewrites imports for nobody's benefit; the extension path is the
  door, not a surface a user reads.

The test that proves it: loading the extension with a stub `pi` registers six
tools — `whiteboard_tickets`, `whiteboard_servers`, the two deprecated aliases,
and the two unchanged doors. Verified by loading the module under node's type
stripping and printing every `registerTool` name.
