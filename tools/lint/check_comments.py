import argparse
import difflib
import io
from pathlib import PurePosixPath
import re
import subprocess
import tokenize


def comment_lines(source, suffix):
    if suffix == '.py':
        return {token.start[0]: token.string for token in
                tokenize.generate_tokens(io.StringIO(source).readline)
                if token.type == tokenize.COMMENT}
    comments = {}
    quote = ''
    index = 0
    line = 1
    while index < len(source):
        char = source[index]
        if quote:
            if char == '\\':
                line += source[index:index + 2].count('\n')
                index += 2
                continue
            if source.startswith(quote, index):
                index += len(quote)
                quote = ''
                continue
        elif char in ('"', "'"):
            quote = char * 3 if source.startswith(char * 3, index) else char
            index += len(quote)
            continue
        elif char == '#':
            end = source.find('\n', index)
            if end == -1:
                end = len(source)
            comments[line] = source[index:end]
            index = end
            continue
        line += char == '\n'
        index += 1
    return comments


def exempt(comment, suffix, line):
    if suffix == '.py' and line <= 2 and re.match(r'^#(?:[ \t]*-\*-)?[ \t]*coding[:=][ \t]*[-\w.]+', comment):
        return True
    return bool(re.match(
        r'^#(?:!|\s*(?:SPDX-(?:License-Identifier|FileCopyrightText):|Copyright\b|'
        r'(?:noqa\b|type:|fmt:|ruff:|gdformat:|gdlint:)))', comment))


def violations(before, after, suffix):
    old_comments = comment_lines(before, suffix)
    retained = set()
    matcher = difflib.SequenceMatcher(None, before.splitlines(), after.splitlines(), autojunk=False)
    for old, new, size in matcher.get_matching_blocks():
        retained.update(new + offset + 1 for offset in range(size)
                        if old + offset + 1 in old_comments)
    return [line for line, comment in comment_lines(after, suffix).items()
            if line not in retained and not exempt(comment, suffix, line)]


def owned(path):
    parts = PurePosixPath(path).parts
    return (parts[0] in {'scripts', 'autoload', 'tests', 'tools'}
            and PurePosixPath(path).suffix in {'.gd', '.py'}
            and not {'vendor', 'third_party', 'generated'}.intersection(parts))


def comment_owned(path):
    parts = PurePosixPath(path).parts
    return owned(path) and parts[0] in {'scripts', 'autoload'} and PurePosixPath(path).suffix == '.gd'


def git(*args):
    return subprocess.check_output(['git', *args]).decode('utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', required=True)
    parser.add_argument('--head', default='HEAD')
    args = parser.parse_args()
    base = git('rev-parse', '--verify', args.base + '^{commit}').strip()
    head = git('rev-parse', '--verify', args.head + '^{commit}').strip()
    changes = iter(git('diff', '--name-status', '--find-renames', '--diff-filter=AMR', '-z', base, head).split('\0')[:-1])
    failures = 0
    for status in changes:
        old_path = path = next(changes)
        if status.startswith('R'):
            path = next(changes)
        if not comment_owned(path):
            continue
        before = git('show', base + ':' + old_path) if status != 'A' else ''
        after = git('show', head + ':' + path)
        for line in violations(before, after, PurePosixPath(path).suffix):
            print(f'{path}:{line}: explanatory comments are banned; use clear names or external design documentation')
            failures += 1
    print(f'Comment lint: {failures} violation(s)')
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
