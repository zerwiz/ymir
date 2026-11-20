#!/usr/bin/env python3
"""Minimal stdlib HTML -> markdown-ish text extractor for EC pages."""
import re, sys
from html.parser import HTMLParser

SKIP = {"script","style","noscript","svg","nav","header","footer","form","iframe","template"}
BLOCK = {"p","div","section","article","tr","br","hr","table","ul","ol","blockquote","main"}

class Ex(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out=[]; self.skip=0; self.h=None; self.a=None; self.abuf=[]
    def handle_starttag(self,tag,attrs):
        t=tag.lower()
        if t in SKIP: self.skip+=1; return
        if self.skip: return
        if re.fullmatch(r"h[1-6]",t): self.h=int(t[1]); self.out.append("\n\n"+"#"*self.h+" ")
        elif t=="li": self.out.append("\n- ")
        elif t=="br": self.out.append("\n")
        elif t=="a":
            d=dict(attrs); self.a=d.get("href"); self.abuf=[]
        elif t in BLOCK: self.out.append("\n")
    def handle_endtag(self,tag):
        t=tag.lower()
        if t in SKIP:
            if self.skip: self.skip-=1
            return
        if self.skip: return
        if re.fullmatch(r"h[1-6]",t): self.h=None; self.out.append("\n")
        elif t=="a":
            if self.a and self.abuf:
                txt="".join(self.abuf).strip()
                href=self.a
                if href.startswith("/"): href="https://"+self.base+href
                if txt and not href.startswith("#") and not href.startswith("javascript"):
                    self.out.append(f" [{txt}]({href}) ")
            self.a=None; self.abuf=[]
        elif t in BLOCK: self.out.append("\n")
    def handle_data(self,d):
        if self.skip: return
        if self.a is not None:
            self.abuf.append(d)
        else:
            self.out.append(d)
    def text(self,base):
        self.base=base
        s="".join(self.out)
        s=re.sub(r"[ \t\r\f\v]+"," ",s)
        s=re.sub(r" ?\n ?","\n",s)
        s=re.sub(r"\n{3,}","\n\n",s)
        return s.strip()

if __name__=="__main__":
    p=sys.argv[1]; base=sys.argv[2] if len(sys.argv)>2 else "example.com"
    raw=open(p,encoding="utf-8",errors="replace").read()
    e=Ex()
    try: e.feed(raw)
    except Exception: pass
    print(e.text(base))
