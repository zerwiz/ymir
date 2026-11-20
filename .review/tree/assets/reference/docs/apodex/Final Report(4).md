The `ApodexAI/AgentHarness` repo is the **official open‑source evaluation harness for Apodex‑1.0 models in a ReAct agent setup**. It is not a TUI, not a general agent platform like Ymir, and not a replacement for pi.dev — it’s the reference pipeline you use to **serve an Apodex model and run deep‑research benchmarks end‑to‑end.**

Below is what it does and how you can meaningfully use it, given your interest in pi.dev and Ymir.

---

## 1. What AgentHarness actually is

From the README:

- Purpose:  
  > “Evaluation harness for Apodex‑1.0 on public deep‑research benchmarks. … used to reproduce the public benchmark results for Apodex‑1.0 in a standard ReAct setup.” [1]

- Benchmarked Apodex‑1.0 variants (open‑source weights) [1]:
  - `Apodex‑1.0‑mini`
  - `Apodex‑1.0‑4B‑SFT`
  - `Apodex‑1.0‑2B‑SFT`
  - `Apodex‑1.0‑0.8B‑SFT`

- Example performance table across four benchmarks (BrowseComp, BrowseComp‑ZH, HLE‑Text, DeepSearchQA) [1]:

  | Model             | BrowseComp | BrowseComp‑ZH | HLE‑Text | DeepSearchQA |
  |-------------------|-----------:|--------------:|---------:|-------------:|
  | Apodex‑1.0‑mini   | 71.5       | 80.6          | 46.8     | 82.2         |
  | Apodex‑1.0‑4B‑SFT | 48.8       | 63.5          | 32.9     | 69.9         |
  | Apodex‑1.0‑2B‑SFT | 27.9       | 35.0          | 18.2     | 49.9         |
  | Apodex‑1.0‑0.8B‑SFT | 13.9     | 10.7          | 11.2     | 25.8         |

- Supported benchmarks include (among others) [1]:
  - BrowseComp, BrowseComp‑ZH
  - xbench‑DeepResearch
  - Humanity’s Last Exam (text‑only)
  - SuperChem
  - FrontierScience‑Research, FrontierScience‑Olympiad
  - DeepSearchQA
  - WideSearch

- License: **Apache 2.0** (permissive; you can copy, modify, and integrate it in commercial or internal systems) [1].

So: AgentHarness is a **reproducible evaluation runner** for a ReAct‑style Apodex agent, plus glue to datasets, search, fetch, and a code sandbox.

---

## 2. What it actually runs (high level)

The README outlines a standard workflow [1]:

1. **Install dependencies**

   Uses `uv` with Python 3.12:

   ```bash
   uv sync --python 3.12
   ```

2. **Serve the model (SGLang)**

   Example command for the 35B Apodex‑1.0 model:

   ```bash
   python3 -m sglang.launch_server \
     --model-path apodex/Apodex-1.0-35B-A3B \
     --tp 8 \
     --host 0.0.0.0 \
     --port 1234 \
     --context-length 262144 \
     --tool-call-parser qwen3_coder \
     --reasoning-parser qwen3
   ```

   This gives you a local, OpenAI‑compatible endpoint for the Apodex model.

3. **Configure environment**

   ```bash
   cp .env.example .env
   ```

   You then set (per README) [1]:

   - `OPENAI_BASE_URL`, `OPENAI_API_KEY`, `OPENAI_MODEL` → point at your served Apodex or any OpenAI‑compatible agent model.
   - `SERPER_API_KEY` → web search.
   - `JINA_API_KEY` → web fetch.
   - `E2B_API_KEY` → code sandbox.

4. **Download benchmark datasets** [1]:

   ```bash
   wget https://huggingface.co/datasets/apodex/Deep-Research-Benchmarks/resolve/main/deep_research_benchmarks_260607.zip
   unzip -P 'apodex*()_2026' deep_research_benchmarks_260607.zip
   rm deep_research_benchmarks_260607.zip
   ```

   Note: HLE answers are *not* redistributed; to run HLE‑Text you must accept the license for `cais/hle` and place the standardized JSONL at:
   `benchmarks/datasets/HLE-text/standardized_data.jsonl` [1].

5. **Run a smoke test** [1]:

   ```bash
   uv run python -m benchmarks.runner.run_subprocess \
     --benchmark browsecomp \
     --pipeline react_base \
     --profile default \
     --limit 1 \
     --concurrency 1 \
     --out ./tmp/smoke
   ```

6. **Run a full benchmark** [1]:

   ```bash
   uv run python -m benchmarks.runner.run_subprocess \
     --benchmark browsecomp \
     --pipeline react_base \
     --profile default \
     --runs 5 \
     --concurrency 30 \
     --out ./bc-runs
   ```

7. **Check progress and aggregate accuracy** [1]:

   ```bash
   uv run python -m benchmarks.runner.check_progress ./bc-runs
   ```

Each question runs in its own subprocess for isolation and debuggability (per README discussion) [1].

---

## 3. How this helps you, concretely

### 3.1 With pi.dev

Your situation:

- You already use **pi.dev**, which is a terminal‑first coding harness that can talk to many providers (including local/OpenAI‑compatible endpoints).

How AgentHarness fits:

1. **Validating a local Apodex endpoint before wiring into pi.dev**

   - Use AgentHarness to **serve** Apodex‑1.0 locally via SGLang and run at least:
     - a smoke test on `browsecomp` and
     - a small subset of one other benchmark.
   - If results are in the expected range from the README’s performance table, you know:
     - your model weights,
     - serving stack, and
     - tool integrations (search, fetch, sandbox)
     are configured correctly.

   Once it’s validated, you can point pi.dev’s “OpenAI‑compatible” provider configuration at the same `OPENAI_BASE_URL`/`OPENAI_MODEL` you used in AgentHarness.

2. **Understanding what “Apodex as a model” actually does**

   - AgentHarness makes it explicit that the Apodex model is being used in a **ReAct agent loop** (tool calls + reasoning) with:
     - web search,
     - web fetch,
     - code execution.
   - That’s very close to how you’d want pi.dev to treat Apodex: not as a dumb completion model, but as a tool‑calling agent. The harness gives you a working example of how that’s wired.

### 3.2 With Ymir

Your earlier questions were about running Apodex (or even its TUI) *inside* Ymir, e.g. as Brokk or Kaia.

AgentHarness’s role relative to Ymir:

1. **Reference “sub‑agent” behavior**

   - The harness shows you a clean, **ReAct‑style agent** around Apodex:
     - structured tool calls to search/fetch/code,
     - bounded concurrent jobs,
     - per‑question subprocesses.
   - In Ymir language, this is close to how an **Eindri** worker in an Utgard sandbox would behave: take a job, call tools, produce a verdict.

2. **Input to designing a Ymir‑compliant worker**

   If you later:
   - keep Ymir as the outer orchestrator (Kaia + Brokk + Mimirsbrunn), and
   - want Apodex as an inner researcher,

   then AgentHarness is essentially a **template** for that inner researcher loop. You would:

   - Preserve Ymir’s laws (Glitnir review, Skuld, append‑only ledger).
   - Adapt the AgentHarness runner’s idea of:
     - “one question = one isolated execution,”
     - reliability under failures/hangs.

   The harness itself does **not** implement Ymir’s ledger, Houses, A2A, or review gates; it’s just a clean, reproducible research runner you can embed under those rules.

---

## 4. What AgentHarness is *not*

To avoid confusion with your previous questions:

- It is **not**:
  - a TUI or chat client.
  - an agent platform with governance (like Ymir).
  - a replacement for pi.dev.

- It **is**:
  - a tested, Apache‑2.0‑licensed **benchmark/evaluation harness** for deep‑research agents built on Apodex‑1.0.
  - a practical way to:
    - serve Apodex locally,
    - confirm it works as intended,
    - and then reuse that same endpoint from tools like pi.dev or Ymir.

---

## 5. Recommended way to use it in your stack

Given everything we’ve discussed:

1. **If your goal is: _“Use Apodex as a strong research agent behind my existing tools”_**

   - Use AgentHarness to:
     - spin up a local Apodex‑1.0 model with SGLang,
     - run the provided smoke test on `browsecomp`,
     - confirm it behaves well on a few benchmark questions.
   - Then:
     - point **pi.dev** at that endpoint for day‑to‑day terminal use,
     - later, if/when you have Ymir access and want to plug Apodex in, reuse the same endpoint and ideas from the harness runner for your Eindri‑style workers.

2. **If your goal is strictly benchmarking**

   - Just run the harness as‑is with your chosen Apodex variant and compare your numbers against the README’s performance table. That tells you whether your hardware/serving stack is behaving as expected.

If you tell me your hardware constraints (e.g., “single 24 GB GPU” vs “multi‑GPU server”) and whether you care more about **reproducible benchmarks** or **integrating as a provider**, I can advise which Apodex‑1.0 variant in the harness is realistic for you and what minimum pieces (search/fetch/sandbox) you should actually turn on.  

---

References  
[1] ApodexAI/AgentHarness: Evaluation harness for Apodex‑1.0 on public deep‑research benchmarks. https://github.com/ApodexAI/AgentHarness