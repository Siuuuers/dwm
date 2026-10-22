# Short ending checkpoint preparation comparison — launch

Reviewed diagnostic only; no production edit, merge, release, or restored-journey acceptance.

- Product: b0c6ac928371ed849bb4c7f6a37d8921465aade9.
- Assets: 66ff24b8096bbf4245bfc2e27634c8df3cfe6cc6; tree 1b5f7253a070386221e776374d3aa174a4608389.
- Controller: f588be78ae850ed490f187ae59937880b7ef3efa; workflow blob 4f7e9364304e28219c61e2301ad37f63048252f8; SHA256 aca61eebe1caa4c575efea7a815895e1c94bbcf1f01a9360935f5193749be480.
- Test: test_scene_ending_direct_return.gd::test_direct_ending_accept_returns_without_save, real rendered input, existing 120-second child deadline.
- Harness: cc0d9a1afc0371ba6623610c752443f1627742221606a5b531ca44727f41195a.
- Independent source/packet reviewer cleared exact immutable assets and controller before publication. Source/master/integration/PR36 reconciled unchanged. Previous two controller runs completed; no overlapping diagnostic launched.

Observable outcome: the existing short direct-Day7 ending transition returns with durable COMPLETED/GALLERY_RECORDED and Title, with returned checkpoint prepare/commit profiles and writer markers. The test observes existing Bootstrap writer and retained checkpoint port; production ownership stays unchanged.

Failure interpretation: absent profiles after timeout do not prove deadlock; original logs/artifacts must be retained. Exact one case, no skips/errors, viewport witness and source custody remain required. Profiles are nested durations and must not be added together. Returned-only production profiles cannot locate an interrupted inner phase. The short history cannot qualify the restored full journey.

Next: consume the single run, verify controller/product/assets, all preparation policies, original ZIP hashes and JUnit/markers/profiles. Preserve failed evidence too. Do not repeat accepted baseline, lengthen deadlines, or change production based only on source suspicion.

Run: https://github.com/Siuuuers/dwm/actions/runs/39739944128 (in progress at handoff). Ordinary CI39739944158 is separate.
