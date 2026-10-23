# PR reconciliation provenance

Final candidate: `7c46453f879c5ce3599c18fecfa19176beee85f5` (`codex/final-integration-20261024`).

GitHub compare confirms both previous PR52 `e5cf80a5417c05bd0bb7fa2f60f59e8905e839a6` and current master `894a9f2f2df65b5b87b0562ea1a2e7bc5fb5b1ef` are exact ancestors (behind=0). The final candidate retains master’s Steam changes. This is source ancestry evidence, not final CI or merge acceptance.

35 open draft PRs were inspected. No remote mutation was made. After final qualification, merge the consolidated candidate with ancestry preserved, then inspect automatic closures and reconcile superseded drafts. Do not merge divergent old source merely to change PR status.

| PR | Exact audited head | Disposition |
|---|---|---|
| #1 | `a6decec3693ee4d57df9f879b90ace3e118c9d1d` | exact ancestor protected reference |
| #4 | `85f29f832dfa627ec128a413922e0daf9dff69f5` | exact ancestor |
| #5 | `e5db010715c187cc775341d204391f527dc334ea` | exact ancestor |
| #6 | `feb39dd0d72af169ccf640bf747b1e370f24f178` | exact ancestor |
| #7 | `af9440207e0b0f7672c4b13eacd3aa904f4416f7` | exact ancestor |
| #8 | `e7fbf747cf501f7010253af3d07f38fe3ea0c83c` | incorporated with later evolution |
| #9 | `452ab34e39f6a3d6e91c4125954b092d9a499e87` | incorporated with later evolution |
| #10 | `ab33586a3e10aed1e853c6f3e9469022df2150b0` | exact ancestor |
| #11 | `544780814217bb7935c58b5a7b7f5885cc0f77ef` | exact content incorporated |
| #12 | `5269dc80a1b66bebd49f13482ee5d13a0a986d98` | incorporated with later evolution |
| #14 | `b37d662403398139fc2b1029853b236c334f59a0` | exact ancestor protected reference |
| #16 | `c8e07e4a1215097506d5483ee9d0d436e5b8021c` | exact ancestor |
| #17 | `08a2caa3108c625e890cf1a1c802d7529be6d54b` | incorporated with later evolution |
| #18 | `90a7319072a6c5c0703f093d16edf52e2cb04e73` | exact ancestor |
| #20 | `d2aacc316920a4198763b4835333b6535e601001` | exact ancestor |
| #22 | `1185f44539c52b9e8085ef51743056f92ac704d1` | incorporated with later evolution |
| #23 | `4c6752829a412f82349fa546f0e022df7ff6e7ec` | exact ancestor |
| #26 | `45dc2df466d52f79a03bf2a4a640b1a160e8c257` | incorporated with later evolution |
| #27 | `3ae6d9138fb53c388380c78550cf6082eafc0ea3` | exact ancestor |
| #28 | `b29005cc989033092881942ddcd6203d0e1e07fb` | incorporated with later evolution |
| #30 | `7d96a2487821a35464ee7852ed495aba2e0b60c7` | diagnostic controller |
| #31 | `94f79da0c46e94a28155635b7a9d32c8471031fe` | incorporated with later evolution |
| #32 | `424e0a917e77c13c143088a1e018e01a8cac0c31` | incorporated with later evolution |
| #36 | `c8358870d3ece92d5f8cc7ba65aefe34a746be5c` | exact ancestor |
| #37 | `91824fbf5628959cc8a4c389660f140b8793a0a1` | incorporated with later evolution |
| #38 | `63e0738fbc786a8f8c7bd66e9f7b27f4e3ede5a9` | historical documentation not incorporated |
| #39 | `9db56fd4144de9be63615b4dbaad56bd8187beeb` | incorporated with later evolution |
| #40 | `d45d12f52abc56c43f331d8ca1e83621265408c1` | exact content incorporated |
| #42 | `e8ab9c99473a207e3a455a3fb1af1ceb05d182fb` | exact ancestor |
| #43 | `e2d1cd5c3500d2178fcbc483495010a1922d3f0f` | implementation superseded unique historical records retained |
| #47 | `a226f61115e739972df3ec7e7eca47a03b5bac13` | exact ancestor |
| #49 | `fe3d7614777f364010cb97c9ac94c075e181de7f` | exact ancestor |
| #50 | `7dab26a826b8fc2c5929625fe3d70d4d90c1ed84` | diagnostic controller |
| #51 | `328edfe082c84bd9f6ca0a9d45e6603e0902695c` | exact ancestor |
| #52 | `e5cf80a5417c05bd0bb7fa2f60f59e8905e839a6` | consolidated integration |

## Historical and protected references

Preserve these branches and exact heads; branch names can advance, so use the pinned hashes for historical retrieval.

- #1: `codex/windows-cloud-ux` at `a6decec3693ee4d57df9f879b90ace3e118c9d1d` — No separate source merge; preserve coordination/archive branch and records.
- #14: `codex/scene-foundation-combined-20261008` at `b37d662403398139fc2b1029853b236c334f59a0` — No separate source merge; preserve coordination/archive branch and records.
- #30: `codex/scene-runtime-integration-controller-20261009` at `7d96a2487821a35464ee7852ed495aba2e0b60c7` — Exclude from product merge; retain controller branch and evidence.
- #38: `codex/c-work-reconciliation-20261016` at `63e0738fbc786a8f8c7bd66e9f7b27f4e3ede5a9` — Preserve exact pinned branch/head; close only as historical/superseded, not wholly incorporated. Do not overwrite current handoff/report.md.
- #43: `codex/seven-day-story-20261023` at `e2d1cd5c3500d2178fcbc483495010a1922d3f0f` — Preserve pinned branch/head and independent build branch; reconcile runtime as superseded, keeping historical export receipts at original source.
- #50: `codex/story-day-qualification-20261023` at `7dab26a826b8fc2c5929625fe3d70d4d90c1ed84` — Exclude from product merge; retain controller branch and evidence.

PR38 retains the absent dated `handoff/c-remaining-work-20261016.md` and the original `handoff/report.md` revision. This historical snapshot explicitly has no current status/behavior/verification authority. Its old191-record/23unfinished count is not a current backlog.

PR43 retains26 historical export/publication files from runs39842240751,39842766427,39843283227,39843770556 plus `handoff/a-resume-20261023-authored-week.md`. No runtime/test path from that proposal is missing in the refreshed comparison. The exact27 paths and blob IDs are in the JSON. Keep `builds/windows-playable-20261023` separate; old package evidence does not qualify a new final source.

The exact ancestor group needs no additional code merge. #11’s3 proposal files and #40’s sole handoff are exact-content incorporated. Remaining evolved proposals are supported by the retained master-integration proposal audits; current owner changes supersede earlier implementations. #32’s previously missing3-case Backup desktop-entry regression is now present and its3/78 scoped pass is recorded in the integration handoff.

Preserve production Notes, Schedule-deletion and legacy-assignment-migration holds. Do not turn scoped historical evidence or metadata reconciliation into release/full-game acceptance.
