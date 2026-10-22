# Clean publication reader readiness packet
Product41e03888e966a57faed27286920f164c46db223a parent340239 changes only manual regression fixture; production runtime/resources unchanged. External assets875d695779e7ed7f9804a86a41a0912eb8ccc2e1 parent453 change isolation helper, manifest and preparation PRODUCT pin.
Test-only handshake follows mounting of frozen reveal and precedes original publication assertions. It reuses existing atomic reader receipt; requires current enginePID, completed discovery, observed/identity_verified native provider, native_provenance_complete event and no reader/native error. Missing env/foreignPID/completed or failed reader fail closed. Separate5000ms readiness bound; all existing5000ms publication/input waits and120s child/reader caps unchanged. Final consumer lifecycle validation remains mandatory.
Child ProcessStartInfo removes stale inherited readiness pointer and sets exact fresh receipt path only for native consumer, without changing parent environment. Timestamped CONTINUE_READER_READY preserves readiness attribution.
Native reader unchanged from precompile candidate; no native operation reordering, production synchronization or artificial game delay.

Manual SHA72ca10041f21cd14b6f8dbf0458b82f6b607301149d18faa6f3f038634a31828.
Isolation SHAa8b5c2452ccd9bbf18e362f9b526efdf5af62ac4f95a0074a853a97dcc9bc76e.
Manifest SHAe8e91c08fa2c27c6e6725d271cda7ac103b78736175b764dc34f1ca4452f74dc.
Preparation SHA34575a34d0e60871a0720c051bbaec22f116ad7fd6b50a848e5d8623467778ad13836bytes.
Controller SHA9a7d216e1095266853cd4559662fed5bd06e8480b1a7f0c119b64146ff890ae013841bytes blob27e64f4282af15e3317fd8ae04bc728e237026af.
Source review passed; final exact remote pins checked before one corrected cloud9case run. Prior failed originals39720030361/39720816043 retained unchanged. No local Godot/PowerShell, merge/release or held refs movement.
