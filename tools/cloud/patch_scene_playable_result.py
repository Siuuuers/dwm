"""Apply the reviewed, exact two-file playable-result change on the pinned source.
This controller utility never changes refs or runs the game.
"""
from pathlib import Path
import hashlib
import subprocess
import sys

BASE = "a991b5256d88275debae051a61a7ee23494c868e"
EXPECTED = {
    "scripts/domain/narrative/SceneEventContract.gd": "1001ac3c8ae03c3461ff4ce20804b89d9e26981b",
    "tests/unit/test_scene_event_contract.gd": "9818fc065884c0bd9781d7e113bdbf148edfe7e7",
}
root = Path(sys.argv[1]).resolve()
head = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
if head != BASE:
    raise SystemExit("Unexpected product base; re-review instead of rebasing implicitly.")
contents = {}
for name, expected in EXPECTED.items():
    data = (root / name).read_bytes()
    blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
    if blob != expected:
        raise SystemExit(f"Source bytes changed: {name}")
    contents[name] = data.decode("utf-8")

name = "scripts/domain/narrative/SceneEventContract.gd"
text = contents[name]
needle = '\t\t"challenge_closed":\n'
addition = '''\t\t"challenge_playable":
\t\t\tif not _keys(result, ["kind", "challenge_occurrence"]) or envelope.kind != "challenge.playable" \\
\t\t\t\t\tor not _hash(result.challenge_occurrence): return _fail(&"scene_result_invalid")
\t\t\tif result.challenge_occurrence != _sha([envelope.source.scene_occurrence, envelope.payload.challenge_id]):
\t\t\t\treturn _fail(&"scene_result_invalid")
'''
if text.count(needle) != 1:
    raise SystemExit("Result discriminator anchor is not unique.")
text = text.replace(needle, addition + needle, 1)
old = '''\t\t\tvar playable: Dictionary = commands[result.playable_command_id].scene_event.semantic
\t\t\tif playable.kind != "challenge.playable" or not _equal(playable.source, semantic.source) \\
\t\t\t\t\tor playable.payload.challenge_id != semantic.payload.challenge_id or playable.ordinal >= semantic.ordinal:
'''
new = '''\t\t\tvar playable: Dictionary = commands[result.playable_command_id].scene_event.semantic
\t\t\tvar playable_result: Dictionary = commands[result.playable_command_id].scene_event.result
\t\t\tif playable.kind != "challenge.playable" or not _equal(playable.source, semantic.source) \\
\t\t\t\t\tor playable.payload.challenge_id != semantic.payload.challenge_id or playable.ordinal >= semantic.ordinal \\
\t\t\t\t\tor playable_result.kind != "challenge_playable" or playable_result.challenge_occurrence != result.challenge_occurrence:
'''
if text.count(old) != 1:
    raise SystemExit("Closure join anchor is not unique.")
text = text.replace(old, new, 1)
(root / name).write_bytes(text.encode("utf-8"))

tests = Path(__file__).with_name("scene_playable_result_tests.gd.txt").read_bytes()
if not tests.startswith(b"\n\nfunc _playable_event"):
    raise SystemExit("Unexpected test payload.")
name = "tests/unit/test_scene_event_contract.gd"
(root / name).write_bytes(contents[name].encode("utf-8") + tests)
print("Applied only the exact result discriminator, closure join, and focused tests.")
