extends "res://addons/gut/test.gd"

const SCRIPT_PATH := "res://tools/git/Invoke-ExactPathCommit.ps1"


func test_exact_path_commit_contract_tokens() -> void:
	assert_true(FileAccess.file_exists(SCRIPT_PATH), "missing_script")
	if not FileAccess.file_exists(SCRIPT_PATH):
		return
	var source := FileAccess.get_file_as_string(SCRIPT_PATH)
	var required_tokens := [
		"[System.Collections.IDictionary]$RequiredStatus",
		"[System.Collections.IDictionary]$OptionalPresentStatus",
		"[string[]]$AllowedDirtyPaths",
		"[string[]]$WhitespaceExemptPaths",
		"[string[]]$RequiredAuthorityVariables",
		"[string]$ExpectedHead",
		"[switch]$RequireRemainingDirtyExact",
		"[string]$Message",
		"DWM_COMMIT_AUTHORIZED",
		"Missing exact extra authority",
		"diff','--cached','--quiet",
		"Staged index is not empty.",
		"HEAD differs from the required parent boundary.",
		"--find-renames=50%",
		"--find-copies=50%",
		"--find-copies-harder",
		"Invoke-GitSafe",
		"$_ -isnot [Management.Automation.ErrorRecord]",
		"'diff','--cached','--raw','--no-abbrev'",
		"Required path has unstaged/partial content.",
		"Whitespace exemption is restricted to immutable Phase 2R logs",
		"Remaining worktree paths differ from the exact allowed-dirty set.",
		"'rev-list','--parents','-n','1'",
		"sole direct child of the expected parent",
		"'diff-tree','--no-commit-id','-r','--name-status'",
		"'diff-tree','--no-commit-id','-r','--raw','--no-abbrev'",
		"EXACT_PATH_COMMIT: PASS",
	]
	for token: String in required_tokens:
		assert_true(source.contains(token), "missing contract token: %s" % token)


func test_exact_path_commit_rejects_non_regular_blob_modes() -> void:
	assert_true(FileAccess.file_exists(SCRIPT_PATH), "missing_script")
	if not FileAccess.file_exists(SCRIPT_PATH):
		return
	var source := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(source.contains("$expectedOld = if ($status -eq 'A') { '000000' } else { '100644' }"))
	assert_true(source.contains("$expectedNew = if ($status -eq 'D') { '000000' } else { '100644' }"))
	assert_true(source.contains("$status -notin @('A','M','D')"))
