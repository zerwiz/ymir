#!/usr/bin/env python3
"""test_figures — the figures are served through the MCP and never copied into a project. The proof runs the real
server over stdio from a shell INSIDE ANOTHER git repository (a temp one with its own skill), and asserts: the prompts
are listed, `ymir_figure forseti` returns that repository's skill and rules in its kit, and no Ymir file is written
into the repository. The research road runs against fake doors."""
import asyncio
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "bin" / "mcp"))
import figures as fg  # noqa: E402

fails = []


def check(name, ok, got=None):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f" — got {str(got)[:300]!r}"))
    if not ok:
        fails.append(name)


# a repository that is not Ymir
repo = Path(tempfile.mkdtemp())
env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.org", "GIT_COMMITTER_NAME": "t",
       "GIT_COMMITTER_EMAIL": "t@example.org", "HOME": str(repo)}
subprocess.run(["git", "-C", str(repo), "init", "-q"], check=True, env=env)
(repo / ".agents" / "skills" / "demo").mkdir(parents=True)
(repo / ".agents" / "skills" / "demo" / "SKILL.md").write_text(
    "---\nname: demo\ndescription: how to package the widget exporter for release\n---\n\n# Demo\nBody.\n")
(repo / "RULES").mkdir()
(repo / "RULES" / "01-widgets.md").write_text("# widgets are never frozen\n")
(repo / "OUTCOMES.md").write_text("# Outcomes\nThe widget exporter ships weekly.\n")
subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True, env=env)
subprocess.run(["git", "-C", str(repo), "commit", "-qm", "init"], check=True, env=env)
before = sorted(str(p.relative_to(repo)) for p in repo.rglob("*") if ".git" not in p.parts)

# unit: the cards, the ranking, the kit
cards = fg.figure_cards(ROOT)
check("every card is a figure", len(cards) >= 20 and "forseti" in cards and "sindri" in cards, sorted(cards))
check("a judge may not edit, so its tools are the reading doors", cards["forseti"]["read_only"] and
      fg.tools_for(cards["forseti"], ["ymir_where", "ymir_errand", "ymir_veil"]) == ["ymir_where", "ymir_veil"])
check("a figure the task does not need ranks nothing", fg.rank_skills(fg.skills_in(repo, "project"), "paint the fence") == [])
k = fg.kit(ROOT, "forseti", "review the widget exporter release packaging", str(repo), ["ymir_where"], lambda t: "episode: x")
check("the kit names the project's own skill, rules and outcomes",
      any(s["name"] == "demo" and s["scope"] == "project" for s in k["skills"]) and
      k["rules"] == ["RULES/01-widgets.md"] and "ships weekly" in k["outcomes"] and k["well"] == "episode: x", k)
check("an unknown figure names the figures", "error" in fg.kit(ROOT, "nobody", "", str(repo), [], lambda t: ""))
check("a project skill is read through its uri", "# Demo" in fg.read_skill(ROOT, "project", "demo", str(repo)))

# research, with fake doors
calls = []


def post(url, key, body, timeout=90):
    calls.append((url.rsplit("/", 1)[1], body))
    if url.endswith("/search"):
        return {"data": [{"url": "https://example.org/a", "title": "A page"}]}
    return {"data": {"markdown": "# A page\nThe finding, in the page's own words."}}


kept = []


class R:
    returncode, stderr = 0, ""


os.environ["FIRECRAWL_API_URL"], os.environ["FIRECRAWL_API_KEY"] = "https://fc.example.org", "k"
out = fg.research(ROOT, "what is X", "demo", "358", post=post, run=lambda a: kept.append(a) or R())
check("research searches then scrapes only the main content", [c[0] for c in calls] == ["search", "scrape"] and
      calls[1][1]["onlyMainContent"] is True and calls[1][1]["formats"] == ["markdown"], calls)
check("research keeps the finding with source, practice and plan",
      kept and "--source" in kept[0] and "https://example.org/a|A page" in kept[0] and any("plan 358" in x for x in kept[0]), kept)
check("research answers short and says it was kept", "kept in the library" in out and len(out) < 1000, out)
kept.clear()
fg.research(ROOT, "nothing", post=lambda *a, **k: {"data": []}, run=lambda a: kept.append(a) or R())
check("a question nothing answers is kept as a negative result", "--negative" in kept[0], kept)

# the proof from outside: the real server, over stdio, started from the other repository
try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
except ImportError:
    print("skip: the MCP client is missing — the outside proof did not run")
    sys.exit(1 if fails else 0)


async def outside():
    params = StdioServerParameters(command=sys.executable, args=[str(ROOT / "bin" / "mcp" / "ymir-mcp.py")],
                                   cwd=str(repo), env={**os.environ, "YMIR_ROOT": str(ROOT)})
    async with stdio_client(params) as (r, w):
        async with ClientSession(r, w) as s:
            await s.initialize()
            prompts = [p.name for p in (await s.list_prompts()).prompts]
            res = [str(x.uri) for x in (await s.list_resources()).resources]
            tools = [t.name for t in (await s.list_tools()).tools]
            got = await s.call_tool("ymir_figure", {"name": "forseti", "task": "package the widget exporter"})
            pr = await s.get_prompt("forseti")
            skill = await s.read_resource("ymir-skill://project/demo")
            return prompts, res, tools, got.content[0].text, pr.messages[0].content.text, skill.contents[0].text


prompts, res, tools, kit_text, prompt_text, skill_text = asyncio.run(outside())
check("outside: the prompts list Forseti and Sindri", "forseti" in prompts and "sindri" in prompts, prompts[:5])
check("outside: the resources list the repository's own skill", "ymir-skill://project/demo" in res, res[:5])
check("outside: ymir_figure and ymir_research are tools", "ymir_figure" in tools and "ymir_research" in tools, tools[:5])
check("outside: forseti's kit carries THAT repository's skill, rules and outcomes",
      "demo" in kit_text and "RULES/01-widgets.md" in kit_text and "ships weekly" in kit_text, kit_text)
check("outside: the prompt is the card, not a file in the project", "Forseti" in prompt_text, prompt_text)
check("outside: the project skill reads on need", "# Demo" in skill_text, skill_text)
after = sorted(str(p.relative_to(repo)) for p in repo.rglob("*") if ".git" not in p.parts)
check("outside: no Ymir file was written into the repository", before == after, set(after) ^ set(before))
status = subprocess.run(["git", "-C", str(repo), "status", "--porcelain"], capture_output=True, text=True).stdout
check("outside: the repository is still clean", status.strip() == "", status)

print(f"{'FAIL' if fails else 'ok'}: {len(fails)} failed")
sys.exit(1 if fails else 0)
