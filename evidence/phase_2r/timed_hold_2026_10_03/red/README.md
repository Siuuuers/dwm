# Timed-hold failed-regression staging

These are complete diagnostic archives for Red1 run **37091802987** and Red2
run **37092157492**, both attempt 1. Each run has one passing control and three
failing test cases, with zero XML errors or skips. Red1 also contains an invalid
resource-identity assertion; Red2 corrects that test-only assumption and retains
the three demonstrated native defects. Neither archive is fixed-runtime acceptance.

| Archive | Bytes | Payload files plus inventory |
| --- | ---: | ---: |
| timed-hold-red1-diagnostic-evidence.tar.gz | 142127 | 37 + 1 |
| timed-hold-red2-diagnostic-evidence.tar.gz | 144179 | 36 + 1 |

Each archive preserves all 11 original capture files, the exact original ZIP and
its five extracted files, all files in its published source snapshot, workflow
YAML/manifests/publication/API/tree records, the historical generator and its
dependencies, and the independent red audit script/report. There are no excluded
files within this declared scope. The executed fixture and unchanged baseline
Wait are copied from immutable Git objects. No candidate or green source is
included, and no current green execution is inferred.

The import process emits one ObjectDB shutdown warning in each job console;
the fixture and import.log artifacts do not contain it. Preserve this qualification.
Native Profile snapshots begin empty, so these runs do not prove initialized
durable Profile bytes, production Pause UI, or a durable timer save cursor.

The external per-run package manifests bind archive and inventory SHA256 values.
Every tar member is checked after creation against the exact intended bytes. Tar
entries are sorted with fixed ownership, mode and timestamp; gzip omits filename
and has timestamp zero. The script rejects replacing any sealed output with
different bytes.

Reproduce with Python and read-only Git; no Godot or PowerShell is invoked:

```sh
python3 build_red_evidence.py --workspace /path/to/workspace --output /path/to/new-stage
```

The workspace needs the archived relative paths and a `dwm` Git checkout holding
the cited commits. The original independent auditors keep their historical paths
unchanged. Extracting the two archives restores their inputs; the packaging script
can be rerun after relocating original ZIP lookup paths. The original capture
manifests themselves are never rewritten.

For repository adoption, retain the two archives, both inventories, both package
manifests, `red-evidence-summary.json`, this README, and `build_red_evidence.py`.
The `red1-payload` and `red2-payload` directories are inspection copies of archived
content and need not be duplicated in the repository.
