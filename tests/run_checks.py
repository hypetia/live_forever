#!/usr/bin/env python3
"""Run the real Godot checks in a fresh checkout/profile using only the stdlib."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', default='godot')
    parser.add_argument('--graphics', action='store_true', help='Requires a working graphical DISPLAY')
    parser.add_argument('--artifacts', type=Path, help='Directory for validation logs')
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    workspace = Path(tempfile.mkdtemp(prefix='live_forever_verify.'))
    project = workspace / 'live_forever'
    shutil.copytree(source, project, ignore=shutil.ignore_patterns('.git', '.godot', 'builds', '__pycache__'))
    output = args.artifacts or workspace / 'logs'
    output.mkdir(parents=True, exist_ok=True)
    (output / 'clean-project-path.txt').write_text(str(project) + '\n')
    env = os.environ.copy()
    for kind in ['CONFIG', 'CACHE', 'DATA']:
        folder = workspace / 'profile' / kind.lower()
        folder.mkdir(parents=True)
        env[f'XDG_{kind}_HOME'] = str(folder)
    # Tests own their slots. They never load or overwrite the player's profile.
    def run(name, command, marker=None):
        process = subprocess.run([args.engine, *command], cwd=project, env=env,
                                 text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 timeout=600 if name == "endurance" else 180)
        (output / f'{name}.log').write_text(process.stdout)
        bad = process.returncode != 0 or any(word in process.stdout for word in ['SCRIPT ERROR:', 'ERROR:', 'FAIL: ', 'FAIL visual:', 'ObjectDB instances leaked'])
        if marker and marker not in process.stdout:
            bad = True
        if bad:
            raise RuntimeError(f'{name} failed; see {output / (name + ".log")}\n{process.stdout[-5000:]}')
        print(f'PASS {name}' + (': ' + marker if marker else ''), flush=True)
        return process.stdout

    run('import', ['--headless', '--path', str(project), '--editor', '--import', '--quit'])
    run('font', ['--headless', '--path', str(project), '--script', 'res://tests/test_font.gd'], 'PASS font:')
    logical = 0
    for name, checks, cases in [('shelter', 41, 8), ('cooking', 57, 10), ('survival', 54, 12),
                               ('saves', 74, 12), ('expedition', 76, 17), ('expedition_saves', 88, 12),
                               ('long_term', 97, 19), ('people', 124, 24), ('story', 68, 13),
                               ('goals', 63, 12), ('balance', 23, 4), ('endurance', 22, 3)]:
        command = ['--headless', '--path', str(project), '--script', f'res://tests/test_{name}.gd']
        if name == 'balance': command += ['--', str(output.resolve() / 'balance')]
        if name == 'endurance': command += ['--', str(output.resolve() / 'endurance')]
        run(name, command,
            f'{checks} checks, 0 failures; {cases} scenarios executed.')
        logical += checks
    run('campaign', ['--headless', '--path', str(project), '--script', 'res://tests/test_campaign.gd'], '85 checks, 0 failures')
    logical += 85
    run('expansion', ['--headless', '--path', str(project), '--script', 'res://tests/test_expansion.gd'], '103 checks, 0 failures')
    logical += 103
    run('vitals', ['--headless', '--path', str(project), '--script', 'res://tests/test_vitals.gd'], '30 checks, 0 failures')
    logical += 30
    run('residence', ['--headless', '--path', str(project), '--script', 'res://tests/test_residence.gd'], '90 checks, 0 failures')
    logical += 90
    run('interactions', ['--headless', '--path', str(project), '--script', 'res://tests/test_interactions.gd'], '87 checks, 0 failures')
    logical += 87
    run('keyboard_movement', ['--headless', '--path', str(project), '--script', 'res://tests/test_keyboard_movement.gd'], '27 checks, 0 failures')
    logical += 27
    run('startup', ['--headless', '--path', str(project), '--quit-after', '8'])
    for name, phases in [('persistence_process', ['write', 'read']),
                         ('persistence_expedition_process', ['write', 'read', 'verify']),
                         ('persistence_long_term_process', ['write', 'read', 'verify']),
                         ('persistence_people_process', ['write', 'read', 'verify']),
                         ('persistence_story_process', ['write', 'read', 'verify']),
                         ('persistence_goals_process', ['write', 'read', 'verify']),
                         ('persistence_campaign_process', ['write', 'read', 'verify']),
                         ('persistence_expansion_process', ['write', 'read', 'verify']),
                         ('persistence_residence_process', ['write', 'pack', 'move', 'verify']),
                         ('persistence_interactions_process', ['write', 'read', 'return', 'verify'])]:
        slot = workspace / f'{name}.json'
        for phase in phases:
            run(f'{name}-{phase}', ['--headless', '--path', str(project), '--script',
                f'res://tests/{name}.gd', '--', phase, str(slot)], 'PASS:')
    graphical = 0
    if args.graphics:
        for name, count in [('visual_smoke', 36), ('visual_expedition', 36), ('visual_long_term', 24), ('visual_people', 22), ('visual_story', 17), ('visual_goals', 24), ('visual_presentation', 45), ('visual_campaign', 47), ('visual_expansion', 15), ('visual_quiet', 20), ('visual_residence', 26), ('visual_interactions', 25), ('visual_keyboard_movement', 10)]:
            run(name, ['--path', str(project), '--resolution', '1440x900', '--audio-driver', 'Dummy',
                '--script', f'res://tests/{name}.gd'], f'{count} checks, 0 failures')
            graphical += count
    print(f'Validated {logical} logical checks, {graphical} GUI checks, startup and 31 persistence processes.')
    print(f'Clean project: {project}\nLogs: {output}')


if __name__ == '__main__':
    main()
