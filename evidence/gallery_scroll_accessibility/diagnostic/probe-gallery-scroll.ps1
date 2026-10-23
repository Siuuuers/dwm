param([string]$LogPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$ready = ((Get-Content -LiteralPath $LogPath -Encoding UTF8 | Where-Object { $_.StartsWith('READY ') } | Select-Object -Last 1).Substring(6) | ConvertFrom-Json)
$native = [Diagnostics.Process]::GetProcessById($ready.pid)
if ($native.MainWindowTitle -cne $ready.title) { throw 'Wrong native window' }
$window = [Windows.Automation.AutomationElement]::FromHandle($native.MainWindowHandle)
if ($window.Current.ProcessId -ne $ready.pid) { throw 'Wrong UIA process' }
$rootFull = [IO.Path]::GetFullPath($ready.folder)
$allowed = [IO.Path]::GetFullPath((Join-Path (Get-Location) '.godot/phase2r_tests'))
if (-not $rootFull.StartsWith($allowed+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected test root' }
$commandPath = Join-Path $rootFull 'scroll-command.json'
function Set-Phase([string]$Phase) {
 $temporary = $commandPath + '.tmp'
 [IO.File]::WriteAllText($temporary, (@{phase=$Phase} | ConvertTo-Json -Compress))
 if (Test-Path -LiteralPath $commandPath) { [IO.File]::Replace($temporary,$commandPath,[NullString]::Value) }
 else { [IO.File]::Move($temporary,$commandPath) }
 if ($Phase -eq 'done') { return }
 $deadline=[DateTime]::UtcNow.AddSeconds(5)
 do {
  $markers=@(Get-Content -LiteralPath $LogPath -Encoding UTF8 | Where-Object { $_.StartsWith('PHASE ') } | ForEach-Object { $_.Substring(6) | ConvertFrom-Json } | Where-Object phase -EQ $Phase)
  if ($markers.Count -eq 1) { return $markers[0] }
  Start-Sleep -Milliseconds 50
 } while ([DateTime]::UtcNow -lt $deadline)
 throw "Phase timeout: $Phase"
}
function Snapshot {
 $elements=$window.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Automation]::ControlViewCondition)
 @($elements | ForEach-Object {
  $pattern=$null
  $hasScroll=$_.TryGetCurrentPattern([Windows.Automation.ScrollPattern]::Pattern,[ref]$pattern)
  [ordered]@{name=$_.Current.Name.TrimEnd();type=$_.Current.ControlType.ProgrammaticName;
   patterns=@($_.GetSupportedPatterns() | ForEach-Object ProgrammaticName);
   scrollable=if($hasScroll){$pattern.Current.VerticallyScrollable}else{$null};
   percent=if($hasScroll){$pattern.Current.VerticalScrollPercent}else{$null};
   view=if($hasScroll){$pattern.Current.VerticalViewSize}else{$null};focused=$_.Current.HasKeyboardFocus}
 })
}
$result=[ordered]@{before=@(Snapshot);ready=$ready;ok=$false}
try {
 $elements=$window.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Automation]::ControlViewCondition)
 $targets=@($elements | Where-Object { $_.Current.Name.TrimEnd() -ceq 'Record details' })
 if ($targets.Count -ne 1) { throw "Record details target count: $($targets.Count)" }
 $scroll=$null
 $result.scroll_pattern_supported=$targets[0].TryGetCurrentPattern([Windows.Automation.ScrollPattern]::Pattern,[ref]$scroll)
 if ($result.scroll_pattern_supported) { $scroll.SetScrollPercent(-1,100) }
 Start-Sleep -Milliseconds 250
 $result.after=@(Snapshot)
 $result.offset=Set-Phase 'offset'
 $result.fit_state=Set-Phase 'fit'
 $result.fit=@(Snapshot)
 $result.title_only_state=Set-Phase 'title_only'
 $result.title_only=@(Snapshot)
 if (@($result.fit | Where-Object name -CEQ 'Record details').Count -ne 0) { throw 'Fitting paper retains named scroll target' }
 if (@($result.fit | Where-Object name -CEQ 'One visible sentence.').Count -ne 1) { throw 'Sentence is absent from fitting semantic tree' }
 $result.fit_semantics_ok=$true
 if (-not $result.scroll_pattern_supported) { throw 'Windows UIA does not expose ScrollPattern for Record details' }
 if ($result.offset.offset -ne $ready.max_offset) { throw 'SetScrollPercent did not reach actual paper bottom' }
 $result.ok=$true
} catch { $result.failure=$_.Exception.Message }
finally {
 Set-Phase 'done'
 $json=$result | ConvertTo-Json -Depth 12
 [IO.File]::WriteAllText([IO.Path]::ChangeExtension($LogPath,'.uia.json'),$json,[Text.UTF8Encoding]::new($false))
 $json
}
if (-not $result.ok) { exit 1 }
