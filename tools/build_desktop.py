#!/usr/bin/env python3
"""Export desktop releases from a clean copy and record exact runtime inputs."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', default='godot')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--logs', type=Path, required=True)
    parser.add_argument('--acceptance', action='store_true', help='Also export separate opt-in QA applications')
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    project = Path(tempfile.mkdtemp(prefix='live_forever_release.')) / 'live_forever'
    shutil.copytree(source, project, ignore=shutil.ignore_patterns('.git', '.godot', 'builds', '__pycache__'))
    logs, output = args.logs.resolve(), args.output.resolve()
    logs.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)

    def run(name, command):
        process = subprocess.run([args.engine, '--headless', '--path', str(project), *command],
                                 env=os.environ.copy(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 text=True, timeout=180)
        (logs / (name + '.log')).write_text(process.stdout)
        if process.returncode or 'ERROR:' in process.stdout:
            raise RuntimeError(name + '\n' + process.stdout[-6000:])
        print('PASS ' + name, flush=True)

    run('import', ['--editor', '--import', '--quit'])
    binaries = {}
    for platform, preset, filename in [('windows', 'Windows Desktop', 'LiveForever.exe'),
                                       ('linux', 'Linux Desktop', 'LiveForever.x86_64')]:
        destination = output / platform / filename
        destination.parent.mkdir(parents=True, exist_ok=True)
        run('export-' + platform, ['--export-release', preset, str(destination)])
        with destination.open('rb') as file:
            header = file.read(128)
            file.seek(-4, 2)
            assert file.read() == b'GDPC', 'Missing embedded game data'
        if platform == 'windows':
            assert header[:2] == b'MZ'
            offset = struct.unpack_from('<I', header, 60)[0]
            with destination.open('rb') as file:
                file.seek(offset)
                pe = file.read(6)
            assert pe[:4] == b'PE\x00\x00' and struct.unpack('<H', pe[4:])[0] == 0x8664
        else:
            assert header[:5] == b'\x7fELF\x02' and struct.unpack_from('<H', header, 18)[0] == 62
            destination.chmod(0o755)
        binaries[platform] = {'path': str(destination), 'bytes': destination.stat().st_size,
                              'sha256': hashlib.sha256(destination.read_bytes()).hexdigest()}
    runtime = [*project.glob('scripts/*.gd'), *project.glob('scenes/*.tscn'),
               project / 'project.godot', project / 'assets/fonts/interface.otf',
               project / 'assets/icon.svg', project / 'export_presets.cfg',
               *[p for p in (project / 'assets/art').glob('*') if p.is_file()]]
    hashes = {str(file.relative_to(project)): hashlib.sha256(file.read_bytes()).hexdigest() for file in runtime}
    acceptance = {}
    if args.acceptance:
        presets = project / 'export_presets.cfg'
        original = presets.read_text()
        settings = project / 'project.godot'
        original_settings = settings.read_text()
        try:
            settings.write_text(original_settings.replace('run/main_scene="res://scenes/campaign.tscn"', 'run/main_scene="res://tests/desktop_acceptance.tscn"'))
            presets.write_text(original.replace('exclude_filter="tests/*,docs/*,', 'exclude_filter="docs/*,')
                               .replace('include_filter=""', 'include_filter="tests/fixtures/*.json"'))
            for platform, preset in [('windows', 'Windows Desktop'), ('linux', 'Linux Desktop')]:
                name = 'LiveForeverAcceptance.exe' if platform == 'windows' else 'LiveForeverAcceptance.x86_64'
                destination = output / ('acceptance-' + platform) / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                run('acceptance-' + platform, ['--export-release', preset, str(destination)])
                if platform == 'linux': destination.chmod(0o755)
                acceptance[platform] = {'path': str(destination), 'bytes': destination.stat().st_size,
                                        'sha256': hashlib.sha256(destination.read_bytes()).hexdigest()}
        finally:
            presets.write_text(original)
            settings.write_text(original_settings)
    (logs / 'build-inputs.json').write_text(json.dumps({'project': str(project), 'runtime_sha256': hashes,
                                                      'binaries': binaries, 'acceptance': acceptance}, indent=2) + '\n')
    print('Verified x86_64 PE / ELF with embedded data. Manifest: ' + str(logs / 'build-inputs.json'))


if __name__ == '__main__':
    main()
