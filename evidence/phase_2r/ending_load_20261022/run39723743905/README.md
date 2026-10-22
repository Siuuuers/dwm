# Connected discriminator 39723743905 — test observer mismatch

Source df9ea602fc813a2f1e39b57dce81d50faa4a9ba4, assets 691ff275d43c2e60bd8d6aa18efd2c000b36df3d, controller 1f38edfe1b5083d37ee8564a48ae9a4963b6d198. Creator passed one exact case/102 assertions (57.004s), child exit0. Fresh loader reached restored Day4 and failed one of64 assertions (41.893s), exit1. This was not the120s outer timeout. Both processes shared the isolated user root. All prep/source gates passed.

The only failure was the helper expecting Button.pressed on reading-rail Save. The actual WitnessedTransportButton owns pointer handling and emits activated; WitnessedTransportRail connects that signal to Save. Ordinary Backup controls still use pressed. This deterministic observer contract error prevents interpreting zero pressed as a failed click. The test returned before checking Backup visibility, so no evidence establishes whether the actual click opened it. No witness save/Day5/ending occurred in the verified test path; do not connect this result to the exported ending timeout.

Correction: observe activated only for the exact transport type, pressed for ordinary buttons. Keep the same target, one physical click, geometry/readiness checks, time bounds and subsequent actual sheet assertions. No production change or retargeting to a different Save control is justified. Independent reviewer and author confirmed the mismatch and acknowledged missing it in initial review.

Both original ZIPs retained unchanged under originals, ordered512KiB parts and providerSHA256/Gitblob identities in archives.json. All22uploaded blobs hash-verified.
