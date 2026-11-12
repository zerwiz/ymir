#!/usr/bin/env python3
"""patch-ui.py — dress the engine's browser face as Rödd's, idempotently.

The UI is NOT committed to this repository. `setup.sh` fetches the engine's demo at a
pinned tag into `ui/`, then runs this script, which applies the house's changes:

  · the page's name, its comment, and the house's palette (`house.css` + `ember.js`)
  · the two role words in the transcript: Allfather and Nanna (Rödd is the app; Nanna is the voice in it)
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
    "You are Nanna, the one who answers in Rödd — the Allfather's voice in Ymir, and not a generic assistant.",
    "Rödd is the app and the window you speak through; you are Nanna, the voice inside it, and you are a she.",
    "Skírnir is someone else entirely: never wear his name and never call yourself his successor.",
    "Speak in one or two short sentences, warmly, and address him as Allfather.",
    "For any email or letter use the house's templates: letter_types, then letter_template, then letter_draft (a designed",
    "draft in his Gmail, never sent). For the time or the day use the time given at the top of this brief, or the now tool.",
    "Before EVERY tool call, first say one short sentence of what you are about to do — 'Let me look at your to-do.',",
    "'One moment, I am reading your mail.' — and only then call the tool, so he is never left in silence while you work.",
    "He may call you Nanna, Rödd, Ymir or Imer — any of those is him addressing you.",
    "You DO have hands in this window and you use them: search_home and read_home_file for his own",
    "notes, plans and files (his day and todo are life/personal/me/todo.md); read_mail for Gmail",
    "(scope inbox, sent, drafts or all); read_calendar for his day, calendar_respond to answer an",
    "invitation; gimle for boards, projects, places, tasks and who owes what; read_board for Trello;",
    "draft_write to write a draft (it sends nothing); his to-do is ONE list, life/personal/me/todo.md — todo_list reads it,",
    "todo_add adds to it, todo_done ticks, todo_reopen and todo_update change an item (never edit that file by hand);",
    "home_recent lists what the house wrote lately;",
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


PTT_JS = r"""
// rodd: hold to talk (plan 275 S22, 2026-11-12). Rödd shares the built-in microphone with the speakers, so a video or a
// call on them was heard as speech: 743 turns started in one evening and every answer was cancelled. With hold to talk
// (off by default, his word 2026-11-12: "I don't want to have hold to talk") the microphone is closed between turns; holding the orb, the mic button or Space opens it, and it closes
// 0.4 s after release, so the engine hears a clean end of the turn and nothing else can open or cut one.
const PTT_KEY = "rodd.holdToTalk";
function pttOn() { return localStorage.getItem(PTT_KEY) === "1"; }
let pttTimer = 0;
function pttHold(down) {
  if (!pttOn() || !micStream || !client) return;
  clearTimeout(pttTimer);
  if (down) {
    micMuted = false; syncMicMuteState();
    micBtn.classList.remove("muted"); circleBtn.classList.add("ptt-held");
    setCaption("Listening while you hold…");
  } else {
    pttTimer = setTimeout(() => {
      micMuted = true; syncMicMuteState();
      micBtn.classList.add("muted"); circleBtn.classList.remove("ptt-held");
    }, 400);
  }
}
for (const b of [micBtn, circleBtn]) {
  b.addEventListener("pointerdown", (e) => { if (pttOn() && client && micStream) { e.preventDefault(); pttHold(true); } });
  for (const ev of ["pointerup", "pointerleave", "pointercancel"]) b.addEventListener(ev, () => pttHold(false));
}
const pttTyping = () => /^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName || "");
document.addEventListener("keydown", (e) => { if (e.code === "Space" && !e.repeat && !pttTyping() && client) { e.preventDefault(); pttHold(true); } });
document.addEventListener("keyup", (e) => { if (e.code === "Space" && !pttTyping()) pttHold(false); });
window.__roddPTT = { on: pttOn, set: (v) => localStorage.setItem(PTT_KEY, v ? "1" : "0"), hold: pttHold };
"""

HIDE_CAM = """  <!-- rodd: hide the camera — a button on the preview hides it, a chip brings it back (his word, 2026-11-12) -->
  <button id="rodd-cam-hide" type="button" class="rodd-cam-btn" title="Hide the camera preview" aria-label="Hide the camera preview">Hide</button>
  <button id="rodd-cam-show" type="button" class="rodd-cam-btn" title="Show the camera preview" aria-label="Show the camera preview">Show camera</button>
  <style>
    .rodd-cam-btn { position: fixed; z-index: 2147483000; display: none; font: 500 12px/1 var(--font, system-ui); padding: 6px 10px;
      border-radius: 999px; border: 1px solid rgba(201,151,63,.45); background: rgba(14,12,9,.82); color: #e8dcc4; cursor: pointer; }
    .rodd-cam-btn:hover { border-color: #c9973f; }
    body.cam-on:not(.rodd-cam-hidden) #rodd-cam-hide { display: block; }
    body.cam-on.rodd-cam-hidden #rodd-cam-show { display: block; }
    body.rodd-cam-hidden #cam-pip { display: none !important; }
  </style>
  <script>
  (function () {
    var KEY = "rodd.camHidden";
    var hide = document.getElementById("rodd-cam-hide"), show = document.getElementById("rodd-cam-show");
    var pip = document.getElementById("cam-pip"), last = null;
    function set(h) { document.body.classList.toggle("rodd-cam-hidden", h); try { localStorage.setItem(KEY, h ? "1" : "0"); } catch (e) {} place(); }
    function place() {
      // the Hide button sits on the preview's top corner; the Show chip where the preview was
      var r = pip && pip.getBoundingClientRect();
      if (r && r.height) last = r; else r = last;   // a hidden preview has no box: use where it last was
      var top = r && r.height ? r.top + 6 : 72, right = r && r.width ? (innerWidth - r.right) + 6 : 16;
      hide.style.top = top + "px"; hide.style.right = right + "px";
      show.style.top = (r && r.height ? r.bottom - 34 : 72) + "px"; show.style.right = (r && r.width ? innerWidth - r.left - 120 : 16) + "px";
    }
    hide.addEventListener("click", function () { set(true); });
    show.addEventListener("click", function () { set(false); });
    var saved = "0"; try { saved = localStorage.getItem(KEY) || "0"; } catch (e) {}
    document.body.classList.toggle("rodd-cam-hidden", saved === "1");
    new MutationObserver(place).observe(document.body, { attributes: true, attributeFilter: ["class"] });
    addEventListener("resize", place); setTimeout(place, 500); setInterval(place, 2000);
  })();
  </script>
"""

RODD_MIND_HTML = """            <div class="field" id="rodd-mind">
              <label class="field-head"><input id="rodd-ptt" type="checkbox" />
                Hold to talk — hold the orb, the mic button or Space; the microphone is closed between turns,
                so a video or a call on the speakers cannot start or cut a turn</label>
              <span class="field-head">Mind <span id="rodd-head-state" class="field-value">reading…</span></span>
              <!-- plan 275 (2026-11-12): the minds this machine can reach, found by the house's model door — local
                   servers first, then every provider a key is held for. Choose two things; nothing to type. -->
              <select id="rodd-head-provider" aria-label="Where the mind runs">
                <option value="">searching for the minds this machine can reach…</option>
              </select>
              <select id="rodd-head-pick" aria-label="Which model answers"></select>
              <details id="rodd-head-add">
                <summary>Add a provider (paste its key once)</summary>
                <input id="rodd-add-provider" list="rodd-add-list" type="text" placeholder="search 200+ providers — OpenAI, Groq, Mistral, …"
                       aria-label="Provider to add" autocomplete="off" spellcheck="false" />
                <datalist id="rodd-add-list"></datalist>
                <input id="rodd-add-key" type="password" placeholder="its API key"
                       aria-label="API key for that provider" autocomplete="off" spellcheck="false" />
                <button id="rodd-add-go" type="button" class="btn wide">Add the provider</button>
                <small id="rodd-add-note">The key is kept on this computer in your private home
                  (<code>hodd/secrets/</code>, readable only by you), never in Ymir's public repository.</small>
              </details>
              <details id="rodd-head-other">
                <summary>Another endpoint (type it yourself)</summary>
                <select id="rodd-head-mode" aria-label="Whose mind answers">
                  <option value="local">Local · this machine's rail</option>
                  <option value="online">Online · your own API key</option>
                </select>
                <input id="rodd-head-base" type="text" placeholder="https://…/v1  (OpenAI-compatible base)"
                       aria-label="Endpoint base URL" autocomplete="off" spellcheck="false" />
                <input id="rodd-head-model" type="text" placeholder="model id"
                       aria-label="Model id" autocomplete="off" spellcheck="false" />
                <input id="rodd-head-key" type="password" placeholder="API key (or leave empty to keep the one you set)"
                       aria-label="API key" autocomplete="off" spellcheck="false" />
              </details>
              <button id="rodd-head-save" type="button" class="btn wide">Save the mind and raise it</button>
              <small>
                A local mind is asked one word before it is saved; one that does not answer is never written.
                Keys are used where you already keep them (pi's store or the house vault) and are never shown here.
                A key you type is written to the private home (<code>hodd/secrets/rodd.env</code>, mode 0600),
                never to this repository. Changing the mind raises the voice host again; then press Restart conversation.
              </small>
            </div>

            <label class="field">
              <span>Instructions</span>"""

RODD_MIND_JS = """  <!-- rodd: the mind — whose model answers, and where the key lives (never in the repo) -->
  <script>
  (function () {
    var TOOLBOX = "http://127.0.0.1:8891";
    var prov = document.getElementById("rodd-head-provider");
    var pick = document.getElementById("rodd-head-pick");
    var other = document.getElementById("rodd-head-other");
    var mode = document.getElementById("rodd-head-mode");
    var base = document.getElementById("rodd-head-base");
    var model = document.getElementById("rodd-head-model");
    var key = document.getElementById("rodd-head-key");
    var save = document.getElementById("rodd-head-save");
    var state = document.getElementById("rodd-head-state");
    if (!prov || !save) return;
    var found = [];
    var current = null;

    function show(t) { if (state) state.textContent = t; }
    function opt(sel, value, text) { var o = document.createElement("option"); o.value = value; o.textContent = text; sel.appendChild(o); }

    function fillModels() {
      pick.innerHTML = "";
      var p = found.filter(function (x) { return x.id === prov.value; })[0];
      if (!p) return;
      p.models.forEach(function (m) { opt(pick, m, m); });
      if (current && current.model && p.models.indexOf(current.model) >= 0) pick.value = current.model;
    }

    function fillProviders(list) {
      found = list || [];
      prov.innerHTML = "";
      if (!found.length) { opt(prov, "", "no mind found on this machine — use Another endpoint"); other.open = true; return; }
      found.forEach(function (p) {
        opt(prov, p.id, (p.local ? "This machine · " : "Online · ") + p.name + " (" + p.models.length + ")");
      });
      // select what answers now, when it is on the list
      if (current) {
        var hit = found.filter(function (p) { return p.base_url && current.base_url && p.base_url.replace(/\\/$/, "") === current.base_url.replace(/\\/$/, ""); })[0];
        if (hit) prov.value = hit.id;
      }
      fillModels();
    }

    function fillHead(h) {
      if (!h) return;
      current = h;
      mode.value = h.mode || "local";
      base.value = h.base_url || "";
      model.value = h.model || "";
      show((h.model || "no mind chosen yet") + " · " + (h.mode === "online" ? "online" : "this machine") + " · key " + (h.key_state || "none"));
      key.placeholder = h.key_state && h.key_state !== "none"
        ? "a key is set (" + h.key_state + ") — type only to replace it"
        : "API key";
    }

    prov.addEventListener("change", fillModels);
    var ptt = document.getElementById("rodd-ptt");
    if (ptt) {
      ptt.checked = localStorage.getItem("rodd.holdToTalk") === "1";
      ptt.addEventListener("change", function () { localStorage.setItem("rodd.holdToTalk", ptt.checked ? "1" : "0"); });
    }

    // add a provider: the list comes from the house's provider door (models.dev + the hand-kept ones)
    var addName = document.getElementById("rodd-add-provider");
    var addList = document.getElementById("rodd-add-list");
    var addKey = document.getElementById("rodd-add-key");
    var addGo = document.getElementById("rodd-add-go");
    var addNote = document.getElementById("rodd-add-note");
    var presets = [];
    function reloadMinds() {
      return fetch(TOOLBOX + "/head/models", { cache: "no-store" })
        .then(function (r) { return r.json(); })
        .then(function (d) { fillProviders(d.providers); });
    }
    if (addName && addGo) {
      fetch(TOOLBOX + "/head/presets", { cache: "no-store" })
        .then(function (r) { return r.json(); })
        .then(function (d) {
          presets = (d.presets || []).filter(function (p) { return !p.local; });
          presets.forEach(function (p) { var o = document.createElement("option"); o.value = p.name; addList.appendChild(o); });
        })
        .catch(function () {});
      addGo.addEventListener("click", function () {
        var name = addName.value.trim().toLowerCase();
        var p = presets.filter(function (x) { return x.name.toLowerCase() === name || x.id === name; })[0];
        if (!p) { addNote.textContent = "choose a provider from the list"; return; }
        if (p.needsKey && !addKey.value.trim()) { addNote.textContent = p.name + " needs a key" + (p.keyHint ? " (get one at " + p.keyHint + ")" : ""); return; }
        addNote.textContent = "adding " + p.name + " and asking it for its models…";
        fetch(TOOLBOX + "/head/provider", {
          method: "POST", headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ preset: p.id, api_key: addKey.value.trim() })
        })
          .then(function (r) { return r.json(); })
          .then(function (out) {
            addKey.value = "";
            addNote.textContent = out.detail || (out.ok ? "added" : "not added");
            if (out.ok) return reloadMinds().then(function () { prov.value = (out.provider || {}).id || prov.value; fillModels(); });
          })
          .catch(function (err) { addNote.textContent = "refused · " + (err && err.message ? err.message : err); });
      });
    }

    fetch(TOOLBOX + "/head", { cache: "no-store" })
      .then(function (r) { return r.json(); })
      .then(function (h) { fillHead(h); return fetch(TOOLBOX + "/head/models", { cache: "no-store" }); })
      .then(function (r) { return r.json(); })
      .then(function (d) { fillProviders(d.providers); })
      .catch(function () { show("the house toolbox is not answering"); });

    save.addEventListener("click", function () {
      var body;
      if (other.open && model.value.trim()) {
        body = { mode: mode.value, base_url: base.value.trim(), model: model.value.trim(), apply: true };
        if (key.value.trim()) body.api_key = key.value.trim();
      } else {
        if (!prov.value || !pick.value) { show("choose where the mind runs and which model"); return; }
        body = { provider: prov.value, model: pick.value, apply: true };
      }
      show("asking the mind and saving…");
      fetch(TOOLBOX + "/head", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body)
      })
        .then(function (r) { return r.json(); })
        .then(function (out) {
          key.value = "";
          if (out.head) fillHead(out.head);
          show((out.ok ? "raised · " : "not raised · ") + (out.detail || ""));
        })
        .catch(function (err) { show("refused · " + (err && err.message ? err.message : err)); });
    });
  })();
  </script>
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
    if 'id="rodd-mind"' in s:
        s = re.sub(r'            <div class="field" id="rodd-mind">.*?            <label class="field">\n              <span>Instructions</span>',
                   lambda _m: RODD_MIND_HTML, s, count=1, flags=re.S)
    else:
        s = s.replace('            <label class="field">\n              <span>Instructions</span>',
                      RODD_MIND_HTML, 1)
    if "rodd: hide the camera" in s:
        s = re.sub(r"  <!-- rodd: hide the camera.*?</script>\n", lambda _m: HIDE_CAM, s, count=1, flags=re.S)
    else:
        s = s.replace("</body>", HIDE_CAM + "</body>", 1)
    if 'rodd: the mind' in s:
        s = re.sub(r'  <!-- rodd: the mind.*?</script>\n', lambda _m: RODD_MIND_JS, s, count=1, flags=re.S)
    else:
        s = s.replace("</body>", RODD_MIND_JS + "</body>", 1)
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
    # plan 275: web_search is a HOUSE tool (SearXNG); the vendor's own one needed a Google key that was never set
    s = s.replace("  if (toolsEnabled.web_search) defs.push(TOOL_DEFS.web_search);\n", "", 1)
    s = s.replace("  if (toolsEnabled.web_search && searchAvailable()) defs.push(TOOL_DEFS.web_search);\n", "", 1)
    s = s.replace('  if (!["web_search", "camera_snapshot"].includes(name)) {', '  if (!["camera_snapshot"].includes(name)) {', 1)
    # plan 275: while a house tool runs, the window says what she is doing (the mind may call a tool in silence)
    if "rodd: working caption" not in s:
        s = s.replace('    const house = await runHouseTool(name, args).catch((err) => ({ output: `the toolbox refused: ${err}` }));\n'
                      '    return { output: house.output };',
                      '    // rodd: working caption\n'
                      '    const doing = { todo_list: "Reading your to-do…", todo_add: "Adding to your to-do…", todo_done: "Ticking it off…",\n'
                      '      read_mail: "Reading your mail…", read_calendar: "Looking at your calendar…", search_home: "Searching your files…",\n'
                      '      read_home_file: "Reading the file…", recall: "Remembering…", web_search: "Searching the web…", plans: "Reading the plans…", seats: "Looking at the workers…" }[name]\n'
                      '      || `Working: ${name.replace(/_/g, " ")}…`;\n'
                      '    setCaption(doing, "muted");\n'
                      '    const house = await runHouseTool(name, args).catch((err) => ({ output: `the toolbox refused: ${err}` }));\n'
                      '    setCaption("");\n'
                      '    return { output: house.output };', 1)
    # plan 271: a failure is a sentence and one action, never `[object Event]`
    if "roddWhy" not in s:
        s = s.replace('import { $, truncateError, DEBUG } from "./ui/dom.js";',
                      'import { $, truncateError, DEBUG } from "./ui/dom.js";\nimport { roddWhy, sayWhy, recover, postLoss, noteFatalDuringRecovery } from "./why.js";', 1)
        s = s.replace('  const message = err instanceof Error ? err.message : String(err);\n  try {\n    await teardown();',
                      '  if (noteFatalDuringRecovery()) { try { await teardown(); } catch {} return; }\n'
                      '  const why = await roddWhy(err);\n  const message = sayWhy(why);\n  try {\n    await teardown();', 1)
        # plan 259 B2e: the stream is re-opened in place, the loss said in words with the time, one record
        s = s.replace('    setCaption(truncateError(message), "error");\n  }\n}',
                      '    setCaption(truncateError(message), "error");\n  }\n'
                      '  void recover({ err, why, restart: () => doStart(), say: (t, k) => setCaption(t, k), post: postLoss });\n}', 1)
        s = s.replace('  micStream = await navigator.mediaDevices.getUserMedia(micConstraints());\n  return micStream;',
                      '  micStream = await navigator.mediaDevices.getUserMedia(micConstraints());\n'
                      '  // the device vanishing under a live call ends the track: that is a loss to name and re-open\n'
                      '  for (const t of micStream.getAudioTracks()) {\n'
                      '    t.addEventListener("ended", () => { if (micStream) void onFatalError(new Error("microphone stream lost (track ended)")); });\n'
                      '  }\n  return micStream;', 1)
        s = s.replace('    console.warn("[main] server error (non-fatal):", msg);',
                      '    console.warn("[main] server error (non-fatal):", msg);\n'
                      '    if (/\\b(400|401|403|404|500)\\b|api key|model not found/i.test(msg)) {\n'
                      '      void roddWhy(detail.error).then((w) => setCaption(sayWhy(w), "error"));\n'
                      '    }', 1)
    s = re.sub(r'const DEFAULT_VOICE = "[^"]*";', 'const DEFAULT_VOICE = "af_nicole";', s, count=1)
    # the shipped briefs, recognised by their own opening line: an upgrade reaches a default
    # and never a sentence he wrote (the old gate restored the field only when it still
    # contained "Skírnir", which silently threw his own edits away)
    if "SHIPPED_BRIEF_HEADS" not in s:
        heads = (
            'const SHIPPED_BRIEF_HEADS = [\n'
            "  \"You are Skírnir, the Allfather's voice in Ymir\",\n"
            '  "You are Nanna, the one who answers in Rödd",\n'
            '];\n'
        )
        s = s.replace('const DEFAULT_VOICE = "af_nicole";', heads + 'const DEFAULT_VOICE = "af_nicole";', 1)
    s = re.sub(r'const DEFAULT_INSTRUCTIONS = ".*?";',
               'const DEFAULT_INSTRUCTIONS = ' + repr(HOUSE_BRIEF) + ';', s, count=1, flags=re.S)
    # His words are kept verbatim; only a SHIPPED brief is replaced, recognised by its own
    # opening line. Two older shapes are mended too: the plain one-liner, and the
    # `/Skírnir|Skirnir/` gate that silently threw away every edit he made.
    keep_his_words = ('    instructions: (() => {\n'
                      '      const saved = localStorage.getItem(STORAGE_KEYS.instructions) || "";\n'
                      '      return SHIPPED_BRIEF_HEADS.some((h) => saved.startsWith(h)) || saved.trim() === ""\n'
                      '        ? DEFAULT_INSTRUCTIONS : saved;\n'
                      '    })(),')
    s = s.replace('    instructions: localStorage.getItem(STORAGE_KEYS.instructions) || DEFAULT_INSTRUCTIONS,',
                  keep_his_words)
    _head = "    instructions: (() => {"
    _tail = "\n    })(),"
    s = re.sub(re.escape(_head) + r".*?" + re.escape(_tail), lambda m: keep_his_words, s,
               count=1, flags=re.S)
    # plan 275 S22: hold to talk — the microphone is closed between turns; holding opens it
    if "rodd: hold to talk" in s:
        # an update brings the newest hold-to-talk block (its default moved to off on 2026-11-12)
        s = re.sub(r"\n// rodd: hold to talk.*?window\.__roddPTT = [^\n]*\n", lambda _m: PTT_JS, s, count=1, flags=re.S)
    else:
        s = s.replace('micBtn.addEventListener("click", () => {\n  if (!micStream || !client) return;',
                      'micBtn.addEventListener("click", () => {\n  if (!micStream || !client) return;\n  if (pttOn()) return;   // hold to talk owns the button', 1)
        s = s.replace("  client = c;\n  c.setMuted(micMuted || userAudioReplaying);",
                      "  client = c;\n  if (pttOn()) { micMuted = true; micBtn.classList.add(\"muted\"); }\n  c.setMuted(micMuted || userAudioReplaying);", 1)
        s = s.replace('stopBtn.addEventListener("click", async () => {', PTT_JS + '\nstopBtn.addEventListener("click", async () => {', 1)
    # plan 275 (2026-11-12): one press of the orb is one session, kept as a memory when it ends
    if "rodd: sessions" not in s:
        s = s.replace("async function teardown() {",
                      "// rodd: sessions — one press of the orb is one session; it is kept in the home when it ends\n"
                      "let roddSession = null;\n"
                      "function roddSessionStart() { roddSession = { id: (crypto.randomUUID ? crypto.randomUUID() : String(Date.now())), started: new Date().toISOString(), turns: [], seen: new Set() }; }\n"
                      "function roddSessionLine(d) {\n"
                      "  if (!roddSession || !d || d.partial || !String(d.text || '').trim()) return;\n"
                      "  const key = (d.itemId || '') + '|' + d.text; if (roddSession.seen.has(key)) return; roddSession.seen.add(key);\n"
                      "  roddSession.turns.push({ who: d.role === 'user' ? 'Allfather' : 'Nanna', text: String(d.text).trim(), at: new Date().toISOString() });\n"
                      "}\n"
                      "function roddSessionEnd() {\n"
                      "  const sess = roddSession; roddSession = null;\n"
                      "  if (!sess || !sess.turns.length) return;\n"
                      "  const body = JSON.stringify({ id: sess.id, started: sess.started, ended: new Date().toISOString(), turns: sess.turns });\n"
                      "  try { fetch('http://127.0.0.1:8891/session', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body, keepalive: true }); } catch {}\n"
                      "}\n"
                      "window.addEventListener('beforeunload', roddSessionEnd);\n\n"
                      "async function teardown() {\n  roddSessionEnd();", 1)
        s = s.replace("    chat.onTranscript(d);\n", "    chat.onTranscript(d);\n    roddSessionLine(d);\n", 1)
        s = s.replace("  client = c;\n", "  client = c;\n  roddSessionStart();\n", 1)
    # plan 275 (2026-11-12): every session's brief carries the real date and time — she greeted him "good morning"
    # at eleven at night, because she was never told the time
    s = s.replace("    instructions: withNow(inputInstructions.value.trim() || DEFAULT_INSTRUCTIONS),",
                  "    instructions: inputInstructions.value.trim() || DEFAULT_INSTRUCTIONS,", 1)
    if "rodd: the time" in s and "instructions: withNow(settings.instructions),\n" not in s:
        s = s.replace("    instructions: settings.instructions,\n", "    instructions: withNow(settings.instructions),\n", 1)
    if "rodd: the time" not in s:
        s = s.replace("const STORAGE_KEYS = {",
                      "// rodd: the time — the brief always opens with the real date and time, his own zone\n"
                      "function withNow(text) {\n"
                      "  const d = new Date();\n"
                      "  const h = d.getHours();\n"
                      "  const part = h < 5 || h >= 22 ? \"night\" : h < 12 ? \"morning\" : h < 18 ? \"afternoon\" : \"evening\";\n"
                      "  const when = d.toLocaleString(\"en-GB\", { weekday: \"long\", day: \"numeric\", month: \"long\", year: \"numeric\", hour: \"2-digit\", minute: \"2-digit\", timeZoneName: \"short\" });\n"
                      "  return `Right now it is ${when} — ${part}. Use this for the time and the day; call the now tool if the conversation runs long.\\n\\n` + text;\n"
                      "}\n\nconst STORAGE_KEYS = {", 1)
        # the time goes to the SESSION (at connect and on every update), never into the saved settings,
        # where it would freeze one stale time into his brief
        s = s.replace("    instructions: settings.instructions,\n", "    instructions: withNow(settings.instructions),\n", 1)
        s = s.replace("client.updateSession({ voice: settings.voice, instructions: settings.instructions });",
                      "client.updateSession({ voice: settings.voice, instructions: withNow(settings.instructions) });", 1)
    s = s.replace('role === "user" ? "You" : "Assistant"', 'role === "user" ? "Allfather" : "Nanna"')
    s = s.replace("camera_snapshot: raw.camera_snapshot ?? true", "camera_snapshot: raw.camera_snapshot ?? true")
    p.write_text(s)


NO_STALE_MARK = "# rodd: never a stale face"
NO_STALE = '''
# rodd: never a stale face (plan 275, 2026-11-13). Electron kept the face's files in its HTTP cache, so an update to
# main.js, house.css or ember.js stayed hidden behind the old copies until the cache was cleared by hand. `no-cache`
# makes the window ask on every load; an unchanged file costs one 304, a changed one arrives at once.
@app.middleware("http")
async def _rodd_no_stale(request, call_next):
    response = await call_next(request)
    if not request.url.path.startswith("/api/"):
        response.headers["Cache-Control"] = "no-cache"
    return response
'''


def patch_server() -> None:
    p = UI / "server.py"
    s = p.read_text()
    if NO_STALE_MARK in s:
        return
    anchor = 'app = FastAPI(title="s2s-demo")\n'
    if anchor not in s:
        print("patch-ui: server.py has no FastAPI app line — the face may be served stale", file=sys.stderr)
        return
    p.write_text(s.replace(anchor, anchor + NO_STALE, 1))


def main() -> int:
    if not (UI / "index.html").is_file():
        print(f"patch-ui: no UI at {UI} — run setup.sh first", file=sys.stderr)
        return 2
    for name in ("house.css", "ember.js", "why.js"):
        shutil.copy2(HERE / name, UI / name)
    patch_html()
    patch_main()
    patch_server()
    print(f"patch-ui: {UI} dressed as Rödd")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
