param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('minesweeper', 'shop', 'desktop', 'settings', 'new_account', 'reading_delivery')]
    [string]$Suite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Deliberate, bounded UI and input regression coverage. Each path must actually
# execute; Invoke-IsolatedGodot also rejects GUT's silent suite-load failures.
$suites = @{
    minesweeper = @(
        'tests/unit/test_minesweeper_app.gd'
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
    )
    desktop = @(
        'tests/unit/test_desktop_panel_split.gd'
        'tests/desktop_shell/test_desktop_split_touch.gd'
        'tests/unit/test_desktop_touch_navigation.gd'
        'tests/unit/test_desktop_app_host_state.gd'
        'tests/unit/test_desktop_accessibility_contract.gd'
        'tests/integration/test_desktop_quick_commands.gd'
        'tests/integration/test_schedule_desktop_host.gd'
        'tests/scene/test_controls_input_contact_release.gd'
    )
    settings = @(
        'tests/unit/test_settings_panel_resize.gd'
        'tests/unit/test_settings_preference_registry.gd'
        'tests/unit/test_settings_window_transactions.gd'
        'tests/unit/test_window_mode_manager.gd'
        'tests/unit/test_window_mode_port.gd'
        'tests/unit/test_bootstrap_window_output.gd'
        'tests/scene/test_settings_window_mode_live.gd'
        'tests/scene/test_settings_reset_confirmation.gd'
        'tests/scene/test_settings_folio.gd'
        'tests/scene/test_settings_host_geometry.gd'
        'tests/scene/test_settings_localization_scene.gd'
        'tests/integration/test_settings_shared_hosts.gd'
    )
    new_account = @(
        'tests/unit/test_canonical_writer_compatibility.gd'
        'tests/unit/test_continuation_serialization_cache.gd'
        'tests/unit/test_new_acc_title_lifetime.gd'
        'tests/integration/test_prepared_new_run.gd'
        'tests/integration/test_new_run_transaction.gd'
        'tests/integration/test_new_run_pair_durability.gd'
        'tests/integration/test_new_run_startup_publication.gd'
        'tests/unit/test_new_run_durability_journal.gd'
    )
    reading_delivery = @(
        'tests/unit/test_minesweeper_delivery_notice.gd'
        'tests/integration/test_witnessed_caption_runtime.gd'
        'tests/unit/test_witnessed_pause_view.gd'
        'tests/unit/test_witnessed_auto_controller.gd'
        'tests/unit/test_witnessed_skip_controller.gd'
        'tests/scene/test_witnessed_transport_recovery.gd'
        'tests/integration/test_witnessed_speech_projection.gd'
        'tests/integration/test_dating_caption_style.gd'
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
    -GodotArgs $arguments
$result = $LASTEXITCODE
$logPath = Join-Path $repositoryRoot ".godot/phase2r_logs/$logName"
if ($result -ne 0) {
    if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath }
    exit $result
}

# A zero process status alone is insufficient (GUT can quit early with zero).
$report = Join-Path $output "$Suite.xml"
if (-not (Test-Path -LiteralPath $report)) { throw 'GUT did not produce its JUnit report.' }
[xml]$xml = Get-Content -LiteralPath $report -Raw
$executed = $xml.SelectNodes('//testcase').Count
if ($executed -eq 0) { throw 'GUT did not report any executed tests.' }
if ($xml.SelectNodes('//failure | //error').Count -ne 0) { throw 'GUT reported test failures.' }
Write-Host "${Suite}: $executed test cases completed across $($testPaths.Count) requested scripts."

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
