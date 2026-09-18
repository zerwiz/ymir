## runtime · unversioned · 2026-09-17 — the feed follows Brokk's thinking past the composer

### Why
- **Sessrúmnir's auto-scroll never counted streamed THINKING as growth.**
  `useChatScroll` watched `messages` and `streamingContent` only, so a
  reasoning-heavy turn (thinking before any visible content) grew the feed
  without moving it — the thinking block ended up below the floating composer,
  behind it, and the Allfather had to scroll down to read it.
- **The growth signal now also includes `streamingThinking` and streaming tool
  calls.** While Brokk reasons, the feed keeps the thinking tail in view above
  the composer (still only when Auto Scroll is on and the reader is at the
  bottom — scrolling up to re-read never gets yanked).
- Live hall updated: rebuilt renderer delivered to the running Sessrúmnir and
  the app restarted via `bin/sessrumnir.sh` (window back on workspace 8).

### Files
- *(carried from the frozen CHANGELOG.md)*
