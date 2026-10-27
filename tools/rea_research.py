#!/usr/bin/env python3
"""Retain read-only REA evidence for a caller-supplied desktop installation."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('target', type=Path, help='Installation directory or a selected native executable')
    parser.add_argument('--output', type=Path, required=True, help='A new private evidence directory, outside the game source tree')
    parser.add_argument('--rea', type=Path, help='REA executable, or its scripts/rea.mjs entry point')
    parser.add_argument('--node', type=Path, help='Supported Node binary when using rea.mjs')
    parser.add_argument('--native', action='store_true', help='Also request Ghidra analysis after provider readiness succeeds')
    args = parser.parse_args()
    target = args.target.expanduser().resolve(strict=True)
    output = args.output.expanduser().resolve()
    source = Path(__file__).resolve().parents[1]
    if output == source or source in output.parents:
        parser.error('Keep original-game evidence outside the source repository; select a private --output directory.')
    if output.exists() and any(output.iterdir()):
        parser.error('Use an empty evidence directory; existing reports are never overwritten.')
    entry = str(args.rea.resolve(strict=True)) if args.rea else shutil.which('rea')
    if not entry:
        parser.error('Install REA, or supply --rea and a supported --node. See docs/REA_RESEARCH_V17.md.')
    command = ([str(args.node.resolve(strict=True)), entry] if args.node else [entry])
    if Path(entry).suffix == '.mjs' and not args.node:
        parser.error('A .mjs entry point requires an explicit supported --node binary.')
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    for kind in ['CONFIG', 'CACHE', 'DATA']:
        profile = output / 'profile' / kind.lower()
        profile.mkdir(parents=True, exist_ok=True)
        env[f'XDG_{kind}_HOME'] = str(profile)
    manifest = {'created_at': datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),
                'target': str(target), 'target_executed': False, 'commands': [],
                'target_sha256': hashlib.sha256(target.read_bytes()).hexdigest() if target.is_file() else None,
                'native_requested': args.native, 'original_game_mechanics_verified': False}

    def run(name, arguments, timeout=120):
        result = subprocess.run(command + arguments, env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True, encoding="utf-8", timeout=timeout)
        (output / (name + '.json')).write_text(result.stdout, encoding='utf-8')
        (output / (name + '.stderr.log')).write_text(result.stderr, encoding='utf-8')
        manifest['commands'].append({'name': name, 'arguments': arguments,
                                     'exit_code': result.returncode,
                                     'report_sha256': hashlib.sha256(result.stdout.encode()).hexdigest()})
        (output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        return result

    version = run('version', ['--version'])
    if version.returncode:
        raise RuntimeError('REA did not start; inspect version.stderr.log.')
    inventory = run('installation', ['inspect-desktop-application', str(target.parent if target.is_file() else target),
                                     '--detail', 'complete', '--json'])
    if inventory.returncode:
        raise RuntimeError('Installation inspection failed; retained diagnostics are in the output directory.')
    if target.is_file() and target.suffix.lower() in ['.exe', '.dll']:
        imports = run('pe-imports', ['inspect-pe-imports', str(target), '--max-file-bytes', str(max(64*1024*1024,target.stat().st_size)), '--json'])
        if imports.returncode:
            raise RuntimeError('PE import inspection failed; see retained diagnostics.')
    if args.native:
        doctor = run('ghidra-readiness', ['doctor', '--provider', 'ghidra', '--json'])
        ready = json.loads(doctor.stdout).get('healthy', False) if doctor.stdout.strip().startswith('{') else False
        if doctor.returncode or not ready:
            print('Static evidence retained. Ghidra is not ready; no native analysis was claimed.', file=sys.stderr)
            return 2
        if not target.is_file():
            parser.error('--native requires a selected executable, not a directory.')
        native = run('native-overview', ['analyze', str(target), '--provider', 'ghidra', '--json'], timeout=900)
        if native.returncode:
            raise RuntimeError('Native analysis did not complete; see retained diagnostics.')
    print('REA evidence retained:', output)
    print('Mechanics conclusions still require examining the evidence and observing the game.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
