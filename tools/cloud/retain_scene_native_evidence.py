"""Retain two original native-control artifacts and verify their byte manifests.

Invoked only by the evidence job after the native job uploaded its original ZIP.
Does not execute archived code, extract arbitrary paths, or run a game engine.
"""
from __future__ import annotations
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

REPO = "Siuuuers/dwm"
FIRST_RUN = 37990185115
FIRST_ARTIFACT = 11644667431
FIRST_DIGEST = "5745d67208f2d6a22da9e934d1674ebd17fd0675bb1e1172ff26f57b6054913e"
FIRST_SOURCE = "8a70985a140c32a0823141bace60f946454a232c"
EXPECTED_PARENT = "9c3c66dfbad0caa77aeaf616d78d0aec56a0f29d"
FINAL_BLOBS = {
    "scripts/narrative/DialogicRuntimeAdapter.gd": "5c2918c79c03ee78de516ba0d0f25e9a8ba79147",
    "tests/fixtures/dialogic/scene_playable_native.dtl": "12f4043df0e4a8a42524a47c6f6a0b93e6dd964e",
    "tests/integration/test_scene_playable_native_control.gd": "beaab006e6807ae27df658d9b3e8ee8864fc7059",
    "tests/integration/test_scene_playable_native_control.gd.uid": "c7c99d96f87851c9ef027e99343f4ef4e252edbc",
}

class RedirectWithoutAuthorization(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        redirected = super().redirect_request(req, fp, code, msg, headers, newurl)
        if redirected is not None:
            redirected.remove_header("Authorization")
        return redirected

OPENER = urllib.request.build_opener(RedirectWithoutAuthorization())

def api(path: str, binary: bool = False):
    request = urllib.request.Request("https://api.github.com/repos/" + REPO + "/" + path,
        headers={"Authorization": "Bearer " + os.environ["GH_TOKEN"],
                 "Accept": "application/vnd.github+json", "User-Agent": "dwm-original-evidence"})
    with OPENER.open(request, timeout=120) as response:
        content = response.read()
    return content if binary else json.loads(content)

def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)

def retain(root: Path, artifact: dict, final: bool) -> dict:
    data = api(f"actions/artifacts/{int(artifact['id'])}/zip", binary=True)
    digest = hashlib.sha256(data).hexdigest()
    require("sha256:" + digest == artifact["digest"], "artifact digest mismatch")
    if not final:
        require(digest == FIRST_DIGEST, "first original changed")
    name = artifact["name"]
    require(name.startswith("scene-playable-native-") and "/" not in name, "wrong artifact name")
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        manifest = json.loads(archive.read("ci/original-file-hashes.json"))
        seen = set()
        for record in manifest:
            path = record["path"]
            require(path.startswith(".godot/") and ".." not in path.split("/"), "invalid manifest path")
            require(path not in seen, "duplicate manifest member")
            seen.add(path)
            member = archive.read(path[len(".godot/"):])
            require(len(member) == record["bytes"] and hashlib.sha256(member).hexdigest() == record["sha256"], "manifest member mismatch: " + path)
        source = json.loads(archive.read("ci/source-receipt.json"))
        engine = json.loads(archive.read("ci/engine-receipt.json"))
        summary = json.loads(archive.read("ci/native-summary.json"))
        xml = ET.fromstring(archive.read("ci/playable-native.xml"))
        cases = list(xml.iter("testcase"))
        require(not list(xml.iter("failure")) and not list(xml.iter("error")) and not list(xml.iter("skipped")), "nonpassing original XML")
        require(len(cases) == (9 if final else 8) == summary["cases"], "case count mismatch")
        require(engine["version"] == "4.6.3.stable.official.7d41c59c4", "wrong engine")
        require(engine["archive_sha256"] == "e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90", "wrong engine archive")
        if final:
            require(source["parent"] == FIRST_SOURCE, "final candidate lost original ancestry")
            require(source["controller_sha"] == os.environ["CONTROLLER_SHA"], "wrong current controller")
            require(str(source["run_id"]) == os.environ["GITHUB_RUN_ID"], "wrong current run")
            with zipfile.ZipFile(io.BytesIO(archive.read("ci/source-inspection.zip"))) as inspection:
                for path, expected in FINAL_BLOBS.items():
                    blob = inspection.read(path)
                    actual = hashlib.sha1(b"blob " + str(len(blob)).encode() + b"\0" + blob).hexdigest()
                    require(actual == expected, "wrong retained product blob: " + path)
        else:
            require(source["source_sha"] == FIRST_SOURCE and source["parent"] == "09addba8b544e21753846f2002880a7826b85f31", "wrong initial source")
        assertions = sum(int(case.attrib.get("assertions", "0")) for case in cases)
        require(assertions == summary["xml_assertions"], "assertion summary mismatch")
    (root / ("original-" + name + ".zip")).write_bytes(data)
    return {"artifact_id": artifact["id"], "artifact_name": name, "bytes": len(data),
            "sha256": digest, "verified_manifest_members": len(manifest), "source": source,
            "engine": engine, "cases": len(cases), "xml_assertions": assertions,
            "status": "final native prerequisite" if final else "superseded eight-case diagnostic"}

def main() -> None:
    require(len(sys.argv) == 2, "usage: retain_scene_native_evidence.py EVIDENCE_CHECKOUT")
    checkout = Path(sys.argv[1]).resolve()
    head = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
    require(head == EXPECTED_PARENT, "evidence ancestry changed")
    target = checkout / "evidence/scene_playable_native_2026_10_10"
    require(not target.exists(), "evidence directory already exists")
    target.mkdir(parents=True)
    first = api(f"actions/artifacts/{FIRST_ARTIFACT}")
    listed = api(f"actions/runs/{os.environ['GITHUB_RUN_ID']}/artifacts?per_page=100")
    expected = f"scene-playable-native-{os.environ['GITHUB_RUN_ID']}-{os.environ['GITHUB_RUN_ATTEMPT']}"
    current = [entry for entry in listed["artifacts"] if entry["name"] == expected]
    require(len(current) == 1 and not current[0]["expired"], "missing current original")
    records = [retain(target, first, False), retain(target, current[0], True)]
    final = records[1]
    text = f'''# Native playable-control prerequisite, 10 October 2026

## Retained result and limits

Final product `{final["source"]["source_sha"]}`, tree `{final["source"]["source_tree"]}`.
Parent `{FIRST_SOURCE}` is the eight-case diagnostic, itself a child of A
`09addba8b544e21753846f2002880a7826b85f31`. Both original source patches, source
archives, controller/event pins, logs and engine receipts remain in these ZIPs.

Final cloud run {final["source"]["run_id"]}/{final["source"]["run_attempt"]}:
**{final["cases"]} cases / {final["xml_assertions"]} XML assertions**, no failures,
errors or skips. The first run {FIRST_RUN}/1 passed eight cases /231 XML
assertions (236 log assertions), then was superseded by the explicit reentrancy
guard and ninth regression. Do not add overlapping runs into a unique total.

The actual installed native callbacks publish a TEST-admitted caption. The
original opaque held-source token admits only the exact schema3/Reading5
playable-control projection. The caption event/execution, frontier, history and
real Profile snapshot remain unchanged; no marker runs and custody is one-use.
Negatives cover unheld/forged/stale source, wrong End/Contact marker, malformed
or changed candidate/input and nested callback installation.

This is a **nonwired native adapter prerequisite**, not Bridge/checkpoint
acknowledgement, Run/Save/issuer authority, fresh-process Load, physical Start or
End, rendered E2E, production startup, independent D acceptance or whole-game
completion. C's final Backup source remains subject to its separate finite D
review and A composition. No engine was rerun by this retention job.

## Integrity

The original artifact download digests and every manifest member were verified
before copying the ZIP bytes unchanged. `retention-verification.json` records
all counts, sizes, hashes, source/controller/event pins and engine identities.
Final source-inspection blobs were also checked against the exact reviewed
adapter, DTL, test and UID blobs. Evidence retention does not move product,
master or PR #1 refs and grants no merge or release permission.
'''
    (target / "README.md").write_text(text, encoding="utf-8", newline="\n")
    (target / "retention-verification.json").write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"original_archives": len(records), "verified_members": sum(r["verified_manifest_members"] for r in records), "final_source": final["source"]["source_sha"]}))

if __name__ == "__main__":
    main()
