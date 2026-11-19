# Resolve Timecode Window

An independent community macOS utility displaying Master TC, In-Out Duration and Total Duration in a resizable floating window.

Developed for DaVinci Resolve 21 Studio on macOS 14 or later, on Apple silicon and Intel. The playback display reads user-selected viewer regions using Apple's local text recognition. It is approximate and can lag. Frame digits are replaced by dashes during detected playback. Orange indicates held duration values awaiting a fresh API response.

Current version: **1.6.13**.

Double-click the display to open Settings. Settings provides capture rate,
timecode format, capture area selection and a preview of saved areas.
Window placement and settings persist across restarts.

Download the app ZIP from this repository's Releases page.

Read [the setup guide](HOWTO.md) before use. Keep the selected viewer digits visible. Screen Recording permission is required. Capture regions and window placement are saved locally.

## Build

Install Apple's Command Line Tools, then run:

```sh
./build.sh
```

The script builds both architectures, applies an ad-hoc signature, and produces a ZIP with the app and documentation. Builds are not Apple-notarized.

Run the bridge's arithmetic tests with:

```sh
python3 -B src/Bridge-Pruefung.py
```

## Project status

This is a personal utility developed with AI assistance. Playback recognition, latency and multi-monitor behavior depend on the local setup. The five Python tests cover timecode arithmetic, not screen recognition or end-to-end operation in Resolve. Contributions and reproducible bug reports are welcome. Ongoing maintenance and support are not guaranteed.

## License and independence

Project code is offered under the MIT License. See LICENSE, NOTICE.md and PRIVACY.md. This project is not affiliated with, endorsed by or supported by Blackmagic Design. DaVinci Resolve and associated product names belong to their respective owners.
