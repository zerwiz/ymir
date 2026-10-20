#!/usr/bin/env bash
# snotra-render-email.sh — the follow-up letter, generated from the record.
#
#   snotra-render-email.sh <meeting-dir>
#
# Writes email.md (plain text) and email.html (the same letter, designed) beside the
# record. Nothing is hand-maintained: counts, decisions and owners come from record.json.
set -euo pipefail
DIR="${1-}"; [ -n "$DIR" ] && [ -d "$DIR" ] || { echo "usage: snotra-render-email.sh <meeting-dir>" >&2; exit 2; }
python3 - "$DIR" <<'PY'
import sys, os, json, html
d=sys.argv[1]
def operator():
    """Who writes the letter. Identity lives in the hoard, never in this script."""
    base=os.environ.get('YMIR_HOME') or os.path.expanduser('~/Documents/ymirhome')
    path=os.path.join(base,'hodd','identity','operator.yaml')
    out={}
    try:
        for line in open(path,encoding='utf-8'):
            if ':' in line and not line.lstrip().startswith('#'):
                k,v=line.split(':',1); out[k.strip()]=v.strip().strip('"\'')
    except OSError:
        pass
    return out
op=operator()
rec={}
for n in ('record.json','meeting.json'):
    p=os.path.join(d,n)
    if os.path.isfile(p): rec=json.load(open(p,encoding='utf-8')); break
m=rec.get('meeting',rec)
people=rec.get('participants',[])
sender=(m.get('sender') or op.get('name') or 'the organiser')
names=[p.get('name','') for p in people if p.get('name') and p.get('name')!=sender]
first=[n.split()[0] for n in names if n]
title=m.get('title','the meeting'); date=str(m.get('started_at',''))[:10]
decisions=rec.get('decisions',[]); actions=rec.get('actions',[])
by_owner={}
for a in actions: by_owner[a.get('owner') or 'unresolved']=by_owner.get(a.get('owner') or 'unresolved',0)+1
greet=', '.join(first[:-1]) + (' and ' + first[-1] if len(first)>1 else first[0] if first else 'all')
plural='s' if len(actions)!=1 else ''
body=[]
body.append(f"Hi {greet},")
body.append("")
body.append(f"Thank you for {date and 'the'} {title} call. Here is the record of what we decided and who does what next.")
body.append("")
body.append(f"The decisions ({len(decisions)})")
for x in decisions:
    who=x.get('decided_by') or 'unrecorded'
    body.append(f"- {x.get('statement')} ({who})")
qs=rec.get('questions',[])
blocking=[q for q in qs if q.get('blocking')]
if qs:
    body.append("")
    body.append(f"Open questions ({len(qs)}{', ' + str(len(blocking)) + ' blocking' if blocking else ''})")
    for q in qs:
        body.append(f"- {q.get('question')} ({q.get('decider')}{'; by ' + q['needed_by'] if q.get('needed_by') else ''})")
body.append("")
body.append(f"Who does what ({len(actions)} action{plural})")
for who,n in sorted(by_owner.items(), key=lambda kv:(-kv[1],kv[0])):
    body.append(f"- {who} — {n}")
body.append("")
body.append("Attached: the Meeting Record (PDF and Markdown), the raw transcript, the Decision Log, the Action Register, the Dependency Map, and your own brief.")
body.append("")
body.append("Two questions:")
body.append("1. Is the record right — anything missing, misheard or attributed to the wrong person?")
body.append("2. Would you like this after every meeting, or only the ones that decide something — and in this shape: one team record, a short brief of your own actions, or both?")
body.append("")
body.append("A short reply is enough. If the format is wrong, say so plainly.")
body.append("")
body.append("To sign the record, reply `confirm`; to correct it, reply `objection: <what is wrong>`. The record becomes official when the Chair signs it.")
body.append("")
body.append("Best,")
body.append((op.get('name') or sender).split()[0])
body.append("")
body.append("—")
body.append(op.get('name') or sender)
body.append(op.get('company') or op.get('organization') or '')
body.append(op.get('email') or '')
body.append("")
body.append(f"Prepared with Snotra, Ymir's meeting assistant. Reviewed by {op.get('name') or sender}.")
text='\n'.join(body)+'\n'
open(os.path.join(d,'email.md'),'w',encoding='utf-8').write(text)

q_html=''.join(f'<li style="margin:0 0 8px;">{html.escape(q.get("question",""))} <span style="color:#7b8794;font-size:13px;">— {html.escape(q.get("decider") or "unassigned")}{"; by " + html.escape(q["needed_by"]) if q.get("needed_by") else ""}</span></li>' for q in qs)
dec_html=''.join(f'<li style="margin:0 0 9px;"><span style="color:#12263f;">{html.escape(x.get("statement",""))}</span> <span style="color:#7b8794;font-size:13px;">— {html.escape(x.get("decided_by") or "unrecorded")}</span></li>' for x in decisions)
owner_rows=''.join(f'<tr><td style="padding:7px 0;border-bottom:1px solid #edf1f5;color:#243b53;">{html.escape(who)}</td><td style="padding:7px 0;border-bottom:1px solid #edf1f5;text-align:right;color:#12263f;font-weight:600;">{n}</td></tr>' for who,n in sorted(by_owner.items(), key=lambda kv:(-kv[1],kv[0])))
chips=''.join(f'<span style="display:inline-block;margin:0 6px 8px 0;padding:6px 11px;background:#f2f6fa;border:1px solid #dbe4ec;border-radius:14px;font-size:12.5px;color:#243b53;">{html.escape(x)}</span>' for x in ['Meeting Record (PDF)','Raw transcript','Decision Log','Action Register','Open Questions','Dependency Map','Your brief'])
doc=f'''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#eef2f6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#243b53;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#eef2f6;padding:30px 12px;"><tr><td align="center">
<table role="presentation" width="640" cellpadding="0" cellspacing="0" style="width:100%;max-width:640px;background:#ffffff;border-radius:10px;overflow:hidden;box-shadow:0 2px 10px rgba(18,38,63,.08);">
<tr><td style="background:#12263f;padding:26px 34px 24px;">
<div style="color:#9fb3c8;font-size:11.5px;letter-spacing:1.6px;text-transform:uppercase;">Synteon Technologies</div>
<div style="color:#ffffff;font-size:23px;font-weight:600;margin-top:7px;line-height:1.25;">{html.escape(title)}</div>
<div style="color:#9fb3c8;font-size:13px;margin-top:7px;">{html.escape(date)} &nbsp;·&nbsp; {html.escape(', '.join(names))}</div>
</td></tr>
<tr><td style="padding:30px 34px 8px;font-size:15px;line-height:1.62;">
<p style="margin:0 0 15px;">Hi {html.escape(greet)},</p>
<p style="margin:0 0 15px;">Thank you for the {html.escape(title)} call. Here is the record of what we decided and who does what next.</p>
</td></tr>
<tr><td style="padding:8px 34px 0;">
<div style="border-top:1px solid #e5ebf1;padding-top:18px;">
<div style="font-size:12px;letter-spacing:1.2px;text-transform:uppercase;color:#7b8794;margin-bottom:10px;">The decisions ({len(decisions)})</div>
<ul style="margin:0;padding-left:19px;font-size:14.5px;line-height:1.55;">{dec_html}</ul>
</div></td></tr>
{f"""<tr><td style="padding:18px 34px 0;">
<div style="border-top:1px solid #e5ebf1;padding-top:16px;">
<div style="font-size:12px;letter-spacing:1.2px;text-transform:uppercase;color:#7b8794;margin-bottom:10px;">Open questions ({len(qs)})</div>
<ul style="margin:0;padding-left:19px;font-size:14.5px;line-height:1.55;">{q_html}</ul>
</div></td></tr>""" if qs else ""}
<tr><td style="padding:22px 34px 0;">
<div style="background:#f7f9fc;border:1px solid #e2e9f1;border-radius:8px;padding:18px 20px;">
<div style="font-size:12px;letter-spacing:1.2px;text-transform:uppercase;color:#7b8794;margin-bottom:8px;">Who does what ({len(actions)} action{plural})</div>
<table role="presentation" width="100%" style="border-collapse:collapse;font-size:14px;">{owner_rows}</table>
</div></td></tr>
<tr><td style="padding:24px 34px 0;font-size:14.5px;line-height:1.6;">
<p style="margin:0 0 10px;">Attached:</p><div>{chips}</div>
</td></tr>
<tr><td style="padding:20px 34px 0;">
<div style="border-left:3px solid #2f6f8f;background:#f7fafc;padding:16px 18px;font-size:14.5px;line-height:1.55;">
<strong style="color:#12263f;">Two questions</strong>
<ol style="margin:8px 0 0;padding-left:19px;">
<li style="margin:0 0 6px;">Is the record right — anything missing, misheard or attributed to the wrong person?</li>
<li>Would you like this after every meeting, or only the ones that decide something — and in this shape: one team record, a short brief of your own actions, or both?</li>
</ol></div>
</td></tr>
<tr><td style="padding:22px 34px 30px;font-size:14.5px;line-height:1.6;">
<p style="margin:0 0 15px;">A short reply is enough. If the format is wrong, say so plainly.</p>
<p style="margin:0 0 15px;">To sign the record, reply <strong>confirm</strong>; to correct it, reply <strong>objection: &lt;what is wrong&gt;</strong>. The record becomes official when the Chair signs it.</p>
<p style="margin:0 0 3px;">Best,<br>{html.escape((op.get('name') or sender).split()[0])}</p>
<div style="margin-top:22px;padding-top:14px;border-top:1px solid #e5ebf1;color:#7b8794;font-size:12.5px;line-height:1.55;">{html.escape(op.get('name') or sender)}<br>{html.escape(op.get('company') or op.get('organization') or '')} &nbsp;·&nbsp; {html.escape(op.get('email') or '')}</div>
<div style="margin-top:12px;color:#9aa8b6;font-size:11.5px;">Prepared with Snotra, Ymir's meeting assistant. Reviewed by {html.escape(op.get('name') or sender)}.</div>
</td></tr>
</table></td></tr></table></body></html>'''
open(os.path.join(d,'email.html'),'w',encoding='utf-8').write(doc)
print('email.md and email.html written')
PY
