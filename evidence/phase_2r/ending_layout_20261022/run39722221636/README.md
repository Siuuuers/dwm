# Ending baseline attempt 39722221636 — invalid test setup

The cloud job failed before any test executed. GUT loaded test_scene_ending_direct_return.gd and rejected line 53: inferred Variant from weakref(prior_layout), with warnings treated as errors. JUnit contains zero cases. There is no ending observation JSON or viewport capture, so this run supports no ending ownership or completion finding. Child exit 0 did not bypass the wrapper's runtime-error gate.

All preparation/import/restoration/post-test source policies passed. Both original artifact ZIPs are retained under originals with exact provider SHA256 and ordered part hashes in archives.json. Correct only the test declaration to explicit WeakRef; keep production Bridge unchanged and rerun the same bounded baseline. Corrected source 3f346680c90ab53b4e68bfd187f44bc8fca50961, assets ab362e5ca5f7089286bd679173bdbbc7af8d832e. Independent source review found no other concrete same-type inference issue.

Reviewed controller blob 65727fe32f4823fea77738c77636939abfd07e82 is 13804 bytes, SHA256 4e2a5c102ed5aa18a5f7156899c44e6400c1f466f06a0bc7967d74d14feca2b3, including two terminal newlines. It differs from local controller-fixed.yml only by one trailing newline; this remote blob is the installation authority.
