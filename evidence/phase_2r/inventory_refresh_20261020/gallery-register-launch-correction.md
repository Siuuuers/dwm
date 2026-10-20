# Gallery qualification launch correction — 20 October 2026

Consumed external C6285277745 / relay6285280384: source27fe2eb5 and controller6914f3eb cleared for ONE focused run under Director6284909302. Product remains a01497d17eafd2ea512aa530fd12f33dbd622db8; source candidate27fe2eb5dbea6345e62d83c611146a2e5199a944/treeed3493c40dc36d8346e42ee60d466e01bcc53ee3 unchanged.

Installed exactly reviewed workflow blob6914f3ebd78893798b8641da814b7d1ef74f47ca at PR30 controller3aaa875ba6115ef7bddc2f254bb09c96efede8da using expected-head protection fromcd494d34. Pre-installation latest runs were completed; product/base unchanged.

Launch issue: reviewed workflow declares only workflow_dispatch. The connected GitHub tools expose no dispatch operation, and the signed-in workflow page exposes no Run workflow control. Prior successful controller used pull_request with this workflow's path filter and PR30/same-repository job guard. No focused Gallery run started. Installation naturally triggered ordinary Windows run39384356877, observed in_progress; it is incidental CI, not the authorized focused result and not a manual broad dispatch.

Prepared a launch-only correction as gallery-register-controller-pr-trigger.yml for C's bounded review: replace workflow_dispatch with the established workflow-path-filtered pull_request event; add existing PR30/same-repository job guard; record controller from event.pull_request.head.sha and separately retain GITHUB_WORKFLOW_SHA because PR event workflow and controller head can differ. Source/tree pins, engine, runner, all steps/deadlines/error/exit gates and evidence census remain unchanged. YAML and embedded Python syntax checked; no Godot/PowerShell execution.

Do not install this correction until C reviews its exact delta. Installation on PR30 will itself trigger the ONE focused run; do not also dispatch/retry it. Reconcile active runs/heads first, then retain actual event/controller/source identities and first failure. Original C-reviewed controller remains installed pending this correction; do not change master/default branch to make manual dispatch available.

No product source/integration, runtime/save/history change or pass claim. C's subsequent concrete result review still precedes product integration. Known33.179067s and official exported completion/Title/fresh Load/normal clean exit remain open. No new native run or release.
