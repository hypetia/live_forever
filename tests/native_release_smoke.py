#!/usr/bin/env python3
"""Drive an exported Linux game over X11, then verify actual saves across restart.
Requires libX11, libXtst, and ImageMagick's import command; no Python packages.
Use a dedicated X display because the probe sends genuine keyboard events.
"""
from pathlib import Path
import argparse
import ctypes as C
import ctypes.util
import json
import os
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--display', default=':98')
    parser.add_argument('--artifacts', type=Path, required=True)
    args = parser.parse_args()
    binary = args.binary.resolve()
    output = args.artifacts.resolve()
    output.mkdir(parents=True, exist_ok=True)
    profile = Path(tempfile.mkdtemp(prefix='live_forever_native.'))
    env = os.environ.copy()
    env['DISPLAY'] = args.display
    for kind in ['CONFIG', 'CACHE', 'DATA']:
        folder = profile / kind.lower()
        folder.mkdir()
        env[f'XDG_{kind}_HOME'] = str(folder)
    x = C.CDLL(ctypes.util.find_library('X11'))
    xt = C.CDLL(ctypes.util.find_library('Xtst'))
    D, U, I = C.c_void_p, C.c_ulong, C.c_int
    x.XOpenDisplay.argtypes, x.XOpenDisplay.restype = [C.c_char_p], D
    display = x.XOpenDisplay(args.display.encode())
    assert display, 'A dedicated X display must be running'
    x.XDefaultRootWindow.argtypes, x.XDefaultRootWindow.restype = [D], U
    root = x.XDefaultRootWindow(display)
    x.XQueryTree.argtypes = [D, U, C.POINTER(U), C.POINTER(U), C.POINTER(C.POINTER(U)), C.POINTER(C.c_uint)]
    x.XFetchName.argtypes = [D, U, C.POINTER(C.c_char_p)]
    x.XFree.argtypes = [D]
    x.XSetInputFocus.argtypes = [D, U, I, U]
    x.XRaiseWindow.argtypes = [D, U]
    x.XStringToKeysym.argtypes, x.XStringToKeysym.restype = [C.c_char_p], U
    x.XKeysymToKeycode.argtypes, x.XKeysymToKeycode.restype = [D, U], C.c_uint
    x.XFlush.argtypes = [D]
    x.XGrabServer.argtypes = [D]
    x.XUngrabServer.argtypes = [D]
    x.XGetWindowProperty.argtypes = [D, U, U, C.c_long, C.c_long, I, U, C.POINTER(U), C.POINTER(I), C.POINTER(U), C.POINTER(U), C.POINTER(C.POINTER(C.c_ubyte))]
    x.XInternAtom.argtypes, x.XInternAtom.restype = [D, C.c_char_p, I], U
    # Register the normal WM protocol before Godot's only-if-existing lookup.
    # A cold dedicated Xorg has no window manager to do this for us.
    for atom in [b'WM_DELETE_WINDOW', b'WM_PROTOCOLS']:
        assert x.XInternAtom(display, atom, False)
    x.XFlush(display)
    xt.XTestFakeKeyEvent.argtypes = [D, C.c_uint, I, U]

    def children(window):
        returned_root, parent, array, count = U(), U(), C.POINTER(U)(), C.c_uint()
        if not x.XQueryTree(display, window, C.byref(returned_root), C.byref(parent), C.byref(array), C.byref(count)):
            return []
        values = [array[i] for i in range(count.value)]
        if array:
            x.XFree(C.cast(array, D))
        return values

    def title(window):
        name = C.c_char_p()
        if not x.XFetchName(display, window, C.byref(name)) or not name:
            return ''
        text = name.value.decode('utf8', errors='replace')
        x.XFree(C.cast(name, D))
        return text

    def owner_pid(window):
        actual, count, after, form = U(), U(), U(), I()
        data = C.POINTER(C.c_ubyte)()
        atom = x.XInternAtom(display, b'_NET_WM_PID', False)
        result = x.XGetWindowProperty(display, window, atom, 0, 1, False, 6,
                                     C.byref(actual), C.byref(form), C.byref(count), C.byref(after), C.byref(data))
        try:
            return int(C.cast(data, C.POINTER(U))[0]) if result == 0 and form.value == 32 and count.value == 1 and data else None
        finally:
            if data: x.XFree(C.cast(data, D))

    class XError(C.Structure):
        _fields_ = [('type', I), ('display', D), ('resourceid', U), ('serial', U),
                    ('error_code', C.c_ubyte), ('request_code', C.c_ubyte), ('minor_code', C.c_ubyte)]

    error_handler_type = C.CFUNCTYPE(I, D, C.POINTER(XError))
    x.XSetErrorHandler.argtypes, x.XSetErrorHandler.restype = [D], D
    x.XSync.argtypes = [D, I]

    def find_ready_window(expected_pid=None, contains="Live Forever"):
        # Snapshot the tree under a short X server grab. Utility windows may
        # disappear during startup; querying stale children causes BadWindow.
        unexpected = []

        @error_handler_type
        def startup_error(_display, event):
            error = event.contents
            # A splash/utility window can vanish while startup is being scanned.
            # Its failed query is skipped by title()/owner_pid(); other X errors fail.
            if error.error_code != 3:
                unexpected.append((error.error_code, error.request_code, error.resourceid))
            return 0

        previous_handler = x.XSetErrorHandler(C.cast(startup_error, D))
        x.XGrabServer(display)
        try:
            pending = children(root)
            while pending:
                window = pending.pop()
                if contains in title(window):
                    if expected_pid is None or owner_pid(window) == expected_pid:
                        return window
                pending.extend(children(window))
            return None
        finally:
            x.XUngrabServer(display)
            x.XSync(display, False)
            x.XSetErrorHandler(previous_handler)
            assert not unexpected, ('Unexpected X11 startup scan errors', unexpected)

    def key(name, pressed):
        code = x.XKeysymToKeycode(display, x.XStringToKeysym(name.encode()))
        assert code, name
        xt.XTestFakeKeyEvent(display, code, int(pressed), 0)
        x.XFlush(display)

    def press(name):
        key(name, True)
        time.sleep(0.06)
        key(name, False)
        time.sleep(0.25)

    def hold(name, seconds):
        key(name, True)
        time.sleep(seconds)
        key(name, False)
        time.sleep(0.15)

    def state():
        files = list((profile / 'data').glob('godot/app_userdata/*/shelter_v1.json'))
        assert len(files) == 1, files
        return json.loads(json.loads(files[0].read_text())['data_json'])

    def save():
        press('F6')
        return state()

    class ClientData(C.Union):
        _fields_ = [('b', C.c_char * 20), ('s', C.c_short * 10), ('l', C.c_long * 5)]

    class Client(C.Structure):
        _fields_ = [('type', I), ('serial', U), ('send_event', I), ('display', D), ('window', U), ('message_type', U), ('format', I), ('data', ClientData)]

    class Event(C.Union):
        _fields_ = [('client', Client), ('pad', C.c_long * 24)]

    x.XSendEvent.argtypes = [D, U, I, C.c_long, C.POINTER(Event)]

    def close(window, process):
        event = Event()
        event.client.type, event.client.display, event.client.window = 33, display, window
        event.client.message_type = x.XInternAtom(display, b'WM_PROTOCOLS', 0)
        event.client.format = 32
        event.client.data.l[0] = x.XInternAtom(display, b'WM_DELETE_WINDOW', 0)
        assert x.XSendEvent(display, window, False, 0, C.byref(event))
        x.XFlush(display)
        try:
            assert process.wait(timeout=15) == 0
        except subprocess.TimeoutExpired:
            subprocess.run(['import', '-display', args.display, '-window', str(window), str(output / 'close-timeout.png')], check=True, timeout=15)
            diagnostics = {'pid': process.pid, 'profile': str(profile), 'saved': state(),
                           'waits': {p.parent.name: p.read_text() for p in Path('/proc', str(process.pid), 'task').glob('*/wchan')}}
            (output / 'close-timeout.json').write_text(json.dumps(diagnostics, ensure_ascii=False, indent=2))
            raise

    def launch(logname):
        log = (output / logname).open('w')
        process = subprocess.Popen([str(binary), '--resolution', '1440x900', '--audio-driver', 'Dummy', '--', '--trace-exit'], env=env, stdout=log, stderr=subprocess.STDOUT)
        for _ in range(600):
            if process.poll() is not None:
                log.close()
                raise RuntimeError('Native startup exited; see ' + logname)
            window = find_ready_window(process.pid)
            if window:
                x.XRaiseWindow(display, window)
                x.XSetInputFocus(display, window, 2, 0)
                x.XFlush(display)
                time.sleep(0.5)
                return process, window, log
            time.sleep(0.1)
        process.terminate()
        process.wait(timeout=15)
        log.close()
        raise RuntimeError('No ready native window; see ' + logname)

    assert not find_ready_window(), 'Use a dedicated empty X display'
    process, window, log = launch('first.log')
    try:
        # A title can appear before the first interactive frame on a busy
        # software renderer. Require an actual F6 response, not a fixed delay.
        initial = None
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            press('3')
            press('F6')
            files = list((profile / 'data').glob('godot/app_userdata/*/shelter_v1.json'))
            if files:
                initial = state()
                if initial['selected_id'] == 2:
                    break
        assert initial is not None and initial['selected_id'] == 2, 'No real selection/save response after startup'
        assert [actor['person']['persona'] for actor in initial['actors']] == ['lin', 'xu', 'chen']
        # Regress the reported daytime keyboard gap using genuine OS events.
        def move_day(name, reference, direction):
            key(name, True)
            deadline = time.monotonic() + 25
            try:
                while True:
                    latest = save()
                    assert not latest['paused'], 'Daytime input probe unexpectedly paused'
                    if (latest['actors'][2]['position'][0] - reference) * direction > 10:
                        break
                    assert time.monotonic() < deadline, ('Actual held movement did not advance', name, latest['simulation_time'], latest['actors'][2]['position'])
            finally:
                key(name, False)
            time.sleep(.2)
            return save()
        day_x = initial['actors'][2]['position'][0]
        moved_right = move_day('d', day_x, 1)
        moved_left = move_day('a', moved_right['actors'][2]['position'][0], -1)
        assert moved_left['actors'][2]['route'] == [], 'Released keyboard movement left a saved floor destination'
        print('NATIVE DAY KEYBOARD PASS: real A/D moves in shelter; key release leaves no phantom route', flush=True)
        press('z')
        inspection = save()
        assert inspection['paused'] and inspection['campaign']['phase'] == 'day', 'Z did not open a paused security inspection'
        press('Return')
        inspected = save()
        assert inspected['simulation_time'] == inspection['simulation_time'] and inspected['campaign']['phase'] == 'day', 'Inspection allowed simulation or a night transition'
        press('Escape')
        assert not save()['paused'], 'Closing inspection did not restore play'
        print('NATIVE SECURITY PASS: real Z opens inspection, Enter is consumed, Escape restores play', flush=True)
        press('v')
        press('Return')
        # End-day simulation and the next rendered frame can take longer
        # than a key's release delay. Observe the saved phase before confirming.
        deadline = time.monotonic() + 20
        while True:
            plan = save()
            if plan.get('campaign', {}).get('phase') == 'planning' or plan['expedition']['active']:
                break
            assert time.monotonic() < deadline, 'End day never reached assignment'
        if not plan['expedition']['active']:
            press('Return')
        deadline = time.monotonic() + 20
        while True:
            trip = save()
            if trip['expedition']['active']:
                break
            assert time.monotonic() < deadline, 'Night confirmation never entered the field'
        assert trip['expedition']['active'] and trip['expedition']['actor_id'] == 2, trip['expedition']
        # Only genuine OS keyboard input controls the game; the build has no test scripts.
        hold('d', 1.0)
        position = save()['expedition']['player_x']
        if abs(position - 300) >= 45:
            hold('a' if position > 300 else 'd', abs(position - 300) / 190)
            position = save()['expedition']['player_x']
        assert abs(position - 300) < 58, position
        # Observe actual search completion; wall time can diverge from the
        # capped simulation delta while a software renderer compiles shaders.
        key('e', True)
        deadline = time.monotonic() + 20
        try:
            while True:
                searched = save()
                field = searched['expedition']
                if field.get('loot_site', -1) >= 0 or field['bag']['raw_food'] >= 2:
                    break
                assert time.monotonic() < deadline, 'Real held-E search never completed'
        finally:
            key('e', False)
        if searched['expedition'].get('manual_loot'):
            press('f')
        looted = save()
        assert looted['expedition']['bag']['raw_food'] == 2 and looted['expedition']['bag']['water'] == 1, looted['expedition']
        assert looted['stock']['raw_food'] == 4, 'Remote cargo credit'
        # Regression: invoke T inside the loot pane, away from the exit.
        assert looted['expedition']['player_x'] > 145, 'Return regression must start away from extraction'
        press('t')
        deadline = time.monotonic() + 25
        # The embedded modal consumes F6. Its opening can therefore leave a
        # pre-arrival snapshot on disk. Send genuine Enter events while the
        # requested route completes, then require a fresh dawn save. Enter has
        # no action in the field before the modal opens.
        exit_confirmation_sent = False
        while True:
            press('Return')
            exit_confirmation_sent = True
            returned = save()
            if not returned['expedition']['active']:
                break
            assert returned['stock'] == looted['stock'], 'Cargo credited before exit confirmation'
            assert returned['campaign']['return_requested'], 'T did not queue return through the loot pane'
            if time.monotonic() >= deadline:
                subprocess.run(['import', '-display', args.display, '-window', str(root), str(output / 'return-timeout.png')], check=True, timeout=15)
                (output / 'return-timeout.json').write_text(json.dumps({'saved':returned,'windows':[(int(w),title(w),owner_pid(w)) for w in children(root)]},ensure_ascii=False,indent=2))
                raise AssertionError('Queued physical return never reached extraction')
        assert exit_confirmation_sent, 'Physical return skipped explicit exit confirmation'
        assert not returned['expedition']['active'] and returned['paused']
        assert returned['stock']['raw_food'] == 6 and returned['stock']['water'] == 5 and returned['stock']['medicine'] == 1, returned['stock']
        assert returned['upkeep']['returns']['street'] == 1
        assert returned['actors'][2]['person']['experience']['scout'] == 4
        subprocess.run(['import', '-display', args.display, '-window', str(window), str(output / 'native-return.png')], check=True, timeout=15)
        close(window, process)
        log.close()
        print('NATIVE PASS: exported game, real OS input, search, inventory T return, physical retreat, explicit exit confirmation, one-time cargo and normal close', flush=True)
        process, window, log = launch('restart.log')
        resumed = save()
        assert resumed['paused'] and not resumed['expedition']['active']
        assert resumed['stock'] == returned['stock'] and resumed['upkeep']['returns']['street'] == 1
        assert resumed['expedition']['sites'][0]['contents']['raw_food'] == 0
        assert resumed['actors'][2]['person']['experience']['scout'] == 4
        assert not any(actor['person']['routine'] for actor in resumed['actors'])
        close(window, process)
        log.close()
        print('NATIVE RESTART PASS: same executable restores real supplies and world depletion without duplication', flush=True)
        for name in ['first.log', 'restart.log']:
            content = (output / name).read_text()
            assert 'ERROR:' not in content and 'instances leaked' not in content, (name, content)
        (output / 'profile-path.txt').write_text(str(profile) + '\n')
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=15)


if __name__ == '__main__':
    main()
