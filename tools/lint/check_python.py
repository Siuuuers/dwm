import argparse
from pathlib import PurePosixPath

from check_comments import git, owned


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', required=True)
    parser.add_argument('--head', default='HEAD')
    args = parser.parse_args()
    base = git('rev-parse', '--verify', args.base + '^{commit}').strip()
    head = git('rev-parse', '--verify', args.head + '^{commit}').strip()
    paths = git('diff', '--name-only', '--find-renames', '--diff-filter=AMR', '-z', base, head).split('\0')[:-1]
    failures = 0
    checked = 0
    for path in paths:
        if not owned(path) or PurePosixPath(path).suffix != '.py':
            continue
        checked += 1
        try:
            compile(git('show', head + ':' + path), path, 'exec', dont_inherit=True)
        except SyntaxError as error:
            print(f'{path}:{error.lineno}:{error.offset}: {error.msg}')
            failures += 1
    print(f'Python syntax: {checked} file(s), {failures} error(s)')
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
