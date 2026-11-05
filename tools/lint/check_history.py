import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SESSION = 'scripts/narrative/SoloReadingSession.gd'
HISTORY = 'scripts/narrative/SceneReadingHistory.gd'
FORBIDDEN = re.compile(r'\b(?:snapshot|_capture_scene|capture_reading_checkpoint|restore|publish_caption|publish_line|append_player_caption|mark_caption_variant_witnessed)\s*\(')


def function_body(source, name):
    match = re.search(r'^(?:static )?func ' + re.escape(name) + r'\(.*?(?=^func |^static func |\Z)', source, re.M | re.S)
    return match.group() if match else ''


def violations(session, history):
    errors = []
    body = function_body(session, 'project_scene_day_history')
    if not body:
        errors.append('Missing local History projection owner')
    if FORBIDDEN.search(body):
        errors.append('History projection must not capture, restore, publish, or record progress')
    if FORBIDDEN.search(history) or 'res://autoload/' in history:
        errors.append('History catalogue projection must not depend on gameplay or Profile owners')
    return errors


def source(path):
    local = ROOT / path
    if local.is_file():
        return local.read_text()
    return subprocess.check_output(['git', 'show', 'HEAD:' + path], cwd=ROOT, text=True)


if __name__ == '__main__':
    errors = violations(source(SESSION), source(HISTORY))
    for error in errors:
        print(error)
    raise SystemExit(bool(errors))
