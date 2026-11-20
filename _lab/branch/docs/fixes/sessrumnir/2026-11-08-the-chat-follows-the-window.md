# sessrumnir · 2026-11-08 — the chat follows the window, not the window it was designed for

Translated from plan 222 (`svartalfaheim/whynotproductions/projects/ymir/plans/`), whose
§1 is the measurement and §2 the five rules this note is held to.

### Why

He runs Sessrúmnir and Rödd side by side, so the chat is routinely half a screen — and
the text ran off the right edge, which in a chat means the sentence he was reading was
cut in half.

The measured cause: the message column (`div.mx-auto.max-w-5xl.px-4`) is a flex child of
the message scroller and carries `min-width: auto`, so its floor was its **content's**
minimum width — the code block's 952 px of unbroken `whitespace-pre` — and `max-w-5xl`
(1024 px) became the width it *took* rather than the ceiling it should have been. The
pane above it clips (`overflow: hidden`), so nothing ever grew a scrollbar to warn
anybody: the right of every line was simply gone.

### The measurement, before and after

`node scripts/probe-chat-widths.mjs` renders the shipping `ChatPanel` in headless
Chromium over the shipping stylesheet and reports every element whose right edge crosses
its container. Baseline `scripts/probe/BASELINE.md`; after:

| case | before | after |
| --- | --- | --- |
| window 1280 | clean | clean |
| window 1024 | clean | clean |
| window 960 | message column 64 px over | clean |
| window 800 | message column 224 px over | clean, prose 728 px / 5 lines, code block scrolls |
| pane 400 in 1400 | message column 624 px over, composer 104 px tall | clean, prose 326 px / 11 lines, composer 76 px / one line |
| window 800, file tree | column 504 px over, file pane 9 px over | clean, panel drawn 280 px |
| window 800, tree + preview | column 504 px over | clean, panel shrunk to 480 px and says so |
| pane 400, file tree | panel took 280 px of 400, chat 120 px, composer 251 px over | panel closed, chat 400 px, toolbar says "Panel closed to fit" |

### What

- **The shrink fix.** `min-w-0` on the flex children that must follow the window: the
  message column, the composer wrappers, the empty-state column, the file pane. Prose and
  table cells get `overflow-wrap: anywhere` (not `break-word` — only `anywhere` also
  lowers min-content, which is the floor that was blocking the shrink). `overflow-x: auto`
  stays on `<pre>` and on wide tables, so a code block scrolls inside itself while the
  prose beside it wraps.
- **One width authority, two inputs.** `resolveSidePanelMetrics` already took the
  column; it now clamps the panel against `column - MIN_CHAT_CENTER_WIDTH` and reports a
  verdict: `full` · `shrunk` · `closed`. The drag handle clamps to the same
  `maxSidePanelWidth` the render uses, so the state cannot outrun the screen. The
  editor/image pane's 360 px floor is honoured only while the panel can afford it.
- **Container queries at the pane boundary.** `.chat-center` is a `container-type:
  inline-size` query root named `chat`, so the branches are asked of the PANE: the
  workspace path gives way under 620, message gutters tighten under 520, the composer's
  secondary affordances stand down under 440, the thinking selector under 380, and the
  permission picker under 360 (the review panel carries the same picker). The
  one `sm:inline` that was answering the *window* question ("Shift+Enter for a newline")
  is now a container rule.
- **It says which way it gave way.** A panel that narrowed shows "Panel narrowed to fit";
  a panel that closed shows "Panel closed to fit", each with a title naming the reason and
  the floor involved.
- **The probe is the test.** `chat-layout.test.ts` drives the probe once per case and
  asserts, per width: no element crosses its container, no page scrollbar, the prose wraps
  (and is not cut), the code block scrolls, the composer stays one line, and the panel
  either fits, shrinks with a word, or closes with a word. A machine without Chromium
  SKIPS with the reason — never a quiet pass.

### Files

- `apps/sessrumnir/src/renderer/src/index.css`
- `apps/sessrumnir/src/renderer/src/components/chat-panel.tsx`
- `apps/sessrumnir/src/renderer/src/components/chat-input.tsx`
- `apps/sessrumnir/src/renderer/src/components/chat-panel-widths.ts` (+ its test)
- `apps/sessrumnir/src/renderer/src/components/chat-layout.test.ts` (new)
- `apps/sessrumnir/src/renderer/src/components/message-bubble.tsx`
- `apps/sessrumnir/src/renderer/src/components/composer-permission-menu.tsx`
- `apps/sessrumnir/resources/locales/en/translation.json`
- `apps/sessrumnir/scripts/probe-chat-widths.mjs` (new), `scripts/probe/` (new)
- `apps/sessrumnir/eslint.config.mjs` (the probe's two runtimes: Node for the runner, the
  browser for the page side)

### Limits — read before trusting the green

- **CodeMirror does not mount in the probe.** The code pane throws inside
  `EditorState.create` in a headless document, so the two-pane panel case is measured with
  the image pane, which carries the same 360 px floor. The code pane's own layout is
  therefore covered by the width maths, not by a browser measurement.
- **Two existing assertions in `chat-panel-widths.test.ts` were rewritten**, not kept:
  they asserted that the panel may take the *whole* column (500 for a 500 px column),
  which is the bound plan 222 §2 retires. Their names and purpose are unchanged; the
  numbers now encode "the chat keeps `MIN_CHAT_CENTER_WIDTH` first". Every other test in
  that file is untouched and passes.
- **Nothing here is a redesign.** The desktop shape is the same; it is now allowed to be
  small. No mobile shell, no second layout system, no second place that decides a width.
- Headless Chromium's minimum window is about 500 px, so a *window* narrower than that is
  measured as a pane (`--pane`) inside a wide window — which is also the honest case for a
  chat beside a second app.
- Pre-existing and untouched: `eslint src` fails on `src/renderer/src/assets/ember.js`
  (no browser globals block for that path), `i18next-cli extract --ci` reports
  `toolbar.ymir` vs `chat.toolbar.ymir`, and `tsc -b` reports 5 errors in `bridge-http.ts`,
  `file-tree.tsx` and `settings-panel.tsx`. All reproduced on the branch's base commit.
