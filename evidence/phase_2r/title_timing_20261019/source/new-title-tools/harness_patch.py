"""Fail-closed, diagnostic-only transformation of the exported gameplay harness.

Clock samples are adjacent observations, not synchronized clocks across processes.
Wait deadlines refer to the original Wait-One stopwatch; Record I/O is included in
that existing budget. No timeout, predicate, UIA lookup or invocation is replaced.
"""


def patch(source: str) -> str:
    """Return instrumented source; reject missing/duplicate anchors or repeat use."""
    newline = "\r\n" if "\r\n" in source else "\n"
    normalized = source.replace("\r\n", "\n")
    if "ending-title-timing-v1" in normalized:
        raise ValueError("harness already contains ending-title-timing-v1")
    replacements = [
        (
            "    foreach ($name in @($start.Environment.Keys | Where-Object { $_ -like 'DWM_*' })) { [void]$start.Environment.Remove($name) }\n",
            """    foreach ($name in @($start.Environment.Keys | Where-Object { $_ -like 'DWM_*' })) { [void]$start.Environment.Remove($name) }
    if ($TraceEndingActions -and $Mode -eq 'Load') {
        $titleTimingPath = [Environment]::GetEnvironmentVariable('DWM_TITLE_TIMING_PATH')
        if (-not [string]::IsNullOrWhiteSpace($titleTimingPath)) {
            $start.Environment['DWM_TITLE_TIMING_PATH'] = $titleTimingPath
        }
    }
""",
        ),
        (
            "function Check-Live {\n",
            """# ending-title-timing-v1: cached identity only; no provider/native observation.
$script:endingTitleWaitTrace = $false
function Record-EndingTiming([string]$Kind, $WaitWatch = $null) {
    $tick = [Diagnostics.Stopwatch]::GetTimestamp()
    $utc = [DateTime]::UtcNow
    $sample = [ordered]@{
        schema=1; source='ending-title-timing-v1'; observed_utc=$utc.ToString('o');
        monotonic_ticks=$tick; monotonic_frequency=[Diagnostics.Stopwatch]::Frequency;
        pid=$result.process.pid; hwnd=$null; hwnd_source='unavailable';
        journey_deadline_seconds=$JourneyTimeoutSeconds
    }
    if ($result.Contains('native_baseline_handle')) {
        $sample.hwnd = $result.native_baseline_handle
        $sample.hwnd_source = 'cached-native-baseline'
    }
    if ($null -ne $WaitWatch) {
        $sample.wait_elapsed_ticks = $WaitWatch.ElapsedTicks
        $sample.wait_deadline_seconds = $StepTimeoutSeconds
        $sample.wait_deadline_ticks_from_origin = [long]($StepTimeoutSeconds * [Diagnostics.Stopwatch]::Frequency)
        # Adjacent reads are not atomic: retain raw samples; do not claim an exact UTC deadline.
        $sample.clock_sample_note = 'monotonic then UTC then wait elapsed; adjacent non-atomic samples'
    }
    Record $Kind $sample
}
function Check-Live {
""",
        ),
        (
            "function Wait-One([string]$Name, [scriptblock]$Find) {\n    $watch = [Diagnostics.Stopwatch]::StartNew()\n",
            """function Wait-One([string]$Name, [scriptblock]$Find) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $endingTitleTrace = $TraceEndingActions -and $script:endingTitleWaitTrace -and $Mode -eq 'Load' -and $Name -ceq 'New Acc'
    if ($endingTitleTrace) { Record-EndingTiming 'ending-title-wait-start' $watch }
""",
        ),
        (
            "    } finally {\n        if ($nativeGate) {\n",
            """    } finally {
        if ($endingTitleTrace) { Record-EndingTiming 'ending-title-wait-end' $watch }
        if ($nativeGate) {
""",
        ),
        (
            "    ([Windows.Automation.InvokePattern]$pattern).Invoke()\n    if ($timedWitness) {\n",
            """    ([Windows.Automation.InvokePattern]$pattern).Invoke()
    if ($TraceEndingActions -and $Mode -eq 'Load' -and $Purpose -ceq 'finish ending') {
        Record-EndingTiming 'finish-ending-invoke-return'
    }
    if ($timedWitness) {
""",
        ),
        (
            "        Invoke-UI (Caption 'TEST Seven-day ending.') 'finish ending'\n        $null = Button 'New Acc'\n        Capture 'ending-return-title'\n",
            """        Invoke-UI (Caption 'TEST Seven-day ending.') 'finish ending'
        $script:endingTitleWaitTrace = [bool]$TraceEndingActions
        try { $null = Button 'New Acc' }
        finally { $script:endingTitleWaitTrace = $false }
        Capture 'ending-return-title'
""",
        ),
    ]
    for old, _ in replacements:
        if normalized.count(old) != 1:
            raise ValueError(f"expected exactly one harness anchor: {old[:100]!r}")
    for old, new in replacements:
        normalized = normalized.replace(old, new, 1)
    return normalized.replace("\n", newline)
