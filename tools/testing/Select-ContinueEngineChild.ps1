# Pure selection shared by the reader and its Windows PowerShell 5 preflight.
# Selection does not replace live argv/start-time/HWND validation in the reader.
function Select-ContinueEngineChild([object[]]$Children, [int]$LauncherId, [string]$EngineExecutable) {
    $matches = New-Object Collections.Generic.List[object]
    $inventory = New-Object Collections.Generic.List[object]
    $errorCode = $null
    foreach ($child in $Children) {
        $path = [string]$child.ExecutablePath
        $reason = 'other_executable'
        if ([int]$child.ProcessId -le 0 -or [int]$child.ParentProcessId -ne $LauncherId) {
            $reason = 'invalid_parent_or_pid'
            $errorCode = 'UIA_CHILD_IDENTITY_INVALID'
        } elseif ([string]::IsNullOrWhiteSpace($path)) {
            $reason = 'executable_unavailable'
            $errorCode = 'UIA_CHILD_IDENTITY_UNAVAILABLE'
        } elseif ($path -ieq $EngineExecutable) {
            $reason = 'engine_executable'
            $matches.Add($child)
        }
        if ($inventory.Count -lt 16) {
            $inventory.Add([ordered]@{ pid = [int]$child.ProcessId;
                parent_pid = [int]$child.ParentProcessId; executable = $path; disposition = $reason })
        }
    }
    if ($matches.Count -gt 1) { $errorCode = 'UIA_AMBIGUOUS_ENGINE_CHILD' }
    $selected = $null
    if ($null -eq $errorCode -and $matches.Count -eq 1) { $selected = $matches[0] }
    return [pscustomobject]@{ candidate = $selected; error = $errorCode;
        receipt = [ordered]@{ child_count = $Children.Count; engine_candidate_count = $matches.Count;
            selected_pid = $(if ($null -ne $selected) { [int]$selected.ProcessId } else { $null });
            inventory_truncated = $Children.Count -gt 16; children = @($inventory.ToArray()) } }
}
