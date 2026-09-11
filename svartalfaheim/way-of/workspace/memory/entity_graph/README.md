# Entity Graph

Relationship notes for the realm's workspace. `bin/workspace-rag.sh entities|graph`
reads these files; each `[[Entity]]` is a node, and `[[A]] -> [[B]]` is a directed
edge. Keep entries short and grounded; this is the realm's memory of *how things
relate*, not a copy of the documents.

## Format

```
[[hlidskjalf]] -> [[gate-api]]
[[gate-api]] -> [[runes]]
[[brokk]] -> [[eindri]]
```

Plain Markdown with `[[wiki-links]]` and `->` edges. Index the prose docs with
`bin/workspace-rag.sh index`; index the relationships here.
