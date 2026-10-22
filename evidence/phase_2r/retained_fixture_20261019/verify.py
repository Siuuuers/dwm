#!/usr/bin/env python3
"""Recheck original cloud fixture archive; no engine execution."""
import hashlib,json,re,zipfile
from pathlib import Path,PurePosixPath
from xml.etree import ElementTree as ET
ROOT=Path(__file__).parent
EXPECTED="343130eef1fcf87e3026e4e41c2b866f2275b80092dfd0312a3e646d3fcaa78d"
SOURCE="3b98a73f1ee271bbc6e733c7665ad0a3e8e75db7"
TREE="507c82e9315abe1732c29ba2b83fe5deae4f5036"
METHODS=["test_v6_does_not_backfill_absent_cache_and_v7_refuses_generated_dating_gap","test_saved_dating_binds_run_board_and_effect_but_keeps_original_branch_and_tier","test_present_dating_cache_is_exact_and_requires_its_reached_phases","test_semantic_checkpoint_cannot_disagree_with_its_saved_canonical_projection","test_strict_prepared_condition_candidate_requires_its_generated_dating_cache_without_repair","test_strict_semantic_checkpoint_requires_both_discriminators_and_preserves_generic_restart","test_v8_requires_generated_contact_context_before_preparing_a_detached_candidate"]
def sha(data):return hashlib.sha256(data).hexdigest()
def verify():
 data=(ROOT/"original-evidence.zip").read_bytes();assert sha(data)==EXPECTED
 report={"archive_sha256":EXPECTED,"archive_bytes":len(data),"source":SOURCE,"tree":TREE,"members":[],"cases":[],"isolated_exits":[]}
 with zipfile.ZipFile(ROOT/"original-evidence.zip") as z:
  names=z.namelist();assert len(names)==32 and len(names)==len(set(names));assert z.testzip() is None
  assert all(not PurePosixPath(n).is_absolute() and ".." not in PurePosixPath(n).parts and chr(92) not in n for n in names)
  for n in sorted(names):report["members"].append({"path":n,"bytes":len(z.read(n)),"sha256":sha(z.read(n))})
  origin=json.loads(z.read("ci/fixture-origin.json").decode("utf-8-sig"));assert origin["source"]==SOURCE and origin["tree"]==TREE and origin["controller"]=="648d6ce0da07c763f215a7edd835627081ff2d2b"
  sources=json.loads(z.read("ci/fixture-source-manifest.json").decode("utf-8-sig"));assert len(sources)==5
  for s in sources:
   raw=z.read("ci/fixture-source/"+s["path"]);assert sha(raw)==s["sha256"]
   assert hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest()==s["blob"]
  counts=[]
  for i in range(1,9):
   stem="retained-fixture-"+str(i)
   tree=ET.fromstring(z.read("ci/"+stem+".xml"));cases=tree.findall(".//testcase")
   assert not tree.findall(".//failure")+tree.findall(".//error")+tree.findall(".//skipped")
   assert len(cases)==(5 if i==8 else 1)
   if i<8:assert cases[0].get("name")==METHODS[i-1]
   else:
    src=z.read("ci/fixture-source/tests/unit/test_retained_frozen_context_fixture.gd").decode()
    assert {c.get("name") for c in cases}==set(re.findall(r"^func (test_\w+)\(",src,re.M))
   report["cases"] += [{"name":c.get("name"),"assertions":int(c.get("assertions"))} for c in cases]
   rows=[json.loads(r) for r in z.read("ci/"+stem+".jsonl").decode("utf-8-sig").splitlines()];assert len(rows)==1
   r=rows[0];assert r["exit_code"]==0 and r["suite_id"]==stem
   report["isolated_exits"].append({"suite":stem,"exit_code":r["exit_code"],"test_root":r["test_root"]})
  assert len({r["test_root"] for r in report["isolated_exits"]})==8
  for n in names:
   if n.endswith(".log"):
    text=z.read(n).decode("utf-8-sig");assert not re.search(r"SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character",text),n
  report.update(ok=True,tests=len(report["cases"]),assertions=sum(c["assertions"] for c in report["cases"]),scope="Selected retained-fixture and same-process cache-isolation tests only; no whole-suite/gameplay acceptance")
  assert report["tests"]==12 and report["assertions"]==177
 return report
if __name__=="__main__":
 result=verify();(ROOT/"verification.json").write_text(json.dumps(result,indent=2)+"\n");print(json.dumps({k:result[k] for k in ["ok","tests","assertions","archive_sha256"]}))
