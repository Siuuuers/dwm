import unittest
from check_history import violations


class HistoryDependencies(unittest.TestCase):
    def test_pure_projection(self):
        self.assertEqual(violations('func project_scene_day_history():\n\treturn project_blocks()\n', 'extends RefCounted'), [])

    def test_rejects_capture_and_profile_coupling(self):
        for call in ['snapshot', '_capture_scene', 'restore', 'publish_caption', 'append_player_caption']:
            with self.subTest(call=call):
                self.assertTrue(violations('func project_scene_day_history():\n\t' + call + '()\n', ''))
        self.assertTrue(violations('func project_scene_day_history():\n\treturn {}\n', 'preload("res://autoload/ProfileManager.gd")'))

    def test_other_session_operations_are_not_history(self):
        self.assertEqual(violations('func project_scene_day_history():\n\treturn {}\nfunc save():\n\tsnapshot()\n', ''), [])
