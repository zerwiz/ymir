#!/usr/bin/env bash
# mill-worker.sh — Grótti on whynot (the heart). Classes:
#   well-digest      local Qwen summarizes the well, then SPEAKS it (piper)
#   index-derivative embed the well's episodes on the stone (:8500) -> vector-index.jsonl
#   recall-rag       embed a query, cosine over the index, observe the top hits
#   code-review      review a git range on the local model -> ~/mill/reviews/
set -u
Q=mill:jobs
log() { printf '[mill] %s\n' "$*"; }

vec_of() { # <json-file> -> "[-0.03,0.01,...]" (first 120 dims), empty on error
  python3 -c "import json,sys
try:
    r=json.load(open(sys.argv[1]))
    e=r[0]['embedding'] if isinstance(r,list) and r else r.get('embedding',[])
    vec=e[0] if e and isinstance(e[0],list) else e
    print(json.dumps([round(x,6) for x in vec[:120]]))
except Exception as ex:
    print('', file=sys.stderr)" "$1" 2>/dev/null
}

while true; do
  job="$(command -v redis-cli >/dev/null && timeout 300 redis-cli --raw blpop "$Q" 300 2>/dev/null | sed -n 2p || true)"
  [ -n "${job:-}" ] || continue
  class="$(python3 -c "import sys,json
try: print(json.loads(sys.stdin.read()).get('class',''))
except Exception: print('')" <<<"$job" 2>/dev/null)"
  scope="$(python3 -c "import sys,json
try: print(json.loads(sys.stdin.read()).get('scope',5))
except Exception: print(5)" <<<"$job" 2>/dev/null)"
  case "$class" in
    well-digest)
      h="$(curl -s --max-time 5 http://127.0.0.1:4602/health)"
      recent="$(curl -s --max-time 5 "http://127.0.0.1:4602/recent?limit=$scope")"
      eval "$(cd ~/Documents/ymirhome && ~/ymir/bin/hodd.sh emit secrets/platform.env 2>/dev/null)"
      prompt="Summarize the Ymir well's recent state in 3 terse lines (what stands, what is open). Well health: ${h:0:120} Recent: ${recent:0:400}"
      body="$(python3 -c "import json,sys;print(json.dumps({'model':'qwen3.6-35b-a3b','messages':[{'role':'user','content':sys.argv[1]}],'max_tokens':200}))" "$prompt")"
      reply="$(curl -s --max-time 180 http://127.0.0.1:8080/v1/chat/completions -H "Authorization: Bearer ${LLAMA_SWAP_API_KEY:-}" -H "Content-Type: application/json" -d "$body")"
      text="$(python3 -c "import sys,json
try: print(json.load(sys.stdin.read())['choices'][0]['message']['content'])
except Exception: print('llm-error')" <<<"$reply" 2>/dev/null)"
      curl -s --max-time 5 -X POST http://127.0.0.1:4602/observe -H "content-type: application/json" \
        -d "$(python3 -c "import json,sys;print(json.dumps({'content':'[mill] well-digest: '+sys.argv[1],'tags':'mill,digest','actors':'grotti'}))" "$text")" >/dev/null 2>&1
      mkdir -p ~/mill/voice
      (printf '%s' "$text" | ~/.venvs/well/bin/piper -m ~/mill/voices/en_US-lessac-medium.onnx -f ~/mill/voice/digest-$(date +%H%M%S).wav >/dev/null 2>&1) || true
      log "well-digest ground + voiced: ${text:0:60}"
      ;;
    index-derivative)
      curl -s --max-time 8 "http://127.0.0.1:4602/recent?limit=$scope" > /tmp/idx.json 2>/dev/null
      python3 -c "import json
d=json.load(open('/tmp/idx.json'))
eps=d if isinstance(d,list) else d.get('episodes',[])
open('/tmp/eps.txt','w').write('\n'.join((e.get('content') or '')[:400] for e in eps[:10]))" 2>/dev/null || true
      n=0
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        curl -s --max-time 25 -X POST http://127.0.0.1:8500/embedding -H "Content-Type: application/json" \
          -d "$(python3 -c "import json,sys;print(json.dumps({'content':sys.argv[1]}))" "$line")" > /tmp/e.json 2>/dev/null
        v="$(vec_of /tmp/e.json)"
        [ -n "$v" ] || v="[]"
        dims="$(python3 -c "import sys,json
try: print(len(json.loads(sys.argv[1])))
except Exception: print(0)" "$v" 2>/dev/null)"
        h="$(printf '%s' "$line" | sha1sum | cut -c1-12)"
        c="$(python3 -c "import sys,json;print(json.dumps(sys.stdin.read()))" <<<"$(printf '%s' "$line" | head -c 160)" 2>/dev/null)"
        echo "{\"hash\":\"$h\",\"dims\":${dims:-0},\"ts\":$(date +%s),\"c\":$c,\"v\":$v}" >> ~/mill/vector-index.jsonl
        n=$((n+1))
      done < /tmp/eps.txt
      metric="$(wc -l < ~/mill/vector-index.jsonl 2>/dev/null || echo 0)"
      curl -s --max-time 6 -X POST http://127.0.0.1:4602/observe -H "content-type: application/json" \
        -d "$(python3 -c "import json;print(json.dumps({'content':'[mill] derivative: indexed $n more, index at $metric vectors','tags':'mill,derivative','actors':'grotti'}))")" >/dev/null 2>&1
      log "index-derivative: index now $metric vectors ($n this turn)"
      ;;
    recall-rag)
      query="$(python3 -c "import sys,json
try: print(json.loads(sys.stdin.read()).get('query',''))
except Exception: print('')" <<<"$job" 2>/dev/null)"
      curl -s --max-time 25 -X POST http://127.0.0.1:8500/embedding -H "Content-Type: application/json" \
        -d "$(python3 -c "import json,sys;print(json.dumps({'content':sys.argv[1]}))" "$query")" > /tmp/q.json 2>/dev/null
      best="$(python3 -c "import json, math, sys
qv=json.loads(sys.argv[1]) if sys.argv[1:] else []
lines=[l for l in open('/home/whynot/mill/vector-index.jsonl') if l.strip()]
best=[]
for l in lines:
    try:
        d=json.loads(l); v=d.get('v',[]); c=d.get('c','')
        if not v: continue
        dot=sum(a*b for a,b in zip(qv,v)); na=math.sqrt(sum(x*x for x in qv)) or 1; nb=math.sqrt(sum(x*x for x in v)) or 1
        best.append((dot/(na*nb),c))
    except Exception: pass
best.sort(reverse=True)
print(' | '.join(x[1] for x in best[:2]))" "$(vec_of /tmp/q.json)" 2>/dev/null)"
      if [ -n "$best" ]; then
        curl -s --max-time 6 -X POST http://127.0.0.1:4602/observe -H "content-type: application/json" \
          -d "$(python3 -c "import json,sys;print(json.dumps({'content':'[mill] recall: '+sys.argv[1][:200],'tags':'mill,recall','actors':'grotti'}))" "$best")" >/dev/null 2>&1
        log "recall-rag: top hit — ${best:0:70}"
      else
        log "recall-rag: no hits (index empty?)"
      fi
      ;;
    code-review)
      repo="$(python3 -c "import sys,json
try: print(json.loads(sys.stdin.read()).get('repo','/home/whynot/ymir'))
except Exception: print('/home/whynot/ymir')" <<<"$job" 2>/dev/null)"
      range="$(python3 -c "import sys,json
try: print(json.loads(sys.stdin.read()).get('range','HEAD~5..HEAD'))
except Exception: print('HEAD~5..HEAD')" <<<"$job" 2>/dev/null)"
      logline="$(git -C "$repo" log --oneline "$range" 2>/dev/null | head -8)"
      diffstat="$(git -C "$repo" diff "$range" --stat 2>/dev/null | tail -14)"
      eval "$(cd ~/Documents/ymirhome && ~/ymir/bin/hodd.sh emit secrets/platform.env 2>/dev/null)"
      prompt="Review this git range tersely (risks, standards drift, what to seal). Log: ${logline} Diff stat: ${diffstat}"
      body="$(python3 -c "import json,sys;print(json.dumps({'model':'qwen3.6-35b-a3b','messages':[{'role':'user','content':sys.argv[1]}],'max_tokens':220}))" "$prompt")"
      reply="$(curl -s --max-time 180 http://127.0.0.1:8080/v1/chat/completions -H "Authorization: Bearer ${LLAMA_SWAP_API_KEY:-}" -H "Content-Type: application/json" -d "$body")"
      text="$(python3 -c "import sys,json
try: print(json.load(sys.stdin.read())['choices'][0]['message']['content'])
except Exception: print('llm-error')" <<<"$reply" 2>/dev/null)"
      mkdir -p ~/mill/reviews
      f=~/mill/reviews/$(date +%Y%m%d-%H%M%S).md
      { printf '# Review (%s, %s)\n\n' "$range" "$(basename "$repo")"; printf '%s\n' "$text"; } > "$f"
      curl -s --max-time 6 -X POST http://127.0.0.1:4602/observe -H "content-type: application/json" \
        -d "$(python3 -c "import json,sys;print(json.dumps({'content':'[mill] review: '+sys.argv[1][:140],'tags':'mill,review','actors':'grotti'}))" "$text")" >/dev/null 2>&1
      log "code-review: $f written"
      ;;
    *) log "unknown job class: $class" ;;
  esac
done