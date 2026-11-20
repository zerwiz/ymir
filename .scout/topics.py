#!/usr/bin/env python3
import json,sys,urllib.request,urllib.parse
BASE="https://api.tech.ec.europa.eu/search-api/prod/rest/search"
def q(text,page,size=100):
    u=BASE+"?"+urllib.parse.urlencode({"apiKey":"SEDIA","text":text,"pageSize":size,"pageNumber":page,"sort":"es_SortDate:desc"})
    r=urllib.request.Request(u,data=b'{"bool":{"must":[]}}',headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    with urllib.request.urlopen(r,timeout=90) as f: return json.loads(f.read().decode())
seen={}
for text in sys.argv[1:]:
    try: d=q(text,1)
    except Exception as e: print("ERR",text,e); continue
    for r in d.get("results",[]):
        m=r.get("metadata",{}) or {}
        if (m.get("type") or [""])[0] != "1": continue
        key=(m.get("callIdentifier") or [""])[0]+"|"+str((m.get("title") or [""])[0])[:40]
        if key in seen: continue
        seen[key]=1
        st=(m.get("status") or [""])[0]
        dl=(m.get("deadlineDate") or [""])
        dl=dl[0] if isinstance(dl,list) and dl else dl
        print(json.dumps({"q":text,"title":(m.get("title") or [""])[0][:80],
            "call":(m.get("callIdentifier") or [""])[0],"status":st,"deadline":str(dl)[:10],
            "url":r.get("url","")},ensure_ascii=False))
