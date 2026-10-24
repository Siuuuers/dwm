# Single terminal ledger qualification — PR82

Final candidate `e31ebf580db251b01c5417ce1171b99d13b5da8d` has the same runtime and tests as measured candidate `2c014e11198b853278be4fd1e63b8fbd0e68133f`; it adds committed inventory updates only. The baseline is PR81 candidate `6c8b5bcf01b6264253d8d918558a005ac941a770`.

Accepted current product coverage: **136 cases / 1,887 testcase assertions**, no failures or skips. The terminal suite now has 190 assertions for the approved single-ledger contract; removed second-ledger refusal expectations are not claimed as passing. Matched comparisons add **8 case executions / 852 assertions**, reported separately. Historical retained-input XML and setup assertions are excluded.

Both ordered pairs improved measured complete UI operations: Save press-return by 18.24% and 13.79%; retained Load Ready by 7.01% and 6.32%; fresh-process Load Ready by 6.03% and 7.53%. All four semantic Ready payloads match; reviewed terminal screenshots retain the same complete caption and backdrop. These are Windows source-project software-rendered comparisons, not a latency distribution, universal speedup guarantee, or installed Steam acceptance.

`results.json` records exact pins, native counts, measurements, qualifications and limits. `current-case-census.json` lists raw current XML cases. Seven original artifact ZIPs were checked against their metadata digests, byte sizes and ZIP CRCs. `manifest.json` maps all original artifact members to unique byte objects in `exact-evidence.zip`; ZIP container bytes are not retained. Exact controller patches are included separately and must not be merged as product runtime.
