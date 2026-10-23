# Windows exporter ObjectDB diagnostic review

## Result

Both Broad1 and Broad2 retain the same exporter-process diagnostic once at `export.console.log:2086`:

`WARNING: ObjectDB instances leaked at exit (run with --verbose for details).`

Line 2087 identifies `cleanup (core/object/object.cpp:2663)`. The two `export.console.log` files are byte-identical (`7a9860f5…`, 256,839 bytes), as are the two `export.log` files (`704cfddd…`). Within each export artifact, the warning is absent from `import.log`, `export.log`, both smoke logs, both pack-audit logs, and the version log. The combined console is constructed as complete stdout plus a newline plus complete stderr, so its placement after the savepack `DONE` marker is byte order, not proof of temporal ordering or stream identity.

The source8 and source9 copies of `Invoke-WindowsExportValidation.ps1` are identical (`a2bb7215…`). Its rejection expression covers structured script/engine/startup, Unicode, NUL, exit-code, and timeout failures; it does not include the ObjectDB warning. Consequently, both successful jobs genuinely satisfy the committed validator's bounded contract: unsigned export creation, packaged-data verification, and isolated 240-iteration headless startup.

They do **not** establish leak-free exporter shutdown. The independent Broad1/Broad2 checklist says to reject resource-lifetime diagnostics outside its explicit controls. The stricter Broad2 scratch exporter auditor therefore stops on this warning. That is a valid refusal of an unqualified clean-diagnostic or whole-gate claim, but it is not evidence that the produced archive, PCK audit, or exported executable startup failed.

No concrete export or startup failure beyond the warning is present in the retained evidence. The warning itself remains a checklist blocker until it is investigated or explicitly dispositioned. Current bytes do not identify the leaked object count, type, owner, plugin, scene, or gameplay consequence, so no culprit is assigned.

If investigation is required, the next useful evidence is the same editor export with verbose diagnostics in an explicitly reviewed workflow, ideally retaining stdout and stderr separately. This review did not run an engine or alter tests, source, prior audits, or evidence.

`broad1-export-audit-erratum.json` is additive: it records the warning omitted from the prior Broad1 audit's observation list while preserving all verified artifact identities and bounded startup/package findings.
