#!/usr/bin/env python3
"""telegram.py — Skírnir's second mouth: his own bot, in DMs and in groups.

    bin/assistant/telegram.py [--once] [--verbose]

One bot, its own token (`SKIRNIR_TELEGRAM_BOT_TOKEN` in the vault), its own identity — never Brokk's.
Who may hear what is decided by the CHAT, not by the message:

    the operator's DM            → owner       (everything the digest and the walls allow)
    an allowlisted group         → collaborator (public facts only; NEVER NDA — a group is other people)
    anyone else                  → stranger    (public facts, and the honest no)

Safety rules, each a line of code:
  * messages from other bots are IGNORED (a bot that answers a bot is a loop);
  * one answer per chat per 5 seconds, 30 an hour;
  * a group must be in `groups.yaml` — an unknown group is not answered at all;
  * the answer comes from skirnir.py, so the four walls apply unchanged.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


def home() -> str:
    env = os.environ.get("YMIR_HOME")
    if env:
        return os.path.expanduser(env)
    lib = os.path.join(ROOT, "bin", "vault", "hoard-lib.sh")
    out = subprocess.run(["bash", "-c",
                          f'. "{lib}" >/dev/null 2>&1; r=""; ymir_home_root r 2>/dev/null; printf "%s" "$r"'],
                         capture_output=True, text=True, timeout=10).stdout.strip()
    if out and os.path.isdir(out):
        return out
    raise SystemExit("telegram: the hoard is unresolved — set YMIR_HOME")


STATE = os.path.join(home(), "hodd", "state", "assistant")
SEEN = os.path.join(STATE, "seen-groups.json")
OFFSET = os.path.join(STATE, "telegram.offset")
GROUPS = os.path.join(STATE, "groups.yaml")
LIMITS = os.path.join(STATE, "telegram.limits.json")
OWNER_ID = os.environ.get("TELEGRAM_OWNER_ID", "")


def vault(key: str) -> str:
    out = subprocess.run(["bash", os.path.join(ROOT, "bin", "vault", "hodd.sh"),
                          "emit", "secrets/platform.env"], capture_output=True, text=True).stdout
    for line in out.splitlines():
        m = re.match(rf"^export {key}=(.*)$", line)
        if m:
            return m.group(1).strip("'\"")
    return ""


TOKEN = os.environ.get("SKIRNIR_TELEGRAM_BOT_TOKEN") or vault("SKIRNIR_TELEGRAM_BOT_TOKEN")
BOT_USERNAME = os.environ.get("SKIRNIR_BOT_USERNAME", "SkirnirymirassistantBot")
if not TOKEN:
    print('telegram[1]{error}: "SKIRNIR_TELEGRAM_BOT_TOKEN is missing from the vault"')
    sys.exit(1)
if not OWNER_ID:
    OWNER_ID = vault("TELEGRAM_OWNER_ID")


API_BASE = os.environ.get("TELEGRAM_API_BASE", "https://api.telegram.org")


def api(method: str, **params):
    url = f"{API_BASE}/bot{TOKEN}/{method}"
    data = urllib.parse.urlencode({k: v for k, v in params.items() if v is not None}).encode()
    with urllib.request.urlopen(urllib.request.Request(url, data=data), timeout=60) as resp:
        return json.load(resp)


def load_groups() -> dict:
    groups = {}
    try:
        import yaml
        with open(GROUPS) as fh:
            data = yaml.safe_load(fh) or {}
        for row in data.get("groups", []) or []:
            groups[str(row.get("id"))] = row.get("tier", "collaborator")
    except Exception:
        pass
    return groups


def allowed(chat_id: str) -> tuple[bool, str]:
    """Rate limits live here so a flood cannot turn him into a nuisance."""
    now = time.time()
    try:
        state = json.load(open(LIMITS))
    except Exception:
        state = {}
    stamps = [t for t in state.get(chat_id, []) if now - t < 3600]
    if stamps and now - stamps[-1] < 5:
        return False, "too fast"
    if len(stamps) >= 30:
        return False, "30/hour in this chat"
    stamps.append(now)
    state[chat_id] = stamps
    os.makedirs(os.path.dirname(LIMITS), exist_ok=True)
    json.dump(state, open(LIMITS, "w"))
    return True, ""


def tier_for(chat: dict) -> tuple[str, str]:
    kind = chat.get("type")
    chat_id = str(chat.get("id"))
    if kind == "private" and str(chat.get("id")) == str(OWNER_ID):
        return "owner", "telegram-dm"
    if kind in ("group", "supergroup"):
        groups = load_groups()
        if chat_id in groups:
            return groups[chat_id], "telegram-group"
        return "unknown-group", "telegram-group"
    return "stranger", "telegram-dm"


def answer(text: str, tier: str, channel: str, sender: str, chat_id: str = "") -> str:
    proc = subprocess.run([sys.executable, os.path.join(HERE, "skirnir.py"),
                           "--tier", tier if tier != "unknown-group" else "stranger",
                           "--channel", channel, "--sender", sender, "--text", text,
                           "--chat", str(chat_id)],
                          capture_output=True, text=True, timeout=120)
    for line in proc.stdout.splitlines():
        if line.strip().startswith("{"):
            return json.loads(line).get("answer", "")
    # never fail silently: the reason goes to the journal, the person gets an honest line
    tail = (proc.stderr or "").strip().splitlines()[-1:] or ["no stderr"]
    print(f"telegram: skirnir.py failed — {tail[0][:200]}", file=sys.stderr)
    return "I'm having trouble answering just now — I'll ask the Allfather."


def main() -> int:
    once = "--once" in sys.argv
    verbose = "--verbose" in sys.argv
    offset = 0
    try:
        offset = int(open(OFFSET).read().strip() or 0)
    except Exception:
        pass
    while True:
        try:
            data = api("getUpdates", offset=offset, timeout=25,
                       allowed_updates=json.dumps(["message"]))
        except Exception as err:
            if verbose:
                print(f"telegram: poll failed: {err}", file=sys.stderr)
            time.sleep(3)
            continue
        for update in data.get("result", []):
            offset = max(offset, update.get("update_id", 0) + 1)
            msg = update.get("message") or {}
            sender = msg.get("from") or {}
            chat = msg.get("chat") or {}
            text = msg.get("text") or ""
            if not text or sender.get("is_bot"):
                continue
            if chat.get("type") in ("group", "supergroup"):
                addressed = ("skirnir" in text.lower()
                             or "skírni" in text.lower()
                             or f"@{BOT_USERNAME.lower()}" in text.lower())
                if not addressed:
                    continue
            # every group he is put in is RECORDED, even while it is not allowed to speak — that is
            # how the Allfather gets a chat id to allowlist instead of guessing one.
            if chat.get("type") in ("group", "supergroup"):
                try:
                    seen = json.load(open(SEEN))
                except Exception:
                    seen = {}
                cid = str(chat.get("id"))
                is_new = cid not in seen
                seen[cid] = {"title": chat.get("title", ""),
                             "seen": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
                os.makedirs(STATE, exist_ok=True)
                json.dump(seen, open(SEEN, "w"), ensure_ascii=False, indent=1)
                if is_new:
                    # a NEW audience: ask before speaking in it. Anyone can add a bot to a group.
                    door = os.path.join(ROOT, "bin", "notify", "send.sh")
                    approve = os.path.join(HERE, "group-allow.sh")
                    if os.path.isfile(door):
                        subprocess.run(["bash", door, "--source", "assistant", "--severity", "MEDIUM",
                                        "--ask", "--key", f"group-allow:{cid}",
                                        "--message",
                                        f"Skírnir was added to a group: “{chat.get('title','')}”. Allow him to answer there?",
                                        "--exec", f"{approve} {cid}"],
                                       check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            tier, channel = tier_for(chat)
            if tier == "unknown-group":
                if verbose:
                    print(f"telegram: ignoring unknown group {chat.get('id')}", file=sys.stderr)
                continue
            ok, why = allowed(str(chat.get("id")))
            if not ok:
                if verbose:
                    print(f"telegram: rate limited ({why})", file=sys.stderr)
                continue
            # a banned chat is not answered at all, and not told why
            try:
                import yaml as _y
                _b = _y.safe_load(open(os.path.join(STATE, "banned.yaml"))) or {}
                if str(chat.get("id")) in {str(x) for x in (_b.get("banned") or [])}:
                    continue
            except Exception:
                pass
            # typing: the Allfather should see that something is happening
            try:
                api("sendChatAction", chat_id=chat.get("id"), action="typing")
            except Exception:
                pass
            reply = answer(text, tier, channel, sender.get("username", ""), chat.get("id"))
            if not reply:
                continue
            try:
                api("sendMessage", chat_id=chat.get("id"), text=reply,
                    reply_to_message_id=msg.get("message_id"),
                    disable_web_page_preview="true")
            except Exception as err:
                if verbose:
                    print(f"telegram: send failed: {err}", file=sys.stderr)
            if verbose:
                print(f"telegram: {tier} asked, answered ({len(reply)} chars)", file=sys.stderr)
        os.makedirs(STATE, exist_ok=True)
        open(OFFSET, "w").write(str(offset))
        open(os.path.join(STATE, "telegram.heartbeat"), "w").write(
            time.strftime("%Y-%m-%dT%H:%M:%S%z"))
        if once:
            return 0


if __name__ == "__main__":
    sys.exit(main())
