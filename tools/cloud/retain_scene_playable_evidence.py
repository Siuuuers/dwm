"""Retain one completed cloud proof verbatim; no engine execution or product edits."""
import hashlib
import io
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

REPO = "Siuuuers/dwm"
RUN = 37979744715
ARTIFACT = 11640677076
SOURCE = "09addba8b544e21753846f2002880a7826b85f31"
TREE = "b8508742f46c7fb7deb5e576e6d5c6490ee352ec"
DIGEST = "243aea0cedaf357140d70c73dfa4813f6f9bd632bad485d4129b5bf7f2ecdfc4"
TOKEN = os.environ["GH_TOKEN"]

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

opener = urllib.request.build_opener(NoRedirect())
def api(path):
    request = urllib.request.Request("https://api.github.com/repos/" + REPO + path,
        headers={"Authorization": "Bearer " + TOKEN, "Accept": "application/vnd.github+json",
                 "X-GitHub-Api-Version": "2022-11-28"})
    return opener.open(request, timeout=60)

def require(condition, message):
    if not condition:
        raise SystemExit(message)

with api(f"/actions/runs/{RUN}") as response:
    run = json.load(response)
require(run["status"] == "completed" and run["conclusion"] == "success", "Original run is not successful.")
require(run["head_sha"] == "eaf2229d24f408ad2152a1423d5139d8058c1d36", "Wrong original controller.")
try:
    with api(f"/actions/artifacts/{ARTIFACT}/zip") as response:
        archive = response.read()
except urllib.error.HTTPError as error:
    require(error.code in (301, 302, 303, 307, 308), "Artifact download failed.")
    location = error.headers.get("Location", "")
    require(urllib.parse.urlsplit(location).scheme == "https", "Artifact redirect is not HTTPS.")
    # Never forward the GitHub token to the signed storage destination.
    with urllib.request.urlopen(location, timeout=120) as response:
        archive = response.read()
require(len(archive) == 8099152 and hashlib.sha256(archive).hexdigest() == DIGEST, "Original archive bytes differ.")
with zipfile.ZipFile(io.BytesIO(archive)) as z:
    require(len(z.namelist()) == len(set(z.namelist())), "Duplicate artifact members.")
    manifest = json.loads(z.read("ci/original-file-hashes.json").decode("utf-8-sig"))
    require(len(manifest) == 10, "Wrong manifest count.")
    checked = []
    for row in manifest:
        path = row["path"].removeprefix(".godot/")
        data = z.read(path)
        require(len(data) == row["bytes"] and hashlib.sha256(data).hexdigest() == row["sha256"], "Manifest member differs: " + path)
        checked.append(path)
    require(len(set(checked)) == 10 and set(z.namelist()) == set(checked) | {"ci/original-file-hashes.json"}, "Unexpected artifact members.")
    source = json.loads(z.read("ci/source-receipt.json").decode("utf-8-sig"))
    require(source["source_sha"] == SOURCE and source["source_tree"] == TREE and source["parent"] == "a991b5256d88275debae051a61a7ee23494c868e", "Wrong tested source.")
    require(source["controller_event_sha"] == "548cf752d0c0fb407e79bf27556b4ff48272c139", "Wrong original event.")
    xml = ET.fromstring(z.read("ci/playable-contract.xml"))
    cases = xml.findall(".//testcase")
    require(len(cases) == 25 and not xml.findall(".//failure") and not xml.findall(".//error") and not xml.findall(".//skipped"), "Test evidence failed.")
    with zipfile.ZipFile(io.BytesIO(z.read("ci/source-inspection.zip"))) as source_zip:
        script = source_zip.read("tests/unit/test_scene_event_contract.gd").decode("utf-8")
    declared = re.findall(r"^func (test_[A-Za-z0-9_]+)\(", script, re.MULTILINE)
    require(len(declared) == 25 and sorted(declared) == sorted(case.attrib["name"] for case in cases), "Declared/executed tests differ.")
    assertions = sum(int(case.attrib.get("assertions", "0")) for case in cases)
    require(assertions == 264, "Wrong assertion count.")
    for path in ("ci/import.log", "phase2r_logs/playable-contract.log"):
        log = z.read(path).decode("utf-8-sig")
        require(not re.search(r"SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character", log), "Strict log failure: " + path)
root = Path(sys.argv[1]).resolve()
destination = root / "evidence/scene_playable_result_2026_10_10"
require(not destination.exists(), "Refusing existing evidence destination.")
destination.mkdir(parents=True)
(destination / "original-scene-playable-result-37979744715-1.zip").write_bytes(archive)
verification = {"original_run_id": RUN, "original_artifact_id": ARTIFACT, "original_artifact_bytes": len(archive),
    "original_artifact_sha256": DIGEST, "source_sha": SOURCE, "source_tree": TREE,
    "verified_manifest_members": checked, "tests": 25, "assertions": assertions,
    "failures": 0, "errors": 0, "skips": 0, "script_errors": 0,
    "retention_run_id": os.environ["GITHUB_RUN_ID"], "new_engine_execution": False,
    "scope": "Contract-only proof; genuine forward producer and durable native control handoff remain unimplemented."}
(destination / "retention-verification.json").write_text(json.dumps(verification, indent=2) + "\n", encoding="utf-8")
print(json.dumps(verification, indent=2))
