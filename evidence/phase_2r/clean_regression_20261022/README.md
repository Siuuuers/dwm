# Clean regression candidate: local and unqualified

Product base remains3801d05934aadbe78741e7db3f3bebd36436d7cf. Integrate only the two files under tests after review. The integration fixture starts from clean958ab5e blob e988009df7cd5f6c3546f686e8870c5c7611ea3f and initializes real in-memory Profile/Localization owners specifically for the projection/source-admission test; its prior setup could not satisfy Continue readiness. Existing admission, History and stale-callback assertions remain unchanged. The manual fixture starts at clean958 blob82b5fdcadfd749215bc341dd825518a2e18df88f and adds only the later real in-memory Profile/Localization initialization, readiness and mounted label/admission assertions. Both completion bodies and5000ms waits remain unchanged. No registration metadata, phase hooks or diagnostic observation test remains.

Stage tools/testing as an external harness directory; do not copy these files into the product checkout. They derive from immutableb430cf2966d87d0da73f0d506f6acd89eecf6fa6. Only two harness files changed: the publication runner adds the ninth exact projection case, locates the sibling isolation helper and passes explicit RepositoryRoot; the isolation helper accepts that root (old location retained as default) and allows native consumers only for organic/manual suites, removing the diagnostic initial-observation lane. Five helper dependencies remain exact source blobs. The native reader uses process/window identity and COM operations, not diagnostic Godot metadata or emitted observation snapshots.

Cloud invocation with official standard Godot4.6.3 console path already configured:

```powershell
pwsh -NoLogo -NoProfile -NonInteractive -File <external-harness>/Invoke-ContinuePublicationChecks.ps1 -RepositoryRoot <clean-test-checkout> -ExpectedSource <full-clean-test-commit> -NativeProviderProvenance
```

Retain .godot/ci/continue-publication and .godot/phase2r_logs. The runner executes exactly nine individually selected cases: original organic, manual, pointer, keyboard, touch, review, speech-start and speech-cancel, followed by projection/source-admission, with native consumers only for the first two. Preserve its JUnit exact selection, isolation, reader identity/lifecycle, engine/log and exit gates. Setup does not need runtime instrumentation. Source commit must identify the actual two-test-file candidate rather than production base alone.

Prior run39716672453 passed eight cases/153assertions on the diagnostic fixture. That is not qualification of this clean composition; removed diagnostic assertions may change its assertion total. Require independent exact source review and targeted cloud qualification. No local PowerShell/Godot execution has occurred. The ninth projection/source-admission case has no native consumer. This newly included case and its initialized setup are unqualified until the targeted run; the original eight names and paths remain unchanged.

No exported journey repeat is proposed if review establishes only these excluded test files change and all packaged runtime/resources remain identical. The active export run stays on3801d. manifest.json records candidate bytes and Git blob identities.
