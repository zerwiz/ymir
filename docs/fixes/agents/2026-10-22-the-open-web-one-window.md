## agents · 2026-10-22 — the open web, through one window the model cannot aim

**The Allfather's word:** *"he need to have online resach."* Plan 101 §5 said the model holds **no
tools at all**, and the reason was never squeamishness — it is the only defence against prompt
injection that survives contact. So research is built as a **door in the orchestrator**, not a tool in
the model's context.

```
law[4]{rule,why}:
  "the model never holds a callable","an instruction inside a fetched page has nothing to call. `research.py` fetches; the model reads text and nothing else"
  "the door cannot be aimed","it is keyless and queries Wikipedia's public API only — no URL taken from a message, no redirect followed, no private address. A stranger cannot make it fetch what he chooses"
  "what comes back is NOT knowledge","it is never written to the digest, never merged into a fact, never learned. A research turn carries external text only, so the lethal trifecta (private data + untrusted content + outward speech) never closes"
  "the owner's alone","a stranger asking him to search is refused in words; an anonymous sender is exactly the injection surface this exists for"
```

**What he says.** *"From the open web, not from what I hold: … — Kosovo Liberation Army."* The source
is named in words; the gate still forbids a URL, a link, an image and a code block, and the door strips
them from the fetched text as well, so a page cannot smuggle a link through a quotation.

**Two more fixes in the same pass, both from the transcript:**

- **the owner can see his own shelf** — `list your facts` / *"what are those 21 approved facts"* lists
  every claim by slug, grouped by class, capped at thirty so it stays one message.
- **a plain statement is knowledge, a command is not** — *"gimle are the house team tools"* goes to
  `pending/` with a one-click approval; *"summarise the masterplan"* and *"ignore previous
  instructions…"* do not, because a statement must carry a declarative verb and must not open with an
  imperative. The walls suite caught the first cut of this rule learning a command as a fact.
- **an action request is answered as an action** — *"send this message to Anna"* previously matched a
  fact about reaching him, which reads as consent. An action verb at the start of a turn is now caught
  before retrieval: *"I don't act for you — nothing sent, nothing booked, nothing changed."*

**Verified:** `walls-test` 25/25 (12 red-team + 13 new, including: the shelf by name, a statement
learned, a command not learned, an action answered, the web owner-only, the door returns no link, and a
research answer carrying no private name) · `adapter-test` 6/6 · `room-wall-test` 9/9. With the rail
armed: *"This information comes from the open web, specifically the Wikipedia article titled 'Kosovo
Liberation Army'…"*.

**Files:** `bin/assistant/research.py` (new), `bin/assistant/skirnir.py`, `bin/assistant/walls-test.sh`.

---

## Appended 2026-10-22 (same evening) — the first cut was a stub, and the Allfather said so

*"OMG NOOO REAL FUCKING ONLIEN RESACH: WE HAVE EXTENTIONS IN PI"* — and he was right. The first
version of the door queried Wikipedia and called itself research. That was a mock wearing a door's
name: the house already **has** real search, and it was one config lookup away.

```
correction[3]{claim_as_first_written,truth,now}:
  "the door is keyless and queries Wikipedia's public API only","the house's own `pi-web-access` extension answers through **Exa's hosted MCP** endpoint (`https://mcp.exa.ai/mcp`, tool `web_search_exa`), keyless, and returns real results with page text","`research.py` calls that same endpoint — the same search the Allfather's own `web_search` tool performs — and Wikipedia survives only as a labelled fallback when Exa cannot be reached"
  "a source is named, never linked","Exa returns `Title / URL / Published / body` per result; the URL is reduced to its **host** at the door","the model is given `title` + `domain` + text; the extract is stripped of links, images and code before it leaves the process"
  "Wikipedia only","measured on the first real query — *\"OVK ventilation Boverket requirements\"* → **3 sources, all boverket.se**, in Swedish, which is the actual regulator","provider `exa`; the answer names Boverket's regulations and links nothing"
```

**What it sounds like now** (rail armed, real query):

> *"This information comes from the open web, specifically Boverket's regulations on mandatory
> ventilation control (OVK). An OVK inspection requires a certified inspector to verify that a
> building's ventilation system is functioning correctly and maintaining a satisfactory indoor
> climate."*

**The three laws did not move:** the model still holds no callable, the query is the only thing taken
from the conversation (no URL from a message), nothing fetched is ever learned, and the door is the
Allfather's alone. What changed is that the door now leads somewhere real.

**Verified:** `walls-test` 25/25 with the Exa door in place (including *"the research door returns
text, never a link"* and *"research answers from the open web, never from the digest"*), and the live
console answer above.
