# Scene challenge checkpoint publication

On `52d54e3`, a board action published a live reading reference. Its checkpoint path recaptured the Run and compared deep copies and fingerprints around a synchronous call. It also carried challenge-specific journal checks in the separate autosave path.

GameState checks the active lease, challenge, record and current reading boundary, then admits its captured snapshot and checkpoint for one call. The checkpoint port checks that pair with the owner and returns the canonical reading fingerprint. The publication has no disk operation, signal or yield between admission and return. Explicit Save still persists the board. Loading a save restores that board and its reading position.

The private challenge-validation phases and challenge-only journal source checks had no saved fields. The older implementation is available at the revision above.
