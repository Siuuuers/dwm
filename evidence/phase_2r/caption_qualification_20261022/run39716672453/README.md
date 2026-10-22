# Focused passes; native geometry check failed

Run https://github.com/Siuuuers/dwm/actions/runs/39716672453 attempt 1, job 119620312522: **failure**.
Controller: 2c994267230469108a41f716d9fcdabd2c1c5511.
Source: b430cf2966d87d0da73f0d506f6acd89eecf6fa6.
Helper: 01a76f15b6c4ab303e8c4cac5b96cd1f72118fd9.

All eight focused cases passed, zero skips/failures, 153 assertions: organic 35, manual 35, pointer 16, keyboard 12, touch 21, review 11, speech-start 13, speech-cancel 10. Organic/manual reader and child exits were zero, unforced, with matching identity, no cleanup errors; clock drift 7.4246/8.2460 ms within the unchanged 10 ms limit. Native timing remains unclassified.

All three preflights and before/import/restored/post-tests preparation checks passed. Native acceptance stopped at first reveal with CAPTION_FIXTURE_GEOMETRY_MISMATCH, before invocation or wheel input. Native provider identity was verified (PID 7052, HWND 983422), operations returned HRESULT 0, provider closed with no cleanup errors.

The focused Text rectangle was [32,544,420,36]; fixture target_rect [16,524,1248,68] describes the entire Control. Continue rectangle [0,4,1280,656] is consistent with client-origin offset y=4. Godot RichTextLabel focuses a shaped-text subelement; its bounds need not equal the control bounds. The flat captured tree does not prove ancestry. Next candidate must collect and validate raw ancestry to the exact owner rectangle, retain the existing tolerance and identity checks, and require text containment. No product/fixture change is justified by this result.

Independent reviewer confirmed the eight focused passes and narrow native failure scope. Retain those passes when changing only native driver/controller; run native-only next. This failed batch must not be relabeled successful.

## Original evidence
archives.json records original ZIP lengths, SHA256, artifact IDs and ordered parts. Concatenate listed parts for the preparation ZIP; other archives are whole. All original downloads were checked against provider SHA256 before preservation. Five archives occupy 46 Git blobs. Original receipts, images, XML, logs and preparation captures are retained inside the archives.

No merge, release, engine rebuild or movement of master, PR36 product, or integration base.
