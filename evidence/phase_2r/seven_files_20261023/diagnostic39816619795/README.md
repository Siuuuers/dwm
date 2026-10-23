# Confirmed mismatch and correction

Run39816619795 failed. Original ZIP603917 bytes, SHA256 7ff247aebe9631ed9089e07697a3e0652a043609248d403964580ddb3a3c8633. Binary concatenate part1 then part2.

Actual marker result: reading_checkpoint_invalid / Run9 requires a complete scene checkpoint. RunSnapshotSchema requires checkpoint.content_version == candidate.content_version; Bootstrap's narrative contract remains1. The split introduced day version2 while retaining global/ending1. Fix606cf0b5a1b90a590babe16682d7a45afc58b568 restores day content version1, updates assertions/docs and removes both diagnostics. No runtime/save-owner changes. Independent review approved: changed locators+content hashes still change full registration fingerprint; Bridge and session restoration reject old fingerprints. No old-save migration.

Corrected qualification run39817290512 uses existing deadlines. Do not promote until results pass.
