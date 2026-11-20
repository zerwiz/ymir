#!/usr/bin/env python3
"""Bing search via curl-reachable HTML, decoding Bing redirect URLs. Prints title|url."""
import re,sys,html,base64,subprocess,urllib.parse
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
def bing(q):
    url="https://www.bing.com/search?"+urllib.parse.urlencode({"q":q,"count":"20"})
    h=subprocess.run(["curl","-sS","-A",UA,url],capture_output=True,text=True,timeout=40).stdout
    out=[]
    for blk in re.findall(r'<li class="b_algo".*?</li>',h,re.S):
        m=re.search(r'<a[^>]+href="([^"]+)"',blk)
        t=re.search(r'<h2[^>]*>(.*?)</h2>',blk,re.S)
        if not m: continue
        u=html.unescape(m.group(1))
        if "bing.com/ck/a" in u:
            mm=re.search(r'[?&]u=a1([^&]+)',u)
            if mm:
                b=mm.group(1); b+="="*(-len(b)%4)
                try: u=base64.urlsafe_b64decode(b).decode('utf-8','replace')
                except Exception: pass
        title=re.sub('<[^>]+>','',t.group(1)) if t else ""
        out.append((html.unescape(title).strip(),u))
    return out
if __name__=="__main__":
    for t,u in bing(sys.argv[1])[:int(sys.argv[2]) if len(sys.argv)>2 else 10]:
        print(f"{t[:70]} | {u[:120]}")
