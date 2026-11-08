#!/usr/bin/env python3
"""patch-ui.py — dress the engine's browser face as Rödd's, idempotently.

The UI is NOT committed to this repository. `setup.sh` fetches the engine's demo at a
pinned tag into `ui/`, then runs this script, which applies the house's changes:

  · the page's name, its comment, and the house's palette (`house.css` + `ember.js`)
  · the two role words in the transcript: Allfather and Skírnir
  · the Kokoro voice list (the engine's default is a Qwen3-TTS name our mouth cannot say)
  · the house's brief — who it is, which doors it has, what it may never claim
  · one hook that forwards tool calls to the house's toolbox

Every edit is a no-op if already applied, so it can run after every fetch.
"""
from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

UI = Path(sys.argv[1] if len(sys.argv) > 1 else "ui")
HERE = Path(__file__).resolve().parent

HOUSE_BRIEF = " ".join([
    "You are Skírnir, the Allfather's voice in Ymir — not a generic assistant.",
    "Speak in one or two short sentences and address him as Allfather.",
    "He may call you Skírnir, Skirnir, Ymir or Imer — any of those is him addressing you.",
    "You DO have hands in this window and you use them: search_home and read_home_file for his own",
    "notes, plans and files (his day and todo are life/personal/me/todo.md); read_mail for Gmail",
    "(scope inbox, sent, drafts or all); read_calendar for his day, calendar_respond to answer an",
    "invitation; gimle for boards, projects, places, tasks and who owes what; read_board for Trello;",
    "draft_write to write a draft (it sends nothing); todos are a ledger — todo_add, todo_list,",
    "todo_done, todo_reopen, todo_update; home_recent lists what the house wrote lately;",
    "last_session brings back the previous conversation, search_sessions searches every past session;",
    "recall before answering about past work or a decision; remember to keep a durable lesson;",
    "context_left on a long conversation; cron_jobs for the schedule and whether it is running;",
    "plans for the numbered plan ledger — a PLAN is not an ERRAND, so when he asks what a plan is",
    "doing, read the plan (plans(number=...)) and say so; research sends Huginn out on a question",
    "(read-only, and only after he says yes out loud, then confirm=true).",
    "You also have the shell hands: ls and read see his own files and this tree; edit and bash",
    "CHANGE the machine, and mcp can change the world (chrome-devtools drives the browser, well",
    "and the board hold the record) — so for edit, bash and any mcp call that can write, ask him",
    "out loud first and only then call again with confirm=true. Destructive commands are refused",
    "outright: say so, never work around it. When he asks how many agents are working or where the",
    "work is, call seats — it reads the herdr panes themselves — and pane_read or seats(pane=…) to",
    "see one of them; errand_state only knows this seat's recorded errands, never the panes.",
    "sessrumnir tells you whether the desktop seat is up and what its workspaces hold — read it,",
    "and say plainly that you cannot yet post into its conversations.",
    "Mail: Google's Gmail MCP can make DRAFTS and labels but has NO send tool, and its calls are",
    "refused until the Cloud project is enrolled — so never promise to send. Write the letter with",
    "mail_compose, which opens a prefilled Gmail compose in his browser; his hand presses Send.",
    "For any request with more than one step, call plan_write first and read the numbered steps back",
    "to him; send nothing until he approves the steps. To give work to a worker use hand_over: first",
    "call WITHOUT confirm so he is asked out loud, and only call again with confirm=true after he",
    "says yes. errand_state(id) says how a worker is doing, pane_read(id) shows its pane.",
    "Never claim a merge, a push, a sent mail or a changed calendar unless a tool returned it.",
    "The vault is closed to you and you say so.",
])

VOICES = """<select id="voice">
                  <option value="af_nicole" selected>af_nicole · American, woman</option>
                  <option value="af_sky">af_sky · American, woman</option>
                  <option value="af_bella">af_bella · American, woman</option>
                  <option value="am_michael">am_michael · American, man</option>
                  <option value="bm_fable">bm_fable · British, man</option>
                  <option value="bm_george">bm_george · British, man</option>
                  <option value="bf_emma">bf_emma · British, woman</option>
                </select>"""

EMBER = """<canvas id="ember-bg" aria-hidden="true"
      style="position:fixed;inset:0;width:100%;height:100%;pointer-events:none;z-index:-1"></canvas>
  <style>
    /* the hearth burns BEHIND everything and the page stays transparent so it shows
       through; nothing else is repositioned (a rule that raised every body child moved
       the fixed chat panel and made the conversation boxes vanish) */
    html, body { background: transparent !important; }
  </style>
  <script type="module">
    import { startEmbers } from './ember.js';
    startEmbers(document.getElementById('ember-bg'));
  </script>
"""

CAMERA_HOOK = """  <!-- rodd: camera follows the head — one snapshot on a text-only head would poison
       the conversation (the rail answers 500 image-input-not-supported), so the face
       only offers the camera when the head it was raised against can see -->
  <script>
  (function () {
    try {
      var m = new URLSearchParams(location.search).get("camera");
      if (m !== "0" && m !== "1") return;
      var key = "s2s.ws.tools";
      var tools = {};
      try { tools = JSON.parse(localStorage.getItem(key) || "{}") || {}; } catch (e) { tools = {}; }
      tools.camera_snapshot = (m === "1");
      localStorage.setItem(key, JSON.stringify(tools));
      document.documentElement.classList.toggle("rodd-text-only", m !== "1");
      document.documentElement.dataset.roddCamera = m;
    } catch (e) {}
  })();
  </script>
"""

HOUSE_TOOLS_JS = r"""
// ── the house's hands ─────────────────────────────────────────────────────────
// The voice tools are Python doors (bin/voice/voice_tools.py); a browser can only run
// JavaScript, so bin/voice/voice-toolbox.py serves them over loopback and this forwards
// every call to it. Same gates, same log, same refusals.
const TOOLBOX = "http://127.0.0.1:8891";
let HOUSE_TOOLS = [];

async function loadHouseTools() {
  try {
    const res = await fetch(`${TOOLBOX}/tools`, { cache: "no-store" });
    if (!res.ok) return [];
    const body = await res.json();
    HOUSE_TOOLS = (body.tools || []).map((t) => ({
      type: "function", name: t.name, description: t.description,
      parameters: t.parameters || { type: "object", properties: {} },
    }));
    return HOUSE_TOOLS;
  } catch (err) {
    console.warn("[house] toolbox unreachable:", err && err.message ? err.message : err);
    return [];
  }
}

async function runHouseTool(name, args) {
  const res = await fetch(`${TOOLBOX}/tool`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name, arguments: args }),
  });
  const body = await res.json().catch(() => ({}));
  return { output: String(body.output ?? ""), createResponse: body.create_response !== false };
}
loadHouseTools();
"""


def patch_html() -> None:
    p = UI / "index.html"
    s = p.read_text()
    s = re.sub(r"<title>.*?</title>", "<title>Rödd · the voice of Ymir</title>", s, count=1, flags=re.S)
    if "house.css" not in s:
        s = s.replace("</head>", '  <link rel="stylesheet" href="house.css" />\n  </head>', 1)
    if 'rodd: camera follows the head' not in s:
        s = s.replace("<head>", "<head>\n" + CAMERA_HOOK, 1)
    if 'id="ember-bg"' not in s:
        marker = '<script src="vendor/openai-realtime-agents.umd.js"></script>'
        s = s.replace(marker, EMBER + marker, 1)
    s = re.sub(r">Hugging Face Realtime</a>", ">Rödd · the voice of Ymir</a>", s)
    s = re.sub(r'<p class="ident-blurb">.*?</p>',
               '<p class="ident-blurb">Speak with the house — its own ear, its own head, its own voice.</p>',
               s, count=1, flags=re.S)
    # the vendor masthead/footer are the engine's, not the house's (attribution lives in README)
    start = s.find('<div class="ident-meta">')
    if start != -1:
        i = start + len('<div class="ident-meta">')
        depth = 1
        while i < len(s) and depth:
            if s.startswith("<div", i):
                depth += 1; i += 4
            elif s.startswith("</div>", i):
                depth -= 1; i += 6
            else:
                i += 1
        s = s[:start] + s[i:]
    s = re.sub(r"\s*<footer class=\"footer\">.*?</footer>", "", s, count=1, flags=re.S)
    if 'id="voice"' in s:
        s = re.sub(r'<select id="voice">.*?</select>', VOICES, s, flags=re.S)
    p.write_text(s)


def patch_main() -> None:
    p = UI / "main.js"
    s = p.read_text()
    if "HOUSE_TOOLS" not in s:
        anchor = "const STORAGE_KEYS = {"
        s = s.replace(anchor, HOUSE_TOOLS_JS + "\n" + anchor, 1)
        s = s.replace("  if (toolsEnabled.camera_snapshot) defs.push(TOOL_DEFS.camera_snapshot);",
                      "  if (toolsEnabled.camera_snapshot) defs.push(TOOL_DEFS.camera_snapshot);\n"
                      "  for (const t of HOUSE_TOOLS) defs.push(t);", 1)
        s = s.replace('  if (DEBUG) console.debug(`[tool] run name=${name}',
                      '  if (!["web_search", "camera_snapshot"].includes(name)) {\n'
                      '    const house = await runHouseTool(name, args).catch((err) => ({ output: `the toolbox refused: ${err}` }));\n'
                      '    return { output: house.output };\n'
                      '  }\n'
                      '  if (DEBUG) console.debug(`[tool] run name=${name}', 1)
    s = re.sub(r'const DEFAULT_VOICE = "[^"]*";', 'const DEFAULT_VOICE = "af_nicole";', s, count=1)
    s = re.sub(r'const DEFAULT_INSTRUCTIONS = ".*?";',
               'const DEFAULT_INSTRUCTIONS = ' + repr(HOUSE_BRIEF) + ';', s, count=1, flags=re.S)
    s = s.replace('    instructions: localStorage.getItem(STORAGE_KEYS.instructions) || DEFAULT_INSTRUCTIONS,',
                  '    instructions: (() => {\n'
                  '      const saved = localStorage.getItem(STORAGE_KEYS.instructions) || "";\n'
                  '      return /Skírnir|Skirnir/.test(saved) ? saved : DEFAULT_INSTRUCTIONS;\n'
                  '    })(),')
    s = s.replace('role === "user" ? "You" : "Assistant"', 'role === "user" ? "Allfather" : "Skírnir"')
    s = s.replace("camera_snapshot: raw.camera_snapshot ?? true", "camera_snapshot: raw.camera_snapshot ?? true")
    p.write_text(s)


def main() -> int:
    if not (UI / "index.html").is_file():
        print(f"patch-ui: no UI at {UI} — run setup.sh first", file=sys.stderr)
        return 2
    for name in ("house.css", "ember.js"):
        shutil.copy2(HERE / name, UI / name)
    patch_html()
    patch_main()
    print(f"patch-ui: {UI} dressed as Rödd")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
