"""Lokale Prüfung der Zeitcode-Arithmetik, ohne Resolve-Projekt."""
import unittest
from unittest.mock import patch

from bridge import format_duration, fps_value, get_marks, read_timeline, display_50i, display_values


class Timeline:
    def GetCurrentTimecode(self):
        return '01:00:03:12'

    def GetSetting(self, key):
        return '25'

    def GetStartFrame(self):
        return 90000

    def GetEndFrame(self):
        return 90125

    def GetMarkInOut(self):
        return {'video': {'in': 17, 'out': 41}}


class BridgeTest(unittest.TestCase):
    def test_three_displays(self):
        self.assertEqual(read_timeline(Timeline(), None), {
            'master': '01:00:03:12',
            'inout': '00:00:01:00',
            'total': '00:00:05:00',
        })

    def test_drop_frame_boundaries(self):
        for rate, minute, ten in [(29.97, 1800, 17982), (59.94, 3600, 35964)]:
            self.assertEqual(format_duration(minute, rate, True),
                             '00:01:00;' + ('02' if minute == 1800 else '04'))
            self.assertEqual(format_duration(ten, rate, True), '00:10:00;00')

    def test_50i_and_50p(self):
        timeline = Timeline()
        timeline.GetSetting = lambda key: {
            'timelineFrameRate': '50',
            'timelineInterlaceProcessing': '1',
        }.get(key)
        timeline.GetCurrentTimecode = lambda: '01:00:03:49'
        with patch.dict('os.environ', {'TIMECODE_DISPLAY_MODE': 'auto'}):
            self.assertEqual(read_timeline(timeline, None), {
                'master': '01:00:03:24*',
                'inout': '00:00:00:13',
                'total': '00:00:02:13',
            })
        with patch.dict('os.environ', {'TIMECODE_DISPLAY_MODE': 'progressive'}):
            self.assertEqual(read_timeline(timeline, None)['master'], '01:00:03:49')
        self.assertEqual(display_50i('01:00:03:02'), '01:00:03:01')
        self.assertEqual(display_50i('01:00:03:03'), '01:00:03:01*')

    def test_50i_durations_are_whole_frames(self):
        for fields, expected in [(1, 1), (2, 1), (3, 2), (49, 25), (50, 25)]:
            with self.subTest(fields=fields):
                timeline = Timeline()
                timeline.GetMarkInOut = lambda: {'video': {'in': 17, 'out': 16 + fields}}
                values = display_values('01:00:00:03', (50, True, fields, get_marks(timeline)))
                duration = format_duration(expected, 25)
                self.assertEqual(values, {
                    'master': '01:00:00:01*',
                    'inout': duration,
                    'total': duration,
                })

    def test_invalid_marks_and_rate(self):
        timeline = Timeline()
        timeline.GetMarkInOut = lambda: {'video': {'in': 9, 'out': 3}}
        self.assertIsNone(get_marks(timeline))
        timeline.GetMarkInOut = lambda: {'video': {'in': 3}}
        self.assertIsNone(get_marks(timeline))
        timeline.GetMarkInOut = lambda: {'video': {'in': 3, 'out': 3}}
        self.assertEqual(get_marks(timeline), 1)
        self.assertEqual(fps_value('nan'), 25.0)
        self.assertEqual(fps_value('23,976'), 23.976)


if __name__ == '__main__':
    unittest.main()
