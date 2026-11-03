import unittest

from check_witnesses import EVENTS, FIELDS, check, read_states


class WitnessFormatTests(unittest.TestCase):
    def setUp(self):
        self.row = {field: '"value"' for field in FIELDS}
        self.block = "State 1:\n" + "\n".join(
            f"/\\ {field} = {value}" for field, value in sorted(self.row.items()))

    def test_reads_all_states_including_final_without_blank_line(self):
        text = self.block + "\n\n" + self.block.replace("State 1:", "State 2:")
        self.assertEqual(list(read_states(text)), [self.row, self.row])

    def test_missing_or_duplicate_field_is_rejected(self):
        for text in (self.block.rsplit("\n", 1)[0], self.block + '\n/\\ phase = "IDLE"'):
            with self.assertRaises(ValueError):
                list(read_states(text))

    def test_requires_all_events_and_completed_released_state(self):
        def dump(events, visible="3"):
            state = dict(self.row, visible=visible, applied="<<1, 1>>", phase='"IDLE"',
                         owner="{}", pc='"idle"', expected="0")
            return "\n\n".join(
                f"State {index}:\n" + "\n".join(f"/\\ {key} = {value}" for key, value
                    in dict(state, last_event=f'"{event}"').items())
                for index, event in enumerate(events, 1))

        events = sorted(EVENTS)
        self.assertEqual(check(dump(events))["behavior_witnesses"], 14)
        self.assertTrue(check(dump(events))["completed_and_released"])
        for text in (dump(events[:-1]), dump(events, visible="2")):
            with self.assertRaisesRegex(ValueError, "Witness check failed"):
                check(text)

    def test_empty_dump_cannot_pass_reachability(self):
        with self.assertRaisesRegex(ValueError, "Witness check failed"):
            check("")


if __name__ == "__main__":
    unittest.main()
