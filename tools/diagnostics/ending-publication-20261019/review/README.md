# Internal reviews and coherent local checks

These are internal implementation/evidence reviews, not external Coordinator C
review or native gameplay acceptance.

- `receipt_review` prepared and froze the native observer, verified its primary
  C API/source semantics, independently reviewed the separate reader and fixtures,
  and reviewed the investigation README. The reader timing rule was tightened to
  require capture start after window-open/prior-row observations. README wording
  now refers to reconstructed retained ancestors and the insufficient ordering
  experiment without rejecting every ordering-related cause.
- `receipt_tests` independently implemented the prepared-graph reader and eleven
  focused methods, reviewed binder integration gaps, then authored five synthetic
  integration methods with fourteen cases. The coordinator reviewed all bodies
  before the final coherent run and corrected the deployed reader lookup path.
- `cloud_comparison` retained primary engine/release/build provenance and reviewed
  the native build, package, controller and binder. Corrections bind dependency
  assets before/after download, bound smoke cleanup, exclude compilation objects,
  seal evidence before fallback upload, bind exactly two native source paths and
  patch/protocol source pins, and qualify clock/cutoff claims.
- Coordinator A alone owns shared binder/controller integration and publication.
  Independent audits completed before the coherent staged-layout Python run.

`reader-tests.log` records eleven passing methods. `binder-tests-result.json` and
`binder-tests.log` record five passing methods with fourteen explicitly synthetic
cases, zero failures/errors/skips. `static-checks.json` binds the checked Python
and controller-template bytes. These checks did not execute Godot, PowerShell,
MSVC or Windows UIA. The same Python bodies and real PowerShell parsing/deadline
checks run on cloud before native compilation.

No official-engine acceptance is established. Existing failed native results
are neither edited nor reclassified by these fixtures.
