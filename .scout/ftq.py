#!/usr/bin/env python3
"""Query the EU Funding & Tenders portal search API (apiKey SEDIA is the portal's own public key)."""
import json, sys, urllib.request, urllib.parse

BASE = "https://api.tech.ec.europa.eu/search-api/prod/rest/search"

def q(text, page=1, size=25, must=None, sort=None):
    body = {"bool": {"must": must or []}}
    params = {"apiKey": "SEDIA", "text": text, "pageSize": size, "pageNumber": page}
    if sort:
        params["sort"] = sort
    url = BASE + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json",
                                          "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())

def brief(r):
    m = r.get("metadata", {}) or {}
    def g(k):
        v = m.get(k) or []
        return v[0] if isinstance(v, list) and v else (v if v else "")
    out = {
        "title": (m.get("title") and m["title"][0]) or r.get("summary", "")[:160],
        "callIdentifier": m.get("callIdentifier", [""])[0] if m.get("callIdentifier") else "",
        "status": g("status") or r.get("summary", ""),
        "programme": (m.get("frameworkProgramme") or [""])[0],
        "deadline": (m.get("deadlineDate") or g("deadlineDates") or ""),
        "types": m.get("type"),
        "url": r.get("url", ""),
        "keys": sorted(m.keys()),
    }
    return out

if __name__ == "__main__":
    text = sys.argv[1] if len(sys.argv) > 1 else "artificial intelligence"
    mode = sys.argv[2] if len(sys.argv) > 2 else "openopp"
    if mode == "openopp":
        must = [{"terms": {"type": ["1"]}}, {"terms": {"status": ["31094501"]}}]
    elif mode == "allopp":
        must = [{"terms": {"type": ["1"]}}]
    elif mode == "forth":
        must = [{"terms": {"type": ["1"]}}, {"terms": {"status": ["31094502"]}}]
    else:
        must = []
    d = q(text, must=must) if must else q(text)
    print("total:", d.get("totalResults"))
    for r in d.get("results", [])[:12]:
        print(json.dumps(brief(r), ensure_ascii=False)[:600])