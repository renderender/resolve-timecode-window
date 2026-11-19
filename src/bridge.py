#!/usr/bin/env python3
"""Read-only DaVinci Resolve timeline polling bridge. JSON lines on stdout."""
import sys, os, json, time, math

API = '/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting'
sys.path.insert(0, os.path.join(API, 'Modules'))
os.environ.setdefault('RESOLVE_SCRIPT_API', API)
os.environ.setdefault('RESOLVE_SCRIPT_LIB', '/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so')


def fps_value(value):
    try:
        rate = float(str(value).replace(',', '.'))
        return rate if math.isfinite(rate) and rate > 0 else 25.0
    except (TypeError, ValueError):
        return 25.0


def format_duration(frames, rate, drop=False):
    frames = max(0, int(frames))
    nominal = round(rate)
    if nominal <= 0:
        nominal = 25
    if drop and nominal in (30, 60) and abs(rate - nominal * 1000 / 1001) < 0.08:
        d = 2 if nominal == 30 else 4
        frames_per_10 = nominal * 600 - d * 9
        tens, remainder = divmod(frames, frames_per_10)
        extra_minutes = max(0, (remainder - d) // (nominal * 60 - d))
        timecode_frames = frames + d * (9 * tens + extra_minutes)
        sep = ';'
    else:
        timecode_frames = frames
        sep = ':'
    ff = timecode_frames % nominal
    total_seconds = timecode_frames // nominal
    ss = total_seconds % 60
    mm = (total_seconds // 60) % 60
    hh = total_seconds // 3600
    return f'{hh:02}:{mm:02}:{ss:02}{sep}{ff:02}'


def get_marks(timeline):
    marks = timeline.GetMarkInOut() or {}
    if not isinstance(marks, dict):
        return None
    for kind in ('video', 'audio'):
        pair = marks.get(kind)
        if isinstance(pair, dict) and 'in' in pair and 'out' in pair:
            try:
                first, last = int(pair['in']), int(pair['out'])
                if 0 <= first <= last:
                    return last - first + 1
            except (ValueError, TypeError, OverflowError):
                continue
    return None


def display_50i(value):
    if value == '--:--:--:--':
        return value
    prefix, field = value.rsplit(':', 1)
    frame, second_field = divmod(int(field), 2)
    return f'{prefix}:{frame:02}' + ('*' if second_field else '')


def read_metadata(timeline, project):
    rate = fps_value(timeline.GetSetting('timelineFrameRate') or project.GetSetting('timelineFrameRate'))
    mode = os.environ.get('TIMECODE_DISPLAY_MODE', 'auto')
    interlaced = mode == '50i'
    if mode == 'auto' and rate == 50:
        setting = timeline.GetSetting('timelineInterlaceProcessing')
        if setting is None or setting == '':
            setting = project.GetSetting('timelineInterlaceProcessing')
        interlaced = str(setting).lower() in ('1', 'true')
    total = int(timeline.GetEndFrame()) - int(timeline.GetStartFrame())
    return rate, interlaced and rate == 50, total, get_marks(timeline)


def display_values(master, metadata):
    rate, interlaced, total, marked = metadata
    drop = ';' in master
    if interlaced:
        master = display_50i(master)
        rate = 25
        drop = False
        # An odd field count occupies a final partial frame.
        total = (total + 1) // 2
        if marked is not None:
            marked = (marked + 1) // 2
    return {
        'master': master,
        'total': format_duration(total, rate, drop),
        'inout': format_duration(marked, rate, drop) if marked is not None else '--:--:--:--',
    }


def read_timeline(timeline, project):
    return display_values(timeline.GetCurrentTimecode() or '--:--:--:--',
                          read_metadata(timeline, project))


def run(once=False):
    resolve = None
    previous_status = None
    metadata = None
    refresh_at = 0.0
    timeline = None
    deadline = time.monotonic() + 12 if "--playback-probe" in sys.argv else None
    while True:
        payload = dict.fromkeys(('master', 'inout', 'total'), '--:--:--:--')
        try:
            if resolve is None:
                import DaVinciResolveScript as dvr
                resolve = dvr.scriptapp('Resolve')
            if time.monotonic() >= refresh_at:
                manager = resolve.GetProjectManager() if resolve else None
                project = manager.GetCurrentProject() if manager else None
                timeline = project.GetCurrentTimeline() if project else None
                metadata = read_metadata(timeline, project) if timeline else None
                refresh_at = time.monotonic() + 0.5
            if timeline:
                started = time.monotonic()
                master = timeline.GetCurrentTimecode() or '--:--:--:--'
                if deadline is not None:
                    print(f'API {(time.monotonic() - started) * 1000:.0f} ms | {master}',
                          file=sys.stderr, flush=True)
                payload = display_values(master, metadata)
                status = 'OK'
            elif not resolve:
                status = 'Could not connect to Resolve. Check that Resolve Studio is running and External scripting using is set to Local.'
            else:
                status = 'No timeline is open.'
        except Exception as exc:
            resolve = None
            timeline = None
            refresh_at = 0.0
            status = f'{type(exc).__name__}: {exc}'
        if status != previous_status and status != 'OK':
            print(status, file=sys.stderr, flush=True)
        previous_status = status
        print(json.dumps(payload), flush=True)
        if once:
            return 0 if status == 'OK' else 1
        if deadline is not None and time.monotonic() >= deadline:
            return 0 if status == 'OK' else 1
        time.sleep(0.02 if status == 'OK' else 0.5)


if __name__ == '__main__':
    sys.exit(run(once='--once' in sys.argv))
