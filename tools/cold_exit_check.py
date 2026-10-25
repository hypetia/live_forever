#!/usr/bin/env python3
"""Repeat exported-game OS-input/close/restart checks on genuinely cold X servers."""
from pathlib import Path
import argparse
import ctypes as C
import ctypes.util
import json
import hashlib
import os
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--artifacts', type=Path, required=True)
    parser.add_argument('--display', default=':99')
    parser.add_argument('--rounds', type=int, default=3)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    output = args.artifacts.resolve()
    output.mkdir(parents=True, exist_ok=True)
    x = C.CDLL(ctypes.util.find_library('X11'))
    x.XOpenDisplay.argtypes, x.XOpenDisplay.restype = [C.c_char_p], C.c_void_p
    x.XCloseDisplay.argtypes = [C.c_void_p]
    x.XInternAtom.argtypes, x.XInternAtom.restype = [C.c_void_p, C.c_char_p, C.c_int], C.c_ulong
    assert not x.XOpenDisplay(args.display.encode()), 'Use an unused dedicated display'
    results = []
    binary_sha256 = hashlib.sha256(args.binary.read_bytes()).hexdigest()
    for index in range(args.rounds):
        folder = output / f'round-{index + 1}'
        folder.mkdir(exist_ok=True)
        server = None
        with (folder / 'server.log').open('w') as server_log:
            try:
                server = subprocess.Popen(['/usr/lib/xorg/Xorg', args.display, '-config',
                    str(source / 'tests/support/xorg-dummy.conf'), '-logfile', str(folder / 'xorg.log'),
                    '-noreset', '-nolisten', 'tcp'], stdout=server_log, stderr=subprocess.STDOUT)
                for _ in range(100):
                    display = x.XOpenDisplay(args.display.encode())
                    if display:
                        break
                    assert server.poll() is None, 'Xorg startup failed'
                    time.sleep(.1)
                else:
                    raise RuntimeError('Xorg startup timed out')
                cold_atom = x.XInternAtom(display, b'WM_DELETE_WINDOW', True)
                x.XCloseDisplay(display)
                assert cold_atom == 0, 'Test server was not genuinely cold'
                process = subprocess.run([sys.executable, str(source / 'tests/native_release_smoke.py'),
                    str(args.binary.resolve()), '--display', args.display, '--artifacts', str(folder / 'native')],
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
                (folder / 'native.log').write_text(process.stdout)
                assert process.returncode == 0 and 'NATIVE RESTART PASS:' in process.stdout, process.stdout
                results.append({'round': index + 1, 'cold_wm_delete_atom': cold_atom, 'close_and_restart': 'passed'})
                print(f'COLD EXIT PASS: round {index + 1}; atom initially absent, genuine OS input, close and restart', flush=True)
            finally:
                if server is not None and server.poll() is None:
                    server.terminate()
                    server.wait(timeout=15)
    assert hashlib.sha256(args.binary.read_bytes()).hexdigest() == binary_sha256
    (output / 'cold-exit-result.json').write_text(json.dumps({'rounds': results, 'game_runtime_patched_for_probe': False, 'binary_sha256': binary_sha256}, indent=2) + '\n')


if __name__ == '__main__':
    main()
