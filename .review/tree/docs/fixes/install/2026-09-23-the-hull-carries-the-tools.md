# install · 2026-09-23 — the hull carries the tools

## Why
The npm manifest's `files[]` whitelist lacked `tools/`: every published
tarball (0.1.40–0.1.49) shipped WITHOUT the fleet's unit templates
(tools/mill/systemd), the well's server, Bölþorn the skills well, and the
Ratatoskr node — an npm-seat install had no templates to raise its fleet from
(proven: tools/skills-mcp was absent from the 0.1.49 tarball).

## What
- `package.json` `files[]` += `tools/` (with the node_modules/__pycache__
  exclusions), so the tarball carries the whole tools/: mill, well-mcp,
  ratatoskr-node, skills-mcp, and tickets-mcp after it lands.

## Files
- `package.json`
