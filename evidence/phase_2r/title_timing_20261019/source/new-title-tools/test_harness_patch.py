"""Static transformation tests; these do not qualify PowerShell or native execution."""
from pathlib import Path
import unittest

from harness_patch import patch

SOURCE = Path(__file__).resolve().parents[1] / 'tools/testing/Invoke-ExportedGameplay.ps1'


class HarnessPatchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = SOURCE.read_text()
        cls.patched = patch(cls.original)

    def test_invocation_return_is_before_sleep_and_after_invoke(self):
        invoke = self.patched.index('    ([Windows.Automation.InvokePattern]$pattern).Invoke()')
        marker = self.patched.index("Record-EndingTiming 'finish-ending-invoke-return'", invoke)
        sleep = self.patched.index('    Start-Sleep -Milliseconds 200', invoke)
        self.assertLess(invoke, marker)
        self.assertLess(marker, sleep)
        self.assertIn("$Purpose -ceq 'finish ending'", self.patched[invoke:marker])

    def test_initial_title_does_not_arm_trace(self):
        self.assertEqual(self.patched.count('$script:endingTitleWaitTrace = [bool]$TraceEndingActions'), 1)
        scope = self.patched.split("'finish ending'\n", 1)[1].split("Capture 'ending-return-title'", 1)[0]
        self.assertIn("try { $null = Button 'New Acc' }", scope)
        self.assertIn('finally { $script:endingTitleWaitTrace = $false }', scope)
        self.assertIn("$Name -ceq 'New Acc'", self.patched)

    def test_wait_body_and_native_gate_unchanged(self):
        start = '    $trace = $TraceDay5'
        end = '    } finally {\n'
        self.assertEqual(self.original.split(start, 1)[1].split(end, 1)[0],
                         self.patched.split(start, 1)[1].split(end, 1)[0])
        for line in self.original.splitlines():
            if 'StepTimeoutSeconds' in line or 'JourneyTimeoutSeconds' in line:
                self.assertIn(line, self.patched)

    def test_helper_uses_only_cached_identity_and_clock(self):
        helper = self.patched.split('function Record-EndingTiming', 1)[1].split('function Check-Live', 1)[0]
        for forbidden in ('$Element', '$window', '$child', 'Observe-Native', 'GetForegroundWindow', '.Current', '.Refresh', 'GetWindowThreadProcessId'):
            self.assertNotIn(forbidden, helper)
        self.assertIn('pid=$result.process.pid', helper)
        self.assertIn("$result.native_baseline_handle", helper)
        self.assertIn('monotonic_frequency=', helper)
        self.assertIn('wait_deadline_ticks_from_origin', helper)
        self.assertIn('adjacent non-atomic samples', helper)

    def test_repeated_patch_rejected(self):
        with self.assertRaises(ValueError):
            patch(self.patched)

    def test_only_opted_in_load_forwards_explicit_timing_path_after_clear(self):
        clear = "    foreach ($name in @($start.Environment.Keys | Where-Object { $_ -like 'DWM_*' })) { [void]$start.Environment.Remove($name) }\n"
        forward = self.patched.split(clear, 1)[1].split('    if ($ProfileSaveLoad)', 1)[0]
        self.assertIn("if ($TraceEndingActions -and $Mode -eq 'Load')", forward)
        self.assertIn("[Environment]::GetEnvironmentVariable('DWM_TITLE_TIMING_PATH')", forward)
        self.assertIn('if (-not [string]::IsNullOrWhiteSpace($titleTimingPath))', forward)
        self.assertEqual(forward.count('$start.Environment['), 1)
        self.assertIn("$start.Environment['DWM_TITLE_TIMING_PATH'] = $titleTimingPath", forward)

    def test_environment_clear_anchor_change_rejected(self):
        with self.assertRaises(ValueError):
            patch(self.original.replace("$_ -like 'DWM_*'", "$_ -like 'OTHER_*'"))

    def test_missing_anchor_rejected(self):
        with self.assertRaises(ValueError):
            patch(self.original.replace("'finish ending'", "'changed ending'"))

    def test_duplicated_anchor_rejected(self):
        with self.assertRaises(ValueError):
            patch(self.original + '\nfunction Check-Live {\n')

    def test_crlf_preserved(self):
        patched = patch(self.original.replace('\n', '\r\n'))
        self.assertIn('\r\n', patched)
        self.assertNotIn('\n', patched.replace('\r\n', ''))


if __name__ == '__main__':
    unittest.main()
