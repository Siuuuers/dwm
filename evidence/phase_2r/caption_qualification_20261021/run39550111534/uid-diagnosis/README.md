# Focused caption preparation failure: offline reconstruction

Run 39550111534 attempt 1 stopped during post-import preparation. This directory contains evidence-only analysis; no helper correction, retry, or game execution.

Reproduce using the original extracted preparation artifact and a repository object database containing the pinned UID blobs:

```sh
python reproduce.py --repo /path/to/dwm --artifact /path/to/extracted-preparation
```

The script refuses missing local objects and disables lazy fetching. It validates every examined byte sequence against the artifact's SHA256 and Git blob identity, then applies the failed helper's actual sorted tracked/generated peer order and canonical validator. `reproduction.json` is the retained result.

The first rejected comparison is number 268, `addons/godot_state_charts/csharp/ResourceWrapper.cs.uid`. Its original 20 bytes are retained in `ResourceWrapper.cs.uid.original`. Its syntax passes; its unsigned base34 value exceeds signed63 range. The generated runtime UID's own decoding succeeded before the peer comparison failed.

[Official Godot 4.6.3 ResourceUID source](https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/core/io/resource_uid.cpp): `text_to_id` accumulates in uint64 using base34, accepts ASCII lower-case letters and digits, and returns the accumulated value masked with `0x7FFFFFFFFFFFFFFF`. For this exact retained text, that gives 69844882223237904; the failed canonical validator rejects its unmasked value 9293216919078013712. This is a policy comparison mismatch, not evidence that the new runtime UID is malformed.

Potential future correction only: retain strict canonical validation for the newly generated runtime UID, while comparing pinned existing sidecars using the engine's decoding semantics. Preserve all raw-byte/index/settings guards and collision checks; name a failing peer path in diagnostic records. Do not normalize source metadata or skip comparisons. No correction is implemented here.
