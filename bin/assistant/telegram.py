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
IDENTITY = os.path.join(home(), "hodd", "identity", "assistant")
GROUPS = os.path.join(IDENTITY, "groups.yaml")
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
    """chat id → {tier, members}. The members matter: a group's audience is their INTERSECTION."""
    groups = {}
    try:
        import yaml
        with open(GROUPS) as fh:
            data = yaml.safe_load(fh) or {}
        for row in data.get("groups", []) or []:
            groups[str(row.get("id"))] = {"tier": row.get("tier", "collaborator"),
                                          "members": row.get("members") or [],
                                          "owner_trusted": bool(row.get("owner_trusted"))}
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


def is_owner(sender: dict) -> bool:
    if str(sender.get("id")) == str(OWNER_ID):
        return True
    try:
        import yaml as _y
        ids = (_y.safe_load(open(os.path.join(IDENTITY, "grants.yaml"))) or {}).get("identities") or {}
        return str(ids.get(str(sender.get("username", "")).lstrip("@"), "")) == "owner"
    except Exception:
        return False


def tier_for(chat: dict, sender: dict | None = None) -> tuple[str, str]:
    kind = chat.get("type")
    chat_id = str(chat.get("id"))
    if kind == "private" and str(chat.get("id")) == str(OWNER_ID):
        return "owner", "telegram-dm"
    if kind in ("group", "supergroup"):
        groups = load_groups()
        if chat_id in groups:
            group = groups[chat_id]
            # a group may be declared owner-trusted: the Allfather is the Allfather in it too.
            # Everything he hears there is heard by the whole room — which is why this is opt-in.
            if group.get("owner_trusted") and sender and is_owner(sender or {}):
                return "owner", "telegram-group"
            return group.get("tier", "collaborator"), "telegram-group"
        return "unknown-group", "telegram-group"
    return "stranger", "telegram-dm"


def answer(text: str, tier: str, channel: str, sender: str, chat_id: str = "", sender_id: str = "",
           members: list | None = None) -> str:
    args = [sys.executable, os.path.join(HERE, "skirnir.py"),
            "--tier", tier if tier != "unknown-group" else "stranger",
            "--channel", channel, "--sender", sender, "--text", text,
            "--chat", str(chat_id), "--sender-id", str(sender_id)]
    if members:
        args += ["--group-members", ",".join(members)]
    proc = subprocess.run(args, capture_output=True, text=True, timeout=120)
    for line in proc.stdout.splitlines():
        if line.strip().startswith("{"):
            return json.loads(line).get("answer", "")
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
            msg = update.get("message") or update.get("channel_post") or update.get("edited_message") or {}
            sender = msg.get("from") or {}
            chat = msg.get("chat") or {}
            fwd = msg.get("forward_from_chat") or (msg.get("forward_origin") or {}).get("chat") or {}
            if fwd.get("id"):
                try:
                    seen = json.load(open(SEEN))
                except Exception:
                    seen = {}
                cid = str(fwd.get("id"))
                if cid not in seen:
                    seen[cid] = {"title": fwd.get("title", ""), "seen": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
                                 "learned_from": "a forwarded message"}
                    os.makedirs(STATE, exist_ok=True)
                    json.dump(seen, open(SEEN, "w"), ensure_ascii=False, indent=1)
                    print(f"telegram: learned a chat from a forward — {cid} {fwd.get('title')!r}", file=sys.stderr)
                    try:
                        api("sendMessage", chat_id=chat.get("id"),
                            text=f"Learned that chat: “{fwd.get('title','')}” — id {cid}. "
                                 f"Say `allow {cid}` and I will answer there.",
                            disable_web_page_preview="true")
                    except Exception:
                        pass
            if verbose:
                print(f"telegram: update {update.get('update_id')} kind={[k for k in update if k != 'update_id']} "
                      f"chat={chat.get('id')} type={chat.get('type')} title={chat.get('title')!r}", file=sys.stderr)
            text = msg.get("text") or ""
            if not text or sender.get("is_bot"):
                continue
            # every group or channel he is put in is RECORDED first, before any filter — that is how
            # the Allfather gets a chat id to allowlist instead of guessing one.
            if chat.get("type") in ("group", "supergroup", "channel"):
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

            # `allow <id>` in the owner's DM: the one-word path from a phone
            if chat.get("type") == "private" and is_owner(sender):
                m = __import__("re").match(r"^\s*allow\s+(-?\d{6,})\s*$", text.strip(), __import__("re").I)
                if m:
                    cid = m.group(1)
                    subprocess.run(["bash", os.path.join(HERE, "group-allow.sh"), cid,
                                    "allowed from the owner's DM"], check=False,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    try:
                        api("sendMessage", chat_id=chat.get("id"),
                            text=f"Allowed {cid}. Write there and I will answer.",
                            disable_web_page_preview="true")
                    except Exception:
                        pass
                    continue

            tier, channel = tier_for(chat, sender)
            if chat.get("type") in ("group", "supergroup", "channel"):
                low = text.lower()
                named = any(tok in low for tok in ("skirn", "skirm", "skrin", "skírni", "skirnir",
                                                   "brokk", "ymir", f"@{BOT_USERNAME.lower()}"))
                trusted_owner = (tier == "owner")
                if not (named or trusted_owner):
                    continue
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
                _b = _y.safe_load(open(os.path.join(IDENTITY, "banned.yaml"))) or {}
                if str(chat.get("id")) in {str(x) for x in (_b.get("banned") or [])}:
                    continue
            except Exception:
                pass
            # typing: the Allfather should see that something is happening
            try:
                api("sendChatAction", chat_id=chat.get("id"), action="typing")
            except Exception:
                pass
            members = None
            if chat.get("type") in ("group", "supergroup", "channel"):
                members = (load_groups().get(str(chat.get("id"))) or {}).get("members") or []
            reply = answer(text, tier, channel, sender.get("username", ""), chat.get("id"),
                           sender.get("id", ""), members)
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
