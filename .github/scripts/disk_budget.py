#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
import time

INTERVAL = 0.5


def probe(paths):
    result = {}
    devices = {}
    for path in paths:
        device = os.stat(path).st_dev
        if device not in devices:
            fs = os.statvfs(path)
            devices[device] = (fs.f_bavail * fs.f_frsize, fs.f_favail)
        free_bytes, free_inodes = devices[device]
        result[path] = dict(device=device, free_bytes=free_bytes, free_inodes=free_inodes)
    return result


def may_skip(paths, min_bytes, min_inodes):
    if min_bytes <= 0 or min_inodes <= 0:
        return False
    try:
        usage = probe(paths)
    except OSError as error:
        print(f'disk probe failed, using fallback: {error}', file=sys.stderr)
        return False
    return len({fs['device'] for fs in usage.values()}) == 1 and all(
        fs['free_bytes'] >= min_bytes and fs['free_inodes'] >= min_inodes
        for fs in usage.values()
    )


def log(label, **data):
    print(f'disk_budget {label} {json.dumps(data, sort_keys=True)}', flush=True)


def watch(paths, command):
    started = last = time.monotonic()
    cpu_started = time.process_time()
    initial = final = probe(paths)
    low = {path: dict(fs) for path, fs in initial.items()}
    samples, max_gap = 1, 0
    error = None
    log('start', paths=initial, interval_seconds=INTERVAL)
    with subprocess.Popen(command) as child:
        while True:
            try:
                status = child.wait(timeout=INTERVAL)
            except subprocess.TimeoutExpired:
                status = None
            now = time.monotonic()
            try:
                final = probe(paths)
                for path, fs in final.items():
                    if fs['device'] != initial[path]['device']:
                        raise OSError(f'filesystem changed during measurement: {path}')
                    for unit in ('free_bytes', 'free_inodes'):
                        low[path][unit] = min(low[path][unit], fs[unit])
            except OSError as failure:
                error = str(failure)
            samples += 1
            max_gap = max(max_gap, now - last)
            last = now
            if status is not None:
                break
    log('end', minima=low, final=final, samples=samples, max_gap_seconds=round(max_gap, 3),
        elapsed_seconds=round(last - started, 3), sampler_cpu_seconds=round(time.process_time() - cpu_started, 3),
        error=error, child_status=status)
    if status < 0:
        return 128 - status
    return status or (1 if error else 0)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--path', action='append')
    modes = parser.add_subparsers(dest='mode', required=True)
    snapshot = modes.add_parser('snapshot')
    snapshot.add_argument('label')
    choose = modes.add_parser('choose')
    choose.add_argument('--min-bytes', type=int, default=0)
    choose.add_argument('--min-inodes', type=int, default=0)
    monitor = modes.add_parser('watch')
    monitor.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    paths = args.path or list(dict.fromkeys([
        '/', '/nix/store', os.getcwd(), '/tmp', os.path.expanduser('~'),
        *(os.environ[name] for name in ('RUNNER_TEMP', 'TMPDIR', 'XDG_STATE_HOME')
          if os.environ.get(name)),
    ]))
    if args.mode == 'snapshot':
        log(args.label, paths=probe(paths))
        return 0
    if args.mode == 'choose':
        print('skip' if may_skip(paths, args.min_bytes, args.min_inodes) else 'clean')
        return 0
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('watch requires a command')
    return watch(paths, command)


if __name__ == '__main__':
    raise SystemExit(main())
