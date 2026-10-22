# Ending aggregate observation result — run39745466691

Disposition: SUCCESS for the short direct-ending observation. One GUT case / 69 assertions / zero failures, errors or skips; child exit0; testcase34.440906s. Fresh Accept reaches durable COMPLETED/GALLERY_RECORDED and Title, retaining the Gallery receipt and premature-input refusal checks. Independent review: review.md.

Run: https://github.com/Siuuuers/dwm/actions/runs/39745466691
Product0b9095e5c63275bc4721cd257413d286bcd958b0; assetsdf1f5df3f2a62ca871fbcd9bcdf0d98bb5c249c5; controllerab23ee7f8327b8be96a7fbd69f57d4032b563cc6.
Actual event workflow commit de5db6cda7a7c76f55806d10fbc3e02448d65117 fetched: workflow blob b7d3cfb53316adca4566ef823e8f17b6888029d2 matches reviewed controller.
All four custody policies,24source receipts,nine aggregates and helper identities reviewed. Original two ZIP digests match GitHub; all5299members match extracted bytes;5205 content-addressed retained byte files rehashed. Originals preserved byte-for-byte in25ordered512KiB-or-smaller parts; concatenate each archive's ordered parts from original-archives.json and check its full SHA256 before extracting.

## Measured result
Final Accept22.743922s; writers6.070841/7.470135/8.352420s.
Configuration48calls/1.709215s (~7.5% of Accept).
Compilation384calls/1.546865s (~6.8%), INCLUDED within configuration.
Captures219/305/272microseconds; atomic writes3.648–3.945ms.
Never sum inclusive parent/child totals. This is not a matched optimization comparison.

Per-operation configuration stays~0.28–0.29s while outer prepare/commit grows~3.0–4.2s. Thus measured compilation/configuration does not account for most of this short-route delay.
Prepare metadata regions grow0.947428/1.627269/2.112682s; outgoing proven-journal regions0.983134/1.667485/2.066101s. Source audit establishes both regions include full recovery-journal bundle validation, despite their names. It does not establish individual suboperation costs. saved_time is empty for this prepare caller.

## Next bounded outcome
See source-audit.md. Add narrow opt-in subphase observation to existing SaveDocumentSchema proof/composition/journal-validation regions and individual existing journal-bundle validations. Preserve function results, early refusals, ordering, three checkpoint boundaries, saved bytes and deadlines. Review before one new dispatch; no cache, bypass or checkpoint removal justified yet.

## Limits
No full restored-history journey, exported-gameplay, arbitrary interruption, performance improvement or broad-CI acceptance. Separate Windows run39745466466 failed committed-public-inventory gate, with downstream skipped journeys and failed retained-history requirement; not a focused observation failure. No new test dispatched in this evidence-review turn. No merge/release or product promotion.
