# Independent review — call-local equality hash reuse

Disposition: **PASS for candidate preparation**, conditional on completed review of the current admission run before any subsequent cloud comparison. This is not execution or performance acceptance.

Baseline product `02a6e275dc3188921edc1fc08ac423c08b306a1e`, contract SHA256 `0ed73a5e8a1e691f1712d90cb75b45905b48e83535f9dd244b281369cb6c1eae`. Candidate SHA256 `67c2c23286de1fb1318b6c68473701367114a2e9b01c2301e0ef6d1bccd98851`. Independently verified manifest SHA256/Git blob and exact reconstruction: replacing only the new `_equal` body with the old body yields every original byte. No public entry, admission helper, live callback, recovery branch, writer implementation or test changed.

Current CanonicalJsonWriter was read via GitHub at the baseline product; blob `2ce8da69f351e4ba858742e90136cd2bab612253`. Its stringify and nested emitters only inspect values, allocate temporary encodings, sort local key arrays and perform deterministic parsing/hash input construction. They neither invoke caller objects nor mutate the input nor yield. RegEx matching and static patterns do not alter the encoded value. `_sha` retains its exact success-string hash / failure-empty-string behavior.

Equivalence by reachable branch:

| Condition | Old and new behavior |
|---|---|
| `_same_types` false | Return false before invoking either hash. |
| First actual serialization fails | Actual hash is empty; return false without hashing expected. |
| Actual serializes; expected fails | Nonempty actual compared to empty expected; return false. |
| Both serialize | Compare the same canonical SHA256 strings. |

The removed operation is only the second immediate successful `_sha(actual)`. No callback, await, input mutation, filesystem read or authority boundary lies between its two original calls. Hashes and all type/first-failure gates remain the same; hash collision semantics are unchanged. Existing recursion behavior in `_same_types` is untouched, not repaired or expanded by this candidate.

The existing38 public-facing unit cases cover exact event/admission reconstruction, nested result/preimage changes, changed registration, issuer/child forgery, strict types, public fresh revalidation and detached outputs. They exercise equality through actual contract callers. They do not explicitly force a CanonicalJsonWriter failure inside `_equal`; most malformed inputs are refused earlier. That limitation is acceptable for this mechanically equivalent elimination because the identical first actual-hash failure and short-circuit are retained. No test that merely mirrors the private helper or counts hash calls is needed.

Preserve the existing38-case regressions and bounded restored-journey/durable/readback comparison, with unchanged observation flags and deadlines. No source-derived percentage saving should be reported as whole-operation speedup. The full restored result must be inspected before promotion, and current admission-run originals must be retained before this candidate is dispatched.
