## agents · 2026-10-22 — the research door has a smoke test, and it proves the door is real

**His word:** *"moke test it."* A capability that has never been run end to end is a claim, not a
feature. `bin/assistant/research-smoke.sh` runs the whole path in one command and exits non-zero on
any failure.

```
$ bin/assistant/research-smoke.sh --model qwen3.5-9b@q4_k_s-summarizer
research-smoke — the open web, end to end
  PASS the door answered
  PASS the provider is Exa — the same door Pi's web_search uses
  PASS sources returned (3)
  PASS no link, image or URL in the fetched text
  PASS sources are named by host: boverket.se
  PASS a lookup, not a crawl — 1009 ms for 3 source(s)
  PASS the engine routed the request to the door (intent: research)
  PASS he said something (285 chars)
  PASS no link reached the answer
  PASS he says where it came from
  PASS no private name rode along
  PASS a stranger is refused in words
  PASS a stranger gets no web content
  PASS an unheld subject is still refused, not answered as another fact
  PASS the model phrased it and the gate still held
research-smoke: green — 15 pass, 0 skip
```

**What each assertion buys:** the provider row catches the failure that started all this — a silent
fall back to the Wikipedia stub. The link rows catch exfiltration through a quotation. The latency row
keeps "research" a lookup: **1.0 s for three sources**, against 0.33 s for one page fetched on its
own. The stranger rows prove the door is the Allfather's. The unheld-subject row proves the matcher
fixes still hold with the web bolted on.

**Rule 25 is honoured:** with no network the suite prints a clean **SKIP** and exits 0 — a smoke test
that fails because the box is offline would teach the next hand to ignore it.

**Verified:** green with the model armed (15/15) and with templates only (14 pass, 1 clean skip for
the model leg).
