# Rune-Glyph Icon Map

**Runecoded, not emoji.** Every icon in Ymir is an Elder Futhark rune drawn as a
24px stroke glyph, colored by `currentColor`. Emoji are never used as icons.

## Set

The glyphs live in `midgard/design-system/icons/*.svg` (24×24 viewBox; render at
16px or 24px). Stroke uses `currentColor`, square caps, miter joins — the chisel
bevel. The primary seat may add a 1px inner bevel via the `--ymir-bevel` token.

```
icons[21]{glyph,name,unicode,figure,used_for}:
  "fehu","Fehu","ᚠ","Ymir (cattle/wealth)","Fleet — the herd of agents"
  "tiwaz","Tiwaz","ᛏ","Týr (justice)","Tasks — the A2A lifecycle board"
  "ingwaz","Ingwaz","ᛜ","Ing (the well)","Well — Mimirsbrunn recall"
  "raidho","Raidho","ᚱ","ride/journey","Runes — the ledger (a road carved)"
  "algiz","Algiz","ᛉ","protection","Reviews / Glitnir — the protective gate; the Ymir emblem"
  "dagaz","Dagaz","ᛞ","day/dawn","Processes — Valhalla supervision"
  "sowilo","Sowilo","ᛊ","sun","Files — Skrymir (light on the tree)"
  "kaunan","Kaunan","ᚴ","torch","OmniChat — Kaia's flame"
  "ansuz","Ansuz","ᚨ","Odin's breath","Forge — creation"
  "ehwaz","Ehwaz","ᛖ","horse/journey","Runtime — the seat and its transit"
  "jera","Jera","ᛃ","year/harvest","Cron — the Nornir's seasons"
  "berkana","Berkanan","ᛒ","birch","Profile — the self"
  "midgard","Midgard","—","the shared world","shared workspace / cross-tenant assets"
  "utgard","Utgard","ᚢ","the outer realm","Utgard — the sandbox barrier"
  "yggdrasil","Yggdrasil","ᛃ","the world-tree","Yggdrasil — worktrees"
  "ratatoskr","Ratatoskr","ᛒ","the squirrel","Ratatoskr — the A2A bus"
  "mimirsbrunn","Mimirsbrunn","ᛜ","the well of wisdom","Mimirsbrunn — memory"
  "valhalla","Valhalla","ᚹ","the hall of the slain","Valhalla — process health"
  "gungnir","Gungnir","ᚷ","Odin's spear","Gungnir — skill synthesis"
  "heimdall","Heimdall","ᚺ","the watchman","Heimdall — auth / the gate"
  "gjallarhorn","Gjallarhorn","ᚷ","the horn","Gjallarhorn — the tunnel and its call"
```

## Usage

- Reference a glyph as an inline `<svg>` (copy the path) or `<img src>`; stroke
  with `currentColor`, never a raw hex.
- Render at **24px** in panels, **16px** inline in tables and chips.
- A status glyph is always paired with **glyph + colour + text** — never
  colour-only state.
- The active realm/accent may tint glyphs via `--realm-tint`.

## Verification

```bash
ls midgard/design-system/icons/*.svg | wc -l      # 21
# no emoji used as icons in the UI:
rg -n "[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]" apps/hlidskjalf/src || echo "no emoji icons"
```

## Maintaining this

- **Owner:** Brokk. **Tokens:** `midgard/design-system/tokens.css`.
- Add a rune here and its glyph in `icons/` in the same pass; keep the count in the
  `icons[N]` block true (Galdr TOON check: `.agents/skills/galdr-ymirsystem/scripts/toon-check.py`).
