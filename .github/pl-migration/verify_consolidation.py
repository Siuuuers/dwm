#!/usr/bin/env python3
"""Check narrative-migration integrity. Does not evaluate literary quality or merge.

python story/maintenance/verify_consolidation.py --root . --source-dir /tmp/source \
  --upload /tmp/Our_PL.md --report /tmp/report.json

Without --source-dir/--upload, exact originals are read with git show at the
retained revisions named by the manifest. No fetch, push or network write occurs.
"""
from __future__ import annotations
import argparse,hashlib,json,re,posixpath,subprocess,sys
from pathlib import Path
from urllib.parse import unquote
OLD='docs/story-auditions/'
MANIFEST='story/maintenance/source-migration.json'
def sha(data):return hashlib.sha256(data).hexdigest()
def blob(data):return hashlib.sha1(f'blob {len(data)}\0'.encode()+data).hexdigest()
def chunks(text):
    result=[];cur=[];mark=None;length=0
    for line in text.splitlines(keepends=True):
        if mark is None:
            m=re.match(r'^ {0,3}(`{3,}|~{3,})',line)
            if m:result.append(''.join(cur));cur=[line];mark=m.group(1)[0];length=len(m.group(1))
            else:cur.append(line)
        else:
            cur.append(line)
            if re.match(r'^ {0,3}'+re.escape(mark)+'{'+str(length)+r',}\s*$',line):
                result.append(''.join(cur));cur=[];mark=None
    result.append(''.join(cur));return result

def active(text):return ''.join(c for i,c in enumerate(chunks(text)) if i%2==0)
def slug(s):
    s=re.sub(r'<[^>]*>','',s).lower().strip()
    return re.sub(r'[^\w\-\s]','',s,flags=re.UNICODE).replace(' ','-')
def anchors(text):
    text=active(text);out=set(re.findall(r'<a\s+(?:id|name)="([^"]+)"',text));seen={}
    for line in text.splitlines():
        m=re.match(r'^#{1,6}\s+(.+?)\s*#*$',line)
        if m:
            key=slug(m.group(1));n=seen.get(key,0);out.add(key+('' if n==0 else '-'+str(n)));seen[key]=n+1
    return out

def links(text):
    for m in re.finditer(r'\[[^\]\n]*\]\(([^\n)]+)\)',active(text)):
        url=m.group(1).split(' "',1)[0].strip('<>')
        if not re.match(r'^[A-Za-z][A-Za-z0-9+.-]*:',url) and not url.startswith('//'):yield url

def prose_normalize(text,pathmap):
    text=re.sub(r'(\[[^\]\n]*\]\()([^\n)]+)(\))',r'\1<TARGET>\3',text)
    for old,new in sorted(pathmap.items(),key=lambda x:-len(x[0])):text=text.replace('`'+old+'`','`'+new+'`')
    return text

def apply_unified(source:str,delta:str)->str:
    src=source.splitlines(keepends=True);ds=delta.splitlines(keepends=True);out=[];i=0;j=0
    while j<len(ds):
        if not ds[j].startswith('@@ '):j+=1;continue
        m=re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',ds[j]);assert m
        start=int(m.group(1))-1;out.extend(src[i:start]);i=start;j+=1
        while j<len(ds) and not ds[j].startswith('@@ '):
            l=ds[j]
            if l.startswith(' '):assert src[i]==l[1:];out.append(src[i]);i+=1
            elif l.startswith('-'):assert src[i]==l[1:];i+=1
            elif l.startswith('+'):out.append(l[1:])
            elif l.startswith('\\'):pass
            else:raise AssertionError('Unexpected diff line')
            j+=1
    out.extend(src[i:]);return ''.join(out)

def verify(root:Path,source_dir:Path|None=None,upload_file:Path|None=None,allow_legacy:bool=False):
    root=root.resolve();m=json.loads((root/MANIFEST).read_text());passed=[];warnings=[];fail=[]
    def check(name,fn):
        try:
            value=fn()
            if value is False:raise AssertionError('false')
            passed.append(name)
        except Exception as e:fail.append({'check':name,'error':str(e)})
    def git(*args):return subprocess.check_output(['git','-C',str(root),*args],stderr=subprocess.DEVNULL)
    source_cache={}
    def source(path,ref=None):
        ref=ref or m['source_commit'];key=(path,ref)
        if key not in source_cache:
            if source_dir and ref==m['source_commit']:data=(source_dir/path).read_bytes()
            elif upload_file and ref==m['uploaded_source_commit'] and path==OLD+'Our_PL.md':data=upload_file.read_bytes()
            else:data=git('show',ref+':'+path)
            source_cache[key]=data
        return source_cache[key]
    raw=source(OLD+'Our_PL.md',m['uploaded_source_commit']);ls=raw.decode().splitlines(keepends=True)
    check('uploaded exact bytes and blob',lambda:len(raw)==m['snapshots']['upload']['bytes'] and sha(raw)==m['snapshots']['upload']['sha256'] and blob(raw)==m['snapshots']['upload']['git_blob'])
    for f in m['source_files']:
        check('source '+f['path'],lambda f=f:sha(source(f['path']))==f['sha256'] and blob(source(f['path']))==f['git_blob'] and len(source(f['path']))==f['bytes'])
    check('exactly 13 source files',lambda:len(m['source_files'])==13)
    starts=[i for i,l in enumerate(ls) if re.match(r'^## Me😸 \d+:',l)]
    check('50 ordered numbered exchanges',lambda:len(starts)==50 and [int(re.search(r'Me😸 (\d+):',ls[i]).group(1)) for i in starts]==list(range(1,51)))
    for n,r in enumerate(m['exchanges'],1):
        check('exchange range '+str(n),lambda r=r:sha(''.join(ls[r['start_line']-1:r['end_line']]).encode())==r['sha256'])
    primary={n:{'Author':0,'Assistant':0} for n in range(1,51)}
    for u in m['content_units']:
        def test_unit(u=u):
            src=source(u['source_path'],u['source_ref']).decode().splitlines(keepends=True)
            text=''.join(src[u['a']:u['b']]).rstrip('\r\n')
            if u['transform']=='json-body-field':
                obj=json.loads(text);text=obj.get('args',obj)['body']
            assert sha(text.encode())==u['source_sha256']
            expected=text
            if u['transform']=='omit-unrelated-personal-context-before-fiction-question':expected=text[text.index('And also I would like to ask'):]
            target=(root/u['destination']).read_text()
            if 'existing_marker' in u:
                a='<!-- EXACT '+u['existing_marker']+' START -->';z='<!-- EXACT '+u['existing_marker']+' END -->'
            else:a='<!-- BEGIN SOURCE '+u['id']+' -->';z='<!-- END SOURCE '+u['id']+' -->'
            assert target.count(a)==target.count(z)==1
            middle=target.split(a,1)[1].split(z,1)[0].strip('\n')
            first,body=middle.split('\n',1);fence=first.removesuffix('text')
            assert body.endswith('\n'+fence)
            actual=body[:-len('\n'+fence)]
            assert actual==expected
            assert sha(actual.encode())==u['rendered_sha256']
        check('exact unit '+u['id'],test_unit)
        mm=re.match(r'upload-e(\d+)-(author|assistant)',u['id'])
        if mm:primary[int(mm.group(1))]['Author' if mm.group(2)=='author' else 'Assistant']+=1
    check('each exchange has author and assistant prose',lambda:all(x['Author']==1 and x['Assistant']>=1 for x in primary.values()))
    for path in [OLD+'2026-09-26-priscilla-lavinia-portrait-and-intimacy-working-record.md',OLD+'2026-09-27-priscilla-lavinia-session-conversation-archive.md',OLD+'README.md']:
        def complete_partition(path=path):
            entries=sorted([u for u in m['content_units'] if u['source_kind']=='repository' and u['source_path']==path],key=lambda x:x['a'])
            cursor=0
            for u in entries:assert u['a']==cursor;cursor=u['b']
            assert cursor==len(source(path).decode().splitlines())
        check('full section partition '+path,complete_partition)
    def check_tools():
        parsed=[]
        for n,a in enumerate(starts,1):
            end=starts[n] if n<len(starts) else len(ls)
            marks=[i for i in range(a,end) if ls[i].strip()=='**You❤:**']
            for k,j in enumerate(marks):
                z=marks[k+1] if k+1<len(marks) else end
                text=''.join(ls[j+1:z]).strip()
                if text.endswith('\n---'):text=text[:-4].rstrip()
                try:obj=json.loads(text)
                except ValueError:continue
                parsed.append((n,obj,sha(text.encode())))
        assert len(parsed)==len(m['historical_tool_calls'])==293
        assert sorted(x[2] for x in parsed)==sorted(x['sha256'] for x in m['historical_tool_calls'])
        contents=[(obj.get('args',obj)['content'],obj.get('args',obj)['path']) for _,obj,_ in parsed if isinstance(obj.get('args',obj).get('content'),str)]
        assert len(contents)==len(m['embedded_payloads'])==8
        assert sorted(blob(t.encode()) for t,p in contents)==sorted(x['git_blob'] for x in m['embedded_payloads'])
    check('all historical tool calls and 8 contents accounted',check_tools)
    for e in m['embedded_payloads']:
        def embedded(e=e):
            if e['disposition']=='EXACT_DUPLICATE_OF_ACCOUNTED_OWNER':assert blob(source(e['target_path']))==e['git_blob']
            else:
                target=(root/e['owner']).read_text();start='<!-- BEGIN EMBEDDED '+e['git_blob']+' -->\n````diff\n';end='````\n<!-- END EMBEDDED '+e['git_blob']+' -->'
                delta=target.split(start,1)[1].split(end,1)[0]
                assert sha(delta.encode())==e['diff_sha256']
                rebuilt=apply_unified(source(e['target_path']).decode(),delta)
                assert blob(rebuilt.encode())==e['git_blob']
        check('embedded payload '+e['git_blob'],embedded)
    for moved in m['file_moves']:
        def whole(moved=moved):
            target=(root/moved['destination']).read_text();token='<!-- END RELOCATED ORIGINAL '+moved['source_blob']+' -->'
            assert target.count(token)==1
            prefix=target.split(token,1)[0]
            assert prefix.startswith('> **2026-10-01 workspace consolidation:')
            old=prefix.split('\n\n',1)[1].rstrip('\r\n')
            assert prose_normalize(old,m['path_map'])==prose_normalize(source(moved['source']).decode().rstrip('\r\n'),m['path_map'])
            if 'destination_sha256' in moved:assert sha((root/moved['destination']).read_bytes())==moved['destination_sha256']
        check('whole moved text '+moved['destination'],whole)
    def handbook():
        h=m['handbook_transfer'];old=source(h['source']).decode();a=old.index('## Priscilla–Lavinia\n');z=old.index('\n## Priscilla–Sylvia',a)
        section=old[a:z];target=(root/h['destination']).read_text()
        actual=target.split('<!-- BEGIN TRANSFERRED HANDBOOK PAIR -->\n',1)[1].split('\n<!-- END TRANSFERRED HANDBOOK PAIR -->',1)[0]
        assert actual==section and sha(section.encode())==h['section_sha256']
        new=(root/h['source']).read_text();aa=new.index('## Priscilla–Lavinia\n');zz=new.index('\n## Priscilla–Sylvia',aa)
        assert old[:a]==new[:aa] and old[z:]==new[zz:]
    check('Handbook exact pair transfer; other text unchanged',handbook)
    for path in m['protected_current_documents']:
        if path.endswith('day-2-sweet-love-portrait.md'):continue
        def scene(path=path):
            old=source(path).decode();new=(root/path).read_text()
            pat=r'(## (?:1\. )?Current assembled passage\n)(.*?)(?=\n## )'
            aa=re.search(pat,old,re.S);bb=re.search(pat,new,re.S)
            assert aa and bb and aa.group(2)==bb.group(2)
            assert 'UNSELECTED' in new[:1200] and 'REACTION TEST' in new[:1200]
        check('current assembled scene unchanged '+path,scene)
    check('Sweet keeps much and stronger now',lambda:'I wouldn’t say ‘much.’' in (root/'story/relationships/priscilla-lavinia/auditions/day-6-sweet-ambiguous-refusal.md').read_text() and 'I tried it your way. I like it stronger now.' in (root/'story/relationships/priscilla-lavinia/auditions/day-6-sweet-ambiguous-refusal.md').read_text())
    check('Dark current passage does not restore much',lambda:'much' not in re.search(r'## 1\. Current assembled passage\n(.*?)(?=\n## )',(root/'story/relationships/priscilla-lavinia/auditions/day-6-dark-notebook.md').read_text(),re.S).group(1).lower())
    check('four-exchange guide and root routing',lambda:'four substantive user-and-assistant exchanges' in (root/'story/AGENTS.md').read_text() and 'story/AGENTS.md' in (root/'AGENTS.md').read_text())
    if not allow_legacy:
        check('legacy active directory absent',lambda:not (root/OLD).exists())
        check('no substitute raw source folder',lambda:not (root/'story/sources').exists())
    if source_dir:
        tree=(source_dir/'TRACKED-TREE.txt').read_text();known={l.split('\t',1)[1] for l in tree.splitlines() if '\t' in l}
    else:known=set(git('ls-tree','-r','--name-only',m['source_commit']).decode().splitlines())
    known={p for p in known if not p.startswith(OLD)}
    known|={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and '.git' not in p.parts and not p.relative_to(root).as_posix().startswith(OLD)}
    all_original_paths=set()
    if source_dir:all_original_paths={p.relative_to(source_dir).as_posix() for p in source_dir.rglob('*.md')}
    else:all_original_paths={p for p in git('ls-tree','-r','--name-only',m['source_commit']).decode().splitlines() if p.endswith('.md')}
    original_known=set(known)|{f['path'] for f in m['source_files']}
    inherited=set()
    def resolve(path,url):
        base,sep,frag=url.partition('#');return posixpath.normpath(posixpath.join(posixpath.dirname(path),unquote(base))) if base else path,unquote(frag)
    for path in all_original_paths:
        try:text=source(path).decode()
        except Exception:continue
        for url in links(text):
            dest,frag=resolve(path,url)
            if dest not in original_known and not any(p.startswith(dest.rstrip('/')+'/') for p in original_known):inherited.add((path,dest,frag))
            elif frag and dest.endswith('.md'):
                try:
                    if frag not in anchors(source(dest).decode()):inherited.add((path,dest,frag))
                except Exception:pass
    editable={'story/AGENTS.md','story/README.md','story/auditions/README.md','story/02-character-relationship-handbook.md'}
    for path in all_original_paths:
        if path.startswith(OLD) or path.startswith('story/relationships/') or path.startswith('story/maintenance/') or path in editable:continue
        if (root/path).exists():
            check('pre-existing prose unchanged '+path,lambda path=path:prose_normalize(source(path).decode(),m['path_map'])==prose_normalize((root/path).read_text(),m['path_map']))
    check('story discussion matches both source snapshots',lambda:source(OLD+'Our_PL.md').split(b'**You',1)[1].rstrip(b'\n')==raw.split(b'**You',1)[1].rstrip(b'\n'))
    source_for={v:k for k,v in m['path_map'].items() if k in {x['source'] for x in m['file_moves']}}
    link_count=0;broken=[]
    for p in sorted(root.rglob('*.md')):
        path=p.relative_to(root).as_posix()
        if path.startswith(OLD) or '.git' in p.parts:continue
        try:old=source(path)
        except Exception:old=None
        if old==p.read_bytes() and path!='AGENTS.md':continue
        for url in links(p.read_text()):
            dest,frag=resolve(path,url);link_count+=1
            exists=dest in known or any(x.startswith(dest.rstrip('/')+'/') for x in known)
            problem=None
            if not exists:problem='missing target'
            elif frag and dest.endswith('.md') and (root/dest).exists() and frag not in anchors((root/dest).read_text()):problem='missing anchor'
            if problem:
                oldpath=source_for.get(path,path);olddest=source_for.get(dest,dest)
                if (oldpath,olddest,frag) in inherited:warnings.append({'type':'pre-existing link issue','path':path,'target':url,'problem':problem})
                else:broken.append({'path':path,'target':url,'problem':problem})
            if dest.startswith(OLD):broken.append({'path':path,'target':url,'problem':'live legacy dependency'})
    check('active relative links introduce no breakage',lambda:not broken)
    if broken:fail.append({'check':'link detail','error':broken})
    return {'passed_count':len(passed),'failed_count':len(fail),'checks':passed,'failures':fail,'warnings':warnings,'active_links_checked':link_count,
      'source_units':len(m['content_units']),'exchanges':len(m['exchanges']),'legacy_source_files':len(m['source_files']),
      'limits':['No external URL/anchor availability check','No independent literary, physical/audio, whole-family or runtime review','Earlier missing-history holds remain'],
      'source_commit':m['source_commit'],'uploaded_source_commit':m['uploaded_source_commit']}
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path('.'));p.add_argument('--source-dir',type=Path);p.add_argument('--upload',type=Path);p.add_argument('--report',type=Path);p.add_argument('--allow-legacy',action='store_true');a=p.parse_args()
    report=verify(a.root,a.source_dir,a.upload,a.allow_legacy)
    if a.report:a.report.parent.mkdir(parents=True,exist_ok=True);a.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='checks'},ensure_ascii=False,indent=2))
    sys.exit(bool(report['failed_count']))
