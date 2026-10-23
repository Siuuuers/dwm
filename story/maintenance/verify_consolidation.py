#!/usr/bin/env python3
"""Validate current working links; optionally validate this curation's frozen snapshot.

The snapshot is evidence of an editorial operation, not a restriction on later
owner-authorized changes. No fetch, push, merge or deletion is performed here.
Run: python story/maintenance/verify_consolidation.py --root . --snapshot
"""
from __future__ import annotations
import argparse, hashlib, json, posixpath, re, subprocess, sys
from pathlib import Path
from urllib.parse import unquote

def sha(data):return hashlib.sha256(data).hexdigest()
def active(text):
    out=[];mark=None;length=0
    for line in text.splitlines(keepends=True):
        if mark:
            if re.match(r'^ {0,3}'+re.escape(mark)+'{'+str(length)+r',}\s*$',line):mark=None
        else:
            m=re.match(r'^ {0,3}(`{3,}|~{3,})',line)
            if m:mark=m.group(1)[0];length=len(m.group(1))
            else:out.append(line)
    return ''.join(out)
def anchors(text):
    t=active(text);out=set(re.findall(r'<a\s+(?:id|name)="([^"]+)"',t));counts={}
    for line in t.splitlines():
        m=re.match(r'^#{1,6}\s+(.+?)\s*#*$',line)
        if m:
            key=re.sub(r'[^\w\-\s]','',re.sub(r'<[^>]*>','',m.group(1)).lower()).strip().replace(' ','-')
            n=counts.get(key,0);out.add(key+('' if n==0 else '-'+str(n)));counts[key]=n+1
    return out

def verify(root,known_tree=None,snapshot=False):
    root=Path(root);m=json.loads((root/'story/maintenance/source-migration.json').read_text());passed=[];errors=[]
    def check(name,fn):
        try:
            if fn() is False:raise AssertionError('check false')
            passed.append(name)
        except Exception as e:errors.append({'check':name,'error':str(e)})
    local={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and '.git' not in p.parts}
    known=set(local)
    if known_tree:
        known|={line.split('\t',1)[-1] for line in Path(known_tree).read_text().splitlines()}
    elif (root/'.git').exists():
        known|=set(subprocess.check_output(['git','-C',str(root),'ls-files'],text=True).splitlines())
    check('no legacy source directory',lambda:not any(p.startswith('docs/story-auditions/') for p in local))
    check('no replacement raw source directory',lambda:not any(p.startswith('story/sources/') for p in local))
    check('root story routing retained',lambda:'story/AGENTS.md' in (root/'AGENTS.md').read_text())
    g=(root/'story/AGENTS.md').read_text()
    check('four-exchange cadence retained',lambda:'four substantive user-and-assistant exchanges' in g)
    check('selection rather than transcript rule',lambda:'Capture useful development, not the exchanges themselves.' in g)
    nlinks=0; broken=[]
    # All story and design files in a full checkout; this snapshot's compact export may omit unchanged targets.
    for name in sorted(local):
        if not name.endswith('.md') or name not in m['reviewed_markdown_paths']:continue
        for mat in re.finditer(r'\[[^\]\n]*\]\(([^\n)]+)\)',active((root/name).read_text())):
            url=mat.group(1).split(' "',1)[0].strip('<>')
            if re.match(r'^[A-Za-z][A-Za-z0-9+.-]*:',url) or url.startswith('//'):continue
            nlinks+=1;p,sep,frag=url.partition('#');p=unquote(p)
            dest=posixpath.normpath(posixpath.join(posixpath.dirname(name),p)) if p else name
            exists=dest in known or any(s.startswith(dest.rstrip('/')+'/') for s in known)
            if not exists:broken.append((name,url,'missing target'))
            elif sep and dest.endswith('.md') and (root/dest).exists() and unquote(frag) not in anchors((root/dest).read_text()):broken.append((name,url,'missing anchor'))
            if dest.startswith('docs/story-auditions/'):broken.append((name,url,'active legacy dependency'))
    check('working Markdown links',lambda:not broken)
    if broken:errors.append({'check':'link detail','error':broken})
    if snapshot:
        for e in m['selected_excerpts']:
            def item(e=e):
                t=(root/e['destination']).read_text();a='<!-- BEGIN CURATED '+e['id']+' -->\n';z='\n<!-- END CURATED '+e['id']+' -->'
                assert t.count(a)==t.count(z)==1
                q=t.split(a,1)[1].split(z,1)[0];assert sha(q.encode())==e['sha256']
            check('selected excerpt '+e['id'],item)
        for b in m['protected_blocks']:
            def item(b=b):
                t=(root/b['path']).read_text()
                if b['kind']=='current_scene':q=re.search(r'(?s)## (?:1\. )?Current assembled passage\n(.*?)(?=\n## )',t).group(1)
                elif b['kind']=='handbook_pair':q=t.split('<!-- BEGIN TRANSFERRED HANDBOOK PAIR -->\n',1)[1].split('\n<!-- END TRANSFERRED HANDBOOK PAIR -->',1)[0]
                else:q=t.split(b['end_marker'],1)[0]+b['end_marker']
                assert sha(q.encode())==b['sha256']
            check('protected '+b['kind']+' '+b['path'],item)
        for a in m['retained_auditions']:check('unchanged audition '+a['path'],lambda a=a:sha((root/a['path']).read_bytes())==a['sha256'])
        rel=(root/'story/relationships/priscilla-lavinia/relationship.md').read_text()
        check('scoped intervention correction',lambda:'This is not a rule that she can never recognize wrongdoing in any other context.' in rel)
        ref=(root/'story/relationships/priscilla-lavinia/auditions/day-6-sweet-ambiguous-refusal.md').read_text()
        dark=(root/'story/relationships/priscilla-lavinia/auditions/day-6-dark-notebook.md').read_text()
        check('Sweet exact phrases retained',lambda:'I wouldn’t say ‘much.’' in ref and 'I tried it your way. I like it stronger now.' in ref)
        check('Dark does not repeat Sweet performance',lambda:'much' not in re.search(r'(?s)## 1\. Current assembled passage\n(.*?)(?=\n## )',dark).group(1).lower())
        for path in [b['path'] for b in m['protected_blocks'] if b['kind']=='current_scene']:
            check('unselected scene '+path,lambda path=path:'UNSELECTED' in (root/path).read_text()[:1500] and 'REACTION TEST' in (root/path).read_text()[:1500])
        check('no former full-response markers',lambda:all(not re.search(r'<!-- (?:BEGIN SOURCE|EXACT OUR-PL|BEGIN EMBEDDED)',(root/p).read_text()) for p in local if p.endswith('.md') and p.startswith('story/')))
    return {'passed':len(passed),'failed':len(errors),'checks':passed,'errors':errors,'relative_links_checked':nlinks,'snapshot_checked':snapshot,'selected_passages':len(m['selected_excerpts']),'limits':['No literary/performance/medical/runtime test','External URL anchors not checked','Missing earlier history not reconstructed']}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',default='.');p.add_argument('--known-tree');p.add_argument('--snapshot',action='store_true');p.add_argument('--report');a=p.parse_args()
    r=verify(a.root,a.known_tree,a.snapshot)
    if a.report:Path(a.report).write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in r.items() if k!='checks'},ensure_ascii=False,indent=2));sys.exit(bool(r['failed']))
