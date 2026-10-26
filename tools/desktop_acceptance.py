#!/usr/bin/env python3
"""Run an exported Linux QA application, then perform actual WM close and restart.
Use a dedicated empty X display. Windows has its own built-in PowerShell runner.
"""
from pathlib import Path
import argparse
import ctypes as C
import ctypes.util
import hashlib
import json
import os
import subprocess
import tempfile
import time


class XDesktop:
    def __init__(self, name):
        self.x = x = C.CDLL(ctypes.util.find_library('X11'))
        self.xt = xt = C.CDLL(ctypes.util.find_library('Xtst'))
        D, U, I = C.c_void_p, C.c_ulong, C.c_int
        x.XOpenDisplay.argtypes, x.XOpenDisplay.restype = [C.c_char_p], D
        self.display = x.XOpenDisplay(name.encode())
        assert self.display, 'Start a dedicated X display'
        x.XDefaultRootWindow.argtypes, x.XDefaultRootWindow.restype = [D], U
        self.root = x.XDefaultRootWindow(self.display)
        x.XQueryTree.argtypes = [D, U, C.POINTER(U), C.POINTER(U), C.POINTER(C.POINTER(U)), C.POINTER(C.c_uint)]
        x.XFetchName.argtypes = [D, U, C.POINTER(C.c_char_p)]
        x.XFree.argtypes = [D]
        x.XFlush.argtypes = [D]
        x.XGrabServer.argtypes = [D]
        x.XUngrabServer.argtypes = [D]
        x.XGetWindowProperty.argtypes = [D, U, U, C.c_long, C.c_long, I, U, C.POINTER(U), C.POINTER(I), C.POINTER(U), C.POINTER(U), C.POINTER(C.POINTER(C.c_ubyte))]
        x.XSync.argtypes = [D, I]
        x.XSetInputFocus.argtypes = [D, U, I, U]
        x.XRaiseWindow.argtypes = [D, U]
        x.XStringToKeysym.argtypes, x.XStringToKeysym.restype = [C.c_char_p], U
        x.XKeysymToKeycode.argtypes, x.XKeysymToKeycode.restype = [D, U], C.c_uint
        xt.XTestFakeKeyEvent.argtypes = [D, C.c_uint, I, U]
        x.XInternAtom.argtypes, x.XInternAtom.restype = [D, C.c_char_p, I], U
        # A bare Xorg has no WM to intern this atom. Godot 4.6.3 looks it up
        # with only_if_exists=True at startup, so act as the missing WM first.
        for atom in [b'WM_DELETE_WINDOW', b'WM_PROTOCOLS']:
            assert x.XInternAtom(self.display, atom, False)
        x.XSync(self.display, False)

        class Data(C.Union):
            _fields_ = [('b', C.c_char * 20), ('s', C.c_short * 10), ('l', C.c_long * 5)]

        class Client(C.Structure):
            _fields_ = [('type', I), ('serial', U), ('send_event', I), ('display', D), ('window', U), ('message_type', U), ('format', I), ('data', Data)]

        class Event(C.Union):
            _fields_ = [('client', Client), ('pad', C.c_long * 24)]
        self.Event = Event
        x.XSendEvent.argtypes = [D, U, I, C.c_long, C.POINTER(Event)]

    def children(self, window):
        U = C.c_ulong
        parent, root, array, count = U(), U(), C.POINTER(U)(), C.c_uint()
        if not self.x.XQueryTree(self.display, window, C.byref(root), C.byref(parent), C.byref(array), C.byref(count)):
            return []
        values = [array[i] for i in range(count.value)]
        if array:
            self.x.XFree(C.cast(array, C.c_void_p))
        return values

    def owner_pid(self, window):
        U, I, D = C.c_ulong, C.c_int, C.c_void_p
        actual, count, after, form = U(), U(), U(), I()
        data = C.POINTER(C.c_ubyte)()
        atom = self.x.XInternAtom(self.display, b'_NET_WM_PID', False)
        result = self.x.XGetWindowProperty(self.display, window, atom, 0, 1, False, 6,
                                          C.byref(actual), C.byref(form), C.byref(count), C.byref(after), C.byref(data))
        try:
            return int(C.cast(data, C.POINTER(U))[0]) if result == 0 and form.value == 32 and count.value == 1 and data else None
        finally:
            if data: self.x.XFree(C.cast(data, D))

    def window(self, expected_pid=None):
        self.x.XGrabServer(self.display)
        try:
            pending = self.children(self.root)
            while pending:
                window = pending.pop()
                name = C.c_char_p()
                if self.x.XFetchName(self.display, window, C.byref(name)) and name:
                    title = name.value.decode('utf8', errors='replace')
                    self.x.XFree(C.cast(name, C.c_void_p))
                    if 'Live Forever' in title:
                        if expected_pid is None or self.owner_pid(window) == expected_pid:
                            return window
                pending.extend(self.children(window))
            return None
        finally:
            self.x.XUngrabServer(self.display)
            self.x.XFlush(self.display)

    def focus(self, window):
        self.x.XRaiseWindow(self.display, window)
        self.x.XSetInputFocus(self.display, window, 2, 0)
        self.x.XSync(self.display, False)

    def press(self, name):
        code = self.x.XKeysymToKeycode(self.display, self.x.XStringToKeysym(name.encode()))
        assert code
        self.xt.XTestFakeKeyEvent(self.display, code, True, 0)
        self.x.XFlush(self.display)
        time.sleep(0.08)
        self.xt.XTestFakeKeyEvent(self.display, code, False, 0)
        self.x.XSync(self.display, False)

    def close(self, window):
        event = self.Event()
        event.client.type, event.client.display, event.client.window = 33, self.display, window
        event.client.message_type = self.x.XInternAtom(self.display, b'WM_PROTOCOLS', False)
        event.client.format = 32
        event.client.data.l[0] = self.x.XInternAtom(self.display, b'WM_DELETE_WINDOW', False)
        assert self.x.XSendEvent(self.display, window, False, 0, C.byref(event))
        self.x.XSync(self.display, False)


def read_save(path):
    envelope = json.loads(path.read_text())
    assert hashlib.sha256(envelope['data_json'].encode()).hexdigest() == envelope['sha256']
    return json.loads(envelope['data_json'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('acceptance_binary', type=Path)
    parser.add_argument('--artifacts', type=Path, required=True)
    parser.add_argument('--minutes', type=float, default=30)
    parser.add_argument('--display', default=':98')
    args = parser.parse_args()
    folder = args.artifacts.resolve()
    folder.mkdir(parents=True, exist_ok=True)
    assert not (folder / 'session.json').exists(), 'Use a fresh output directory'
    desktop = XDesktop(args.display)
    assert not desktop.window(), 'Use a dedicated empty X display'
    env = os.environ.copy()
    env['DISPLAY'] = args.display
    profile = Path(tempfile.mkdtemp(prefix='live_forever_desktop.'))
    for key in ['CONFIG', 'CACHE', 'DATA']:
        path = profile / key.lower()
        path.mkdir()
        env[f'XDG_{key}_HOME'] = str(path)
    binary = str(args.binary.resolve())
    command = [str(args.acceptance_binary.resolve()), '--resolution', '1440x900', '--audio-driver', 'Dummy', '--',
               '--output', str(folder), '--minutes', str(args.minutes), '--trace-exit']
    process = None

    def close_process():
        window = desktop.window(process.pid)
        assert window, 'Missing game window before real close'
        desktop.close(window)
        try:
            assert process.wait(timeout=15) == 0
        except subprocess.TimeoutExpired:
            subprocess.run(['import', '-display', args.display, '-window', str(window), str(folder / 'close-timeout.png')], timeout=15, check=True)
            raise

    try:
        with (folder / 'continuous.log').open('w') as log:
            process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + args.minutes * 60 + 180
            report = {}
            memory_samples = []
            next_memory_sample = 0.0
            while time.monotonic() < deadline:
                assert process.poll() is None, 'Game exited during continuous test'
                if time.monotonic() >= next_memory_sample:
                    next_memory_sample = time.monotonic() + 10
                    status = Path('/proc', str(process.pid), 'status').read_text()
                    rss = next(int(line.split()[1]) * 1024 for line in status.splitlines() if line.startswith('VmRSS:'))
                    memory_samples.append({'monotonic_seconds': time.monotonic(), 'resident_bytes': rss})
                report_file = folder / 'desktop-report.json'
                if report_file.exists():
                    report = json.loads(report_file.read_text())
                    if report['status'] in ['ready_to_close', 'failed']:
                        break
                time.sleep(1)
            assert report.get('status') == 'ready_to_close', report
            before = read_save(folder / 'session.json')
            close_process()
        with (folder / 'restart.log').open('w') as log:
            process = subprocess.Popen([binary, '--resolution', '1440x900', '--audio-driver', 'Dummy',
                                        '--', '--qa-slot=' + str(folder / 'session.json'), '--trace-exit'],
                                       env=env, stdout=log, stderr=subprocess.STDOUT)
            for _ in range(600):
                assert process.poll() is None
                window = desktop.window(process.pid)
                if window:
                    break
                time.sleep(.1)
            else:
                raise RuntimeError('No restored window')
            desktop.focus(window)
            time.sleep(1)
            desktop.press('F6')
            time.sleep(1)
            after = read_save(folder / 'session.json')
            assert after['paused'] and after['stock'] == before['stock']
            assert after['goals'] == before['goals'] and after['story'] == before['story']
            assert after['campaign'] == before['campaign']
            assert after['expansion'] == before['expansion']
            assert after['residence'] == before['residence']
            assert abs(after['simulation_time'] - before['simulation_time']) < .000001
            close_process()
        for name in ['continuous.log', 'restart.log']:
            text = (folder / name).read_text()
            assert not any(item in text for item in ['ERROR:', 'SCRIPT ERROR:', 'instances leaked']), name
        report.update(native_close_and_restart='passed', executable_sha256=hashlib.sha256(Path(binary).read_bytes()).hexdigest(),
                      acceptance_binary_sha256=hashlib.sha256(args.acceptance_binary.read_bytes()).hexdigest(),
                      continuous_30_minutes_complete=report['elapsed_seconds'] >= 1800,
                      process_memory_samples=memory_samples)
        (folder / 'acceptance-result.json').write_text(json.dumps(report, indent=2) + '\n')
        print(f'DESKTOP ACCEPTANCE PASSED: {report["elapsed_seconds"]:.1f}s actual gameplay, matrix/fullscreen, real WM close and restart')
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=15)


if __name__ == '__main__':
    main()
