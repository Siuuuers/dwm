#!/usr/bin/env python3
"""Historical manuscript importer. Production DTL is authored directly."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'story/auditions/playable-week-20261023'
OUTCOMES = ('never_started', 'unfinished', 'won', 'lost', 'perfect')


class Week:
    def __init__(self):
        self.entries = []
        self.sources = {day: (SOURCE / f'day-{day}.md').read_text().splitlines()
                        for day in range(1, 8)}

    def read(self, day, start, end):
        result = []
        for number in range(start, end + 1):
            raw = self.sources[day][number - 1].strip()
            if not raw or raw.startswith('#'):
                continue
            if any(raw.startswith(prefix) for prefix in (
                '**[Author', '**Author boundary', '*Control:', '*(Read ',
                '*(Follow ', '*The visible scene cuts', '**Self-talk — Aftermath',
                '- *No input', '- *Option', '> **Unmarked perceptual shard')):
                continue
            raw = raw.removeprefix('> ').strip()
            # Structural self-talk labels are author annotations, not dialogue.
            raw = re.sub(r'^\*\*(?:Optional thought(?: \(Route Fork\))?|Self-talk(?: — [^:*]+)?|Private self-talk(?: — [^:*]+)?):\*\*\s*', '', raw)
            if re.fullmatch(r'\*\*(?:Private self-talk|Self-talk)[^*]*\*\*', raw):
                continue
            raw = re.sub(r'\*\*([^*]+)\*\*', r'\1', raw)
            raw = re.sub(r'(?<!\*)\*([^*]+)\*(?!\*)', r'\1', raw)
            raw = re.sub(r'~~([^~]+)~~', lambda m: ''.join(c + '\u0336' for c in m[1]), raw)
            raw = raw.replace('`', '')
            if raw:
                result.append({'text': raw, 'source_line': number, 'source_day': day})
        return result

    @staticmethod
    def join(*groups):
        return [block for group in groups for block in group]

    def scene(self, id, day, blocks, terminal, role='scene'):
        assert re.fullmatch(r'[A-Za-z0-9_.]+', id), id
        assert blocks, id
        assert all(entry['id'] != id for entry in self.entries), id
        self.entries.append({'id': id, 'day': day, 'lines': blocks,
                             'terminal': terminal, 'role': role})

    def write(self):
        raise SystemExit(
            'This historical ordinal-ID importer is retired. Edit DTL directly, '
            'retain existing #id values, declare entries and routing with # story, '
            'then run tools/authoring/ExportSevenDayRegistration.gd in the cloud.')


if __name__ == '__main__':
    import story_days_1_3
    import story_days_4_7
    week = Week()
    story_days_1_3.build(week)
    story_days_4_7.build(week)
    week.write()
