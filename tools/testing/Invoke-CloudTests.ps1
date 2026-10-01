param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('minesweeper', 'shop', 'desktop', 'settings', 'checkpoint_diagnostics', 'new_account', 'reading_delivery', 'localization', 'dating', 'persistence', 'endings', 'audio', 'public_surfaces')]
    [string]$Suite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Deliberate, bounded UI and input regression coverage. Each path must actually
# execute; Invoke-IsolatedGodot also rejects GUT's silent suite-load failures.
$suites = @{
    public_surfaces = @(
        'tests/unit/tooling/test_public_surface_inventory.gd'
    )
    # Isolate the new fixture without removing its order/interaction coverage in Settings.
    checkpoint_diagnostics = @(
        'tests/unit/test_checkpoint_phase_diagnostics.gd'
        'tests/unit/test_normalization_identity.gd'
        'tests/unit/test_checkpoint_history_region_search.gd'
        'tests/integration/test_warm_outgoing_proof_commits.gd'
    )
    persistence = @(
        'tests/unit/test_frozen_run_context.gd'
        'tests/unit/test_profile_presentation_chronology.gd'
        'tests/unit/test_profile_dating_attempts.gd'
        'tests/unit/test_profile_dating_branches.gd'
        'tests/unit/test_profile_pair_form_witness.gd'
        'tests/unit/test_contact_invitation_state.gd'
        'tests/unit/test_seven_day_calendar.gd'
        'tests/unit/test_pair_deck_draw.gd'
        'tests/unit/test_pair_deck_draw_port.gd'
        'tests/unit/test_profile_v4_upgrade.gd'
        'tests/unit/test_profile_new_run_consumption.gd'
        'tests/unit/test_save_migrations.gd'
        'tests/integration/test_save_manager_journal.gd'
        'tests/integration/test_restore_transaction.gd'
        'tests/unit/test_reading_restore_admission.gd'
        'tests/unit/test_reading_next_checkpoint.gd'
        'tests/integration/test_unified_restore_contract.gd'
        'tests/integration/test_run_restore_isolation.gd'
        'tests/integration/test_live_run_rollback_isolation.gd'
        'tests/integration/test_save_manager_public_boundaries.gd'
        'tests/integration/test_save_capability.gd'
    )
    endings = @(
        'tests/unit/test_ending_frozen_context.gd'
        'tests/unit/test_day7_condition_ending.gd'
        'tests/unit/test_ending_completion_durability.gd'
        'tests/unit/test_ending_presentation_signature.gd'
        'tests/unit/test_dialogic_ending_playback_port.gd'
        'tests/unit/test_run_lifecycle.gd'
        'tests/unit/test_dating_ending_rules.gd'
        'tests/unit/test_dating_ending_rules_migration.gd'
        'tests/integration/test_ordered_ending_playback.gd'
        'tests/integration/test_ending_dialogic_wiring.gd'
        'tests/scenario/test_day7_endings.gd'
        'tests/scenario/test_day7_schedule_provenance.gd'
    )
    audio = @(
        'tests/unit/test_audio_manager.gd'
        'tests/unit/test_audio_settings_transactions.gd'
    )
    dating = @(
        'tests/unit/test_active_dating_backup_capture.gd'
        'tests/integration/test_dating_quick_commands.gd'
        'tests/unit/test_frozen_presentation_context.gd'
        'tests/unit/test_dating_narrative_playback.gd'
        'tests/unit/test_canonical_dating_mastery.gd'
        'tests/unit/test_dating_attempt_runtime.gd'
        'tests/unit/test_profile_evidence_v8.gd'
        'tests/unit/test_dating_physical_owner.gd'
        'tests/unit/test_dating_capability_envelope.gd'
        'tests/unit/test_dating_rehearsal_owner.gd'
        'tests/unit/test_dating_presentation_port.gd'
        'tests/integration/test_ordered_ending_real_runtime.gd'
    )
    minesweeper = @(
        'tests/unit/test_minesweeper_theme.gd'
        'tests/unit/test_minesweeper_palette_components.gd'
        'tests/unit/test_minesweeper_app.gd'
        'tests/unit/test_minesweeper_cell.gd'
        'tests/unit/test_gallery_rehearsal_host.gd'
        'tests/unit/test_minesweeper_dock.gd'
        'tests/unit/test_minesweeper_register.gd'
        'tests/unit/test_minesweeper_panel.gd'
        'tests/unit/test_minesweeper_worksheet.gd'
        'tests/unit/test_minesweeper_worksheet_layout.gd'
        'tests/unit/test_minesweeper_worksheet_view_layout.gd'
        'tests/unit/test_minesweeper_view_controls.gd'
        'tests/unit/test_minesweeper_view_preferences.gd'
        'tests/unit/test_minesweeper_zoom_input.gd'
        'tests/unit/test_minesweeper_scroll_rail.gd'
        'tests/unit/test_minesweeper_sheet_controls.gd'
        'tests/unit/test_minesweeper_information_sheet.gd'
        'tests/scene/test_minesweeper_toggle_bindings.gd'
        'tests/scene/test_minesweeper_new_board_bindings.gd'
        'tests/scene/test_minesweeper_view_gestures.gd'
        'tests/scene/test_minesweeper_challenge_controls.gd'
        'tests/integration/test_minesweeper_desktop_host.gd'
    )
    shop = @(
        'tests/unit/test_shop_app_purchase_bridge.gd'
        'tests/unit/test_shop_catalog_projection.gd'
        'tests/unit/test_shop_presentation_port.gd'
        'tests/scene/test_shop_card.gd'
        'tests/scene/test_shop_plate.gd'
        'tests/integration/test_shop_desktop_host.gd'
        'tests/integration/test_minesweeper_shop_transaction.gd'
        'tests/unit/test_minesweeper_shop_purchase_participant.gd'
    )
    desktop = @(
        'tests/unit/test_application_runtime_lifetime.gd'
        'tests/unit/test_contacts_frozen_context.gd'
        'tests/unit/test_desktop_panel_split.gd'
        'tests/desktop_shell/test_desktop_split_touch.gd'
        'tests/unit/test_desktop_touch_navigation.gd'
        'tests/unit/test_desktop_app_host_state.gd'
        'tests/unit/test_desktop_accessibility_contract.gd'
        'tests/integration/test_desktop_quick_commands.gd'
        'tests/integration/test_desktop_bootstrap_wiring.gd'
        'tests/unit/test_desktop_cold_recovery_preparation.gd'
        'tests/integration/test_schedule_desktop_host.gd'
        'tests/integration/test_phase2r_schedule_desktop_handoff.gd'
        'tests/unit/test_schedule_app.gd'
        'tests/integration/test_contacts_run_presentation.gd'
        'tests/scene/test_controls_input_contact_release.gd'
        'tests/unit/test_angela_stat_overlay.gd'
        'tests/unit/test_stat_hud_week_tint.gd'
        'tests/integration/test_ui_art_placements.gd'
        'tests/integration/test_desktop_logout_consent.gd'
        'tests/unit/test_session_exit_coordinator.gd'
    )
    settings = @(
        'tests/unit/test_save_manager_parse_cache.gd'
        'tests/unit/test_backup_quick_actions.gd'
        'tests/unit/test_settings_panel_resize.gd'
        'tests/unit/test_settings_preference_registry.gd'
        'tests/unit/test_shared_week_tint.gd'
        'tests/unit/test_settings_window_transactions.gd'
        'tests/unit/test_window_mode_manager.gd'
        'tests/unit/test_window_mode_port.gd'
        'tests/unit/test_bootstrap_window_output.gd'
        'tests/scene/test_settings_window_mode_live.gd'
        'tests/scene/test_settings_audio_live.gd'
        'tests/scene/test_settings_reset_confirmation.gd'
        'tests/scene/test_settings_folio.gd'
        'tests/scene/test_settings_host_geometry.gd'
        'tests/scene/test_settings_localization_scene.gd'
        'tests/integration/test_settings_shared_hosts.gd'
        'tests/unit/test_profile_manager.gd'
        'tests/unit/test_profile_caption_witnesses.gd'
        'tests/unit/test_controls_binding_import.gd'
        'tests/unit/test_steady_interface_profile.gd'
        'tests/unit/test_restore_participants.gd'
        'tests/integration/test_restore_preserves_current_profile.gd'
        'tests/integration/test_restore_production_adapters.gd'
        'tests/integration/test_desktop_board_persistence.gd'
        'tests/integration/test_minesweeper_first_reveal_transaction.gd'
        'tests/unit/test_save_manager_checkpoint_port.gd'
        'tests/unit/test_checkpoint_validation_reuse.gd'
        'tests/unit/test_checkpoint_phase_diagnostics.gd'
        'tests/unit/test_checkpoint_journal.gd'
    )
    new_account = @(
        'tests/unit/test_canonical_writer_compatibility.gd'
        'tests/unit/test_continuation_serialization_cache.gd'
        'tests/unit/test_new_acc_title_lifetime.gd'
        'tests/unit/test_run_dark_configuration.gd'
        'tests/integration/test_prepared_new_run.gd'
        'tests/integration/test_new_run_transaction.gd'
        'tests/integration/test_new_run_pair_durability.gd'
        'tests/integration/test_new_run_startup_publication.gd'
        'tests/unit/test_new_run_durability_journal.gd'
        'tests/unit/test_json_file_storage.gd'
        'tests/unit/test_temporary_storage.gd'
        'tests/unit/test_save_document_schema.gd'
        'tests/unit/test_run_snapshot_schema.gd'
        'tests/unit/tooling/test_phase2r_closeout_sentinel.gd'
        'tests/unit/tooling/test_phase2r_schedule_gate.gd'
    )
    reading_delivery = @(
        'tests/unit/test_hospital_frozen_context.gd'
        'tests/unit/test_frozen_replay_context.gd'
        'tests/unit/test_minesweeper_delivery_notice.gd'
        'tests/unit/test_narrative_caption_ledger.gd'
        'tests/unit/test_solo_reading_session.gd'
        'tests/unit/test_solo_reading_catalogue.gd'
        'tests/integration/test_solo_authored_selector_witness.gd'
        'tests/integration/test_solo_authored_selector_runtime.gd'
        'tests/integration/test_dialogic_caption_variant_witness.gd'
        'tests/integration/test_dialogic_next_traversal.gd'
        'tests/integration/test_dialogic_skip.gd'
        'tests/integration/test_narrative_caption_ledger_runtime.gd'
        'tests/unit/test_witnessed_reading_rail.gd'
        'tests/unit/test_reading_pause_save.gd'
        'tests/unit/test_dialogic_pause_recovery.gd'
        'tests/unit/test_pause_surface.gd'
        'tests/integration/test_narrative_reading_frontier_runtime.gd'
        'tests/integration/test_narrative_pause_frontier.gd'
        'tests/integration/test_witnessed_caption_runtime.gd'
        'tests/unit/test_witnessed_pause_view.gd'
        'tests/unit/test_witnessed_auto_controller.gd'
        'tests/unit/test_witnessed_skip_controller.gd'
        'tests/scene/test_witnessed_transport_recovery.gd'
        'tests/integration/test_witnessed_speech_projection.gd'
        'tests/integration/test_dating_caption_style.gd'
        'tests/unit/test_scene_art_bindings.gd'
        'tests/unit/test_scene_art_hold.gd'
        'tests/unit/test_production_pause_controller.gd'
        'tests/scene/test_hospital_scene.gd'
        'tests/unit/test_day7_font_preferences.gd'
        'tests/unit/test_gallery_replay_owner.gd'
    )
    localization = @(
        'tests/unit/test_japanese_korean_ui.gd'
        'tests/unit/test_localization.gd'
        'tests/unit/test_localization_extraction.gd'
        'tests/unit/test_locale_font_preparation.gd'
        'tests/unit/test_gallery_typography.gd'
        'tests/unit/test_font_styles.gd'
        'tests/unit/test_ordinary_reply_echo_state.gd'
        'tests/unit/test_provisional_correspondence_catalog.gd'
        'tests/unit/test_system_tts_coordinator.gd'
        'tests/unit/test_witnessed_transport_rail.gd'
        'tests/unit/test_witnessed_speech_status.gd'
        'tests/unit/test_gallery_registrar.gd'
        'tests/unit/test_controls_binding_rules.gd'
        'tests/unit/test_backup_panel_resize.gd'
        'tests/unit/test_backup_presentation.gd'
        'tests/integration/test_desktop_crash_recovery.gd'
        'tests/scene/test_ending_recovery_localization.gd'
        'tests/unit/tooling/test_ui_literal_audit.gd'
    )
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$testPaths = @($suites[$Suite] | ForEach-Object {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $_))) {
        throw "Requested test does not exist: $_"
    }
    "res://$_"
})
$arguments = @(
    '-s', 'res://addons/gut/gut_cmdln.gd'
    '-gconfig='
    "-gtest=$($testPaths -join ',')"
    '-gexit'
    '-glog=2'
    "-gjunit_xml_file=res://.godot/ci/$Suite.xml"
)
$logName = "cloud-$Suite.log"
& (Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1') `
    -SuiteId "cloud-$Suite" `
    -LogName $logName `
    -EvidenceLogPath ".godot/ci/$Suite.jsonl" `
    -TimeoutSeconds 480 `
    -GodotArgs $arguments
$result = $LASTEXITCODE
$logPath = Join-Path $repositoryRoot ".godot/phase2r_logs/$logName"
if ($result -ne 0) {
    if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath }
    exit $result
}
$sourceTestScript = ''
$sourceTestName = ''
$expectedUnreadableDiagnostics = 0
foreach ($line in Get-Content -LiteralPath $logPath) {
    if ($line.StartsWith('res://tests/', [StringComparison]::Ordinal)) {
        $sourceTestScript = $line
        $sourceTestName = ''
    }
    if ($line.StartsWith('* test_', [StringComparison]::Ordinal)) { $sourceTestName = $line.Substring(2) }
    if ($line -notmatch '^(?:ERROR: )?(?:Unicode parsing error\b|Unexpected NUL character\b)') { continue }
    # This existing negative fixture deliberately loads exactly one 0xff byte.
    # Keep its corrupt-save consent coverage; no NUL diagnostic is expected.
    if ($Suite -eq 'new_account' -and $expectedUnreadableDiagnostics -eq 0 -and
        $sourceTestScript -ceq 'res://tests/integration/test_prepared_new_run.gd' -and
        $sourceTestName -ceq 'test_prepare_counts_nonempty_unreadable_autosave_but_not_zero_bytes' -and
        $line -ceq 'Unicode parsing error, some characters were replaced with � (U+FFFD): Invalid UTF-8 leading byte (ff)') {
        $expectedUnreadableDiagnostics += 1
        continue
    }
    throw "Unexpected Unicode/NUL diagnostic in $sourceTestScript / ${sourceTestName}: $line"
}
if ($Suite -eq 'new_account' -and $expectedUnreadableDiagnostics -ne 1) {
    throw 'The corrupt-save fixture did not produce its one expected 0xff diagnostic.'
}
if ($expectedUnreadableDiagnostics -eq 1) {
    Write-Host 'CORRUPT_SAVE_DIAGNOSTIC_VERIFIED: expected 0xff fixture diagnostic observed once.'
}

# A zero process status alone is insufficient (GUT can quit early with zero).
$report = Join-Path $output "$Suite.xml"
if (-not (Test-Path -LiteralPath $report)) { throw 'GUT did not produce its JUnit report.' }
[xml]$xml = Get-Content -LiteralPath $report -Raw
$executed = $xml.SelectNodes('//testcase').Count
if ($executed -eq 0) { throw 'GUT did not report any executed tests.' }
if ($xml.SelectNodes('//failure | //error').Count -ne 0) { throw 'GUT reported test failures.' }
Write-Host "${Suite}: $executed test cases completed across $($testPaths.Count) requested scripts."
# Keep actual per-script results observable when the JUnit artifact is unavailable.
$scriptResults = @($xml.SelectNodes('//testsuite') | ForEach-Object {
    $cases = $_.SelectNodes('./testcase').Count
    $skipped = $_.SelectNodes('./testcase[skipped]').Count
    [ordered]@{ script = $_.GetAttribute('name'); test_cases = $cases; passed = $cases - $skipped; skipped = $skipped }
})
$skippedCases = $xml.SelectNodes('//testcase[skipped]').Count
Write-Host ('CLOUD_GUT_RESULT ' + ([ordered]@{
    suite = $Suite; test_cases = $executed; passed = $executed - $skippedCases; skipped = $skippedCases
    requested_scripts = $testPaths.Count; reported_scripts = $scriptResults.Count; scripts = $scriptResults
} | ConvertTo-Json -Depth 4 -Compress))

if ($Suite -eq 'settings') {
    # Expected fixture refusals are reported separately from passing GUT cases.
    & (Join-Path $PSScriptRoot 'Invoke-StorageRefusalChecks.ps1')

    # The diagnostic uses the real revision protocol with deterministic FileOps
    # faults. Its standalone assertions are not counted as GUT test cases.
    $witnessLogName = 'cloud-manual-witness-revision-storage.log'
    & (Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1') `
        -SuiteId 'cloud-manual-witness-revision-storage' -LogName $witnessLogName `
        -EvidenceLogPath '.godot/ci/manual-witness-revision-storage.jsonl' -TimeoutSeconds 180 `
        -GodotArgs @('-s', 'res://tests/backup_storage/test_manual_witness_revision_storage.gd')
    $witnessResult = $LASTEXITCODE
    $witnessLog = Join-Path $repositoryRoot ".godot/phase2r_logs/$witnessLogName"
    if ($witnessResult -ne 0) {
        if (Test-Path -LiteralPath $witnessLog) { Get-Content -LiteralPath $witnessLog }
        exit $witnessResult
    }
    $markers = @(Get-Content -LiteralPath $witnessLog | Where-Object { $_ -ceq 'MANUAL_WITNESS_REVISION_STORAGE_PASS' })
    if ($markers.Count -ne 1 -or (Select-String -LiteralPath $witnessLog -Pattern 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character' -Quiet)) {
        throw 'Manual witness storage did not prove ordered fault/restart equivalence.'
    }
    Get-Content -LiteralPath $witnessLog
}

if ($Suite -eq 'persistence') {
    # This standalone capture/retention contract is a SceneTree script, not a GUT suite.
    $captureLogName = 'cloud-save-load-capture.log'
    & (Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1') `
        -SuiteId 'cloud-save-load-capture' -LogName $captureLogName `
        -EvidenceLogPath '.godot/ci/save-load-capture.jsonl' -TimeoutSeconds 180 `
        -GodotArgs @('-s', 'res://tests/save_load_capture/test_capture.gd')
    $captureResult = $LASTEXITCODE
    $captureLog = Join-Path $repositoryRoot ".godot/phase2r_logs/$captureLogName"
    if ($captureResult -ne 0) {
        if (Test-Path -LiteralPath $captureLog) { Get-Content -LiteralPath $captureLog }
        exit $captureResult
    }
    $markers = @(Get-Content -LiteralPath $captureLog | Where-Object { $_ -cmatch '^SAVE_LOAD_CAPTURE_PASS [0-9]+ checks; failures=0$' })
    if ($markers.Count -ne 1 -or (Select-String -LiteralPath $captureLog -Pattern 'SCRIPT ERROR:|ERROR: Failed to load' -Quiet)) {
        throw 'Standalone save capture did not prove its complete contract.'
    }
    Write-Host $markers[0]
}

if ($Suite -eq 'new_account') {
    # Measure the real title-button flow in a fresh isolated process. Correctness
    # gates this job; machine-dependent timings are evidence, not a fixed budget.
    $latencyLogName = 'cloud-new-account-latency.log'
    & (Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1') `
        -SuiteId 'cloud-new-account-latency' `
        -LogName $latencyLogName `
        -EvidenceLogPath '.godot/ci/new-account-latency.jsonl' `
        -GodotArgs @('-s', 'res://tests/integration/verify_new_acc_latency.gd', '--', '--phase2r-bootstrap-mode=final')
    $result = $LASTEXITCODE
    $latencyLog = Join-Path $repositoryRoot ".godot/phase2r_logs/$latencyLogName"
    if ($result -ne 0) {
        if (Test-Path -LiteralPath $latencyLog) { Get-Content -LiteralPath $latencyLog }
        exit $result
    }
    $prefix = 'NEW_ACC_LATENCY_VERIFIED '
    $markers = @(Get-Content -LiteralPath $latencyLog | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) })
    if ($markers.Count -ne 1) { throw 'New Account latency probe did not report verified results.' }
    if (Select-String -LiteralPath $latencyLog -Pattern 'SCRIPT ERROR:|ERROR: Failed to load' -Quiet) {
        throw 'New Account latency probe reported script errors.'
    }
    $timingJson = $markers[0].Substring($prefix.Length)
    $timing = $timingJson | ConvertFrom-Json
    if ($timing.ok -ne $true -or @($timing.samples).Count -ne 2 -or
        (@($timing.samples.case | Sort-Object) -join ',') -cne 'fresh,replacement') {
        throw 'New Account latency probe did not verify both account creation cases.'
    }
    foreach ($sample in $timing.samples) {
        if ($sample.button_to_desktop_us -le 0 -or $sample.max_frame_gap_us -lt 0) {
            throw 'New Account latency probe returned invalid measurements.'
        }
    }
    Set-Content -LiteralPath (Join-Path $output 'new-account-latency.json') -Value $timingJson -Encoding utf8
    Write-Host "$prefix$timingJson"
}
