# The Rune Library

**Runecoded, not emoji.** Every icon in Ymir is an Elder Futhark rune drawn as a
24×24 stroke glyph, coloured by `currentColor` (or the app's house tint). This is
the library: the full futhark, what each rune means, and where Ymir uses it.

- **Glyphs:** `midgard/design-system/icons/*.svg` (24×24 viewBox, stroke 1.8,
  square caps, miter joins — the chisel bevel).
- **Names in code:** the file name is the rune's name, lower-case (`ehwaz.svg`).
- **Usage rules:** inline `<svg>` or `<img src>`; stroke with `currentColor`,
  never a raw hex; 24px in panels, 16px inline; a status glyph is always paired
  with **glyph + colour + text**, never colour alone.
- **The app runes:** five UI surfaces, five different glyphs — see the foot.

## The futhark

```
runes[24]{glyph,name,sound,meaning,ymir_use,file}:
  "ᚠ","Fehu","f","cattle, wealth","Fleet — the herd of agents","fehu"
  "ᚢ","Uruz","u","aurochs, strength","Utgard — the sandbox barrier","utgard"
  "ᚦ","Thurisaz","th","thorn, giant","Gungnir — skill synthesis","gungnir"
  "ᚨ","Ansuz","a","Odin's breath","Forge — creation","ansuz"
  "ᚱ","Raido","r","ride, journey","Runes — the ledger (a road carved)","raidho"
  "ᚲ","Kaunan","k","torch, ulcer","Smíðja's eye — the trace of the forge, OmniChat's flame","kaunan"
  "ᚷ","Gebo","g","gift","Gjallarhorn — the tunnel and its call","gjallarhorn"
  "ᚹ","Wunjo","w","joy","Óðrerir — the Live Hall","valhalla"
  "ᚺ","Hagall","h","hail","Heimdall — auth, the gate","heimdall"
  "ᚾ","Naudiz","n","need, constraint","(no glyph yet)","—"
  "ᛁ","Isaz","i","ice","(no glyph yet)","—"
  "ᛃ","Jera","j","year, harvest","Nornir — the seasons; Yggdrasil — the world-tree's cycle","jera"
  "ᛇ","Eihwaz","ï","yew","(no glyph yet)","—"
  "ᛈ","Perthro","p","lot, fate","(no glyph yet)","—"
  "ᛉ","Algiz","z","protection","Glitnir's reviews — the protective gate; **the Ymir emblem**","algiz"
  "ᛊ","Sowilo","s","sun","Skrymir — files (light on the tree); Sessrúmnir — the seat that shows the cloth","sowilo"
  "ᛏ","Tiwaz","t","Týr, justice","Tasks — the A2A lifecycle board","tiwaz"
  "ᛒ","Berkanan","b","birch","Profile — the self; Ratatoskr — the messenger","berkana"
  "ᛖ","Ehwaz","e","horse","Runtime — the seat and its transit; Hlidskjalf","ehwaz"
  "ᛗ","Mannaz","m","man, self","(no glyph yet)","—"
  "ᛚ","Laguz","l","water, flow","(no glyph yet)","—"
  "ᛜ","Ingwaz","ng","Ing, the seed","Mimirsbrunn — the well of wisdom","ingwaz"
  "ᛞ","Dagaz","d","day, dawn","Valhalla — process health","dagaz"
  "ᛟ","Othala","o","inheritance, estate","(no glyph yet)","—"
```

**Twenty-one of the twenty-four are drawn; three are not yet:** Naudiz, Isaz,
Eihwaz, Perthro, Mannaz, Laguz and Othala have no file — add the glyph and its
row in `icons.md` in the same pass.

**Every file is a rune.** It was not always so: eight files used to be *drawings*
of the thing they were named after (a hall, a horn, a shield, a spear, a well, a
squirrel, a gate, a world-tree) while `icons.md` claimed a rune for each. Corrected
2026-09-16 — Gungnir took Thurisaz, since Gebo was already Gjallarhorn's.

## The app runes

Five UI surfaces, five different glyphs — no app borrows another's rune:

```
app_runes[5]{app,glyph,rune,house_tint}:
  "Hlidskjalf","ᛖ","ehwaz — the seat","#c9973f bronze (ymirlabs)"
  "Hlidskjalf Mobile","ᚱ","raidho — the road, the seat carried","#c9973f bronze"
  "Óðrerir","ᚹ","wunjo — joy, the hall","#c9973f bronze"
  "Sessrúmnir","ᛊ","sowilo — the sun, the cloth shown","#8b5cf6 violet (muninn)"
  "Smíðja (visualizer)","ᚲ","kaunan — the torch, the forge's eye","#f59e0b amber (brokkforge)"
```

Minted and installed by `bin/design-icon.sh` (`list` · `mint --all` · `install`):
the icon into the user's icon theme, the `.desktop` entry into their applications
dir, so every app is dockable and carries the house mark.

## Adding a rune

1. Draw it in `icons/<name>.svg` — 24×24, stroke 1.8, square caps, miter joins,
   `stroke="currentColor"`, a `<title>` naming the rune and its use.
2. Add its row to `icons.md` **and** to the futhark table above, in the same
   change. Keep both counts true (the TOON check counts rows).
3. If an app should wear it, add the app to `bin/design-icon.sh`'s table and run
   `mint --all && install`.
