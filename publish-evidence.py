import base64,gzip,hashlib,io,json,os,pathlib,subprocess,urllib.request,zipfile
ROOT=pathlib.Path("candidate")
BASE="0ccaaed82bb0f896e998118ee8b5db5d2a25a7e3"
BRANCH="codex/snapshot-validation-simplification-20261025"
entries=json.loads(gzip.decompress(base64.b64decode(pathlib.Path("controller/publication-payload.b64").read_bytes())))
def git(*args): return subprocess.check_output(["git","-C",str(ROOT),*args]).decode().strip()
assert git("rev-parse","HEAD")==BASE
def blob(data): return hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest()
objects={}
metadata=json.loads(base64.b64decode(next(x["content"] for x in entries if x["path"].endswith("original-artifacts.json"))))
for e in metadata:
 process=subprocess.run(["curl","--fail","--silent","--show-error","--location","--retry","3","--header","Authorization: Bearer "+os.environ["GH_TOKEN"],"--header","Accept: application/vnd.github+json",e["archive_download_url"]],stdout=subprocess.PIPE)
 assert process.returncode==0, ("artifact download failed",e["id"])
 data=process.stdout
 assert len(data)==e["size_in_bytes"]
 assert "sha256:"+hashlib.sha256(data).hexdigest()==e["digest"]
 with zipfile.ZipFile(io.BytesIO(data)) as z:
  assert z.testzip() is None
  for i in z.infolist():
   if not i.is_dir():
    content=z.read(i); objects[hashlib.sha256(content).hexdigest()]=content
for e in entries:
 p=ROOT/e["path"]; p.parent.mkdir(parents=True,exist_ok=True)
 if "append" in e: p.write_bytes(p.read_bytes()+base64.b64decode(e["append"]))
 elif "content" in e: p.write_bytes(base64.b64decode(e["content"]))
 else:
  with zipfile.ZipFile(p,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
   for item in e["zip"]:
    info=zipfile.ZipInfo(item["filename"],tuple(item["date_time"]))
    for k in ["compress_type","create_system","external_attr"]: setattr(info,k,item[k])
    z.writestr(info,objects[item["filename"].split("/")[1]],compresslevel=9)
 assert blob(p.read_bytes())==e["sha"], ("blob mismatch",e["path"],blob(p.read_bytes()),e["sha"])
 print("Verified exact publication blob:",e["path"])
assert not git("diff","--name-only",BASE,"--","autoload","scripts","addons","scenes","assets","data","dialogic","localization","project.godot","tests","tools")
git("diff","--check")
git("add","--",*[x["path"] for x in entries])
assert set(git("diff","--cached","--name-only").splitlines())=={x["path"] for x in entries}
git("config","user.name","github-actions[bot]")
git("config","user.email","41898282+github-actions[bot]@users.noreply.github.com")
git("commit","-m","Retain qualified snapshot validation evidence and next investigation handoff [skip ci]")
assert git("ls-remote","origin","refs/heads/"+BRANCH).split()[0]==BASE
git("push","origin","HEAD:refs/heads/"+BRANCH)
print("Publication commit:",git("rev-parse","HEAD"))
