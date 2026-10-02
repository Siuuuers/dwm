# Evidence tooling

These are the exact shared/focused helpers used for capture, source-bound audit
and packaging. The broad archive additionally retains its independent coverage,
public-surface, Settings/storage, rendered/reading and performance auditors under
`run120/audit/`. Their CLI arguments carry explicit source and checkout identities.
Python only reads evidence/Git objects; Godot and PowerShell execute in Actions.

Capture uses authenticated GitHub tools, opaque artifact file IDs, verified SHA-256
and ZIP membership. `capture_cloud_evidence.js` is an orchestration recipe for
`functions.exec`, not a Node script. Its task-local root/helper paths identify this
workspace and must be adjusted to a new scratch root if replayed. Cached downloads
are accepted only after metadata equality, then the same full ZIP/member checks.
The oversized export omission is explicit; it is not a successful local download.

For Run119, run `audit_selector_cloud.py --stage initial` and
`audit_selector_focused.py` with its run directory, source
`7a545490acc65a3332e766c243dee5f8938c7b4a`, repository and attachment directory.
The independent selector report preserves exact case names and reviewed inventories.

For Run120, `cloud_evidence.py audit` uses source
`1459af29ad467ca1375ed12fe9e2f31671ce8171`, checkout
`e84131335d7e49a4d7ae151f99df6f8f2ce93eec`, master
`6a5ddf1564870b43aa9140cad7e0e5b12e43f399`, 23 jobs, 13 XML suites,
checkout-free job `Windows / seven-day retained history`, allowed differences
`AGENTS.md`, `docs/*`, `story/*`, and reading modes
`write,read,repeat,variant,witness-read,next-unseen,next,next-read`.
Run the independent auditors before the retained selector acceptance join.

`cloud_evidence.py package` verifies source-bound raw evidence again and creates a
deterministic, round-trip-verified archive. The bundle manifest records payload
hashes and all omissions. Full ZIP/extraction audit replay requires the original
artifact ZIPs while available; omitted PNG/binary bytes are not manufactured from
hashes. Retained text, reading PNGs and save bytes remain independently hashable
inside the published archive after upstream artifact expiry.
