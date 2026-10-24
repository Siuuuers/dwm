# Selected recall ledger qualification — PR81

Current selected-ledger validation reuses the canonical registration when resolving a retained Challenge recall. Standalone arbitrary-bundle callers continue fresh structural validation. No second-ledger removal is included.

The final candidate is `6c8b5bcf01b6264253d8d918558a005ac941a770`. Runtime matches the initially measured candidate exactly. The correction changes one terminal test expectation from two to three avoided structural checks and commits regenerated inventory hashes.

Accepted product coverage: **136 current cases / 1,910 testcase assertions**, with no failures or skips. Two matched comparison orders add **8 case executions / 852 assertions**; these repeat test bodies and are reported separately. The initial failed terminal report is retained. Historical input XML is excluded from current coverage.

Save press-return improved 13.64% and 7.11%; fresh-process Load Ready improved 10.14% and 10.58%. Retained Load Ready changed −8.61% and +1.59%. These are two ordered pairs on Windows source-project software-rendered runs, not a latency distribution or installed Steam acceptance.

`results.json` holds pins, measurements, coverage and acceptance limits. `current-case-census.json` holds exact current XML cases. `original-artifacts.json` and `manifest.json` map eight verified original artifacts to every unique uncompressed member in `exact-evidence.zip`. The original ZIP containers are not retained; their exact hashes and member mappings are. Both controller patches are preserved separately and must not be merged as product runtime.
