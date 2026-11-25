# Resolve Timecode Window

An independent macOS utility showing **Master TC**, **In-Out Duration**
and **Total Duration** in one resizable floating window.

**Version 2.0.2** includes a graphical setup assistant, saved capture areas,
window placement, capture-rate settings, a new icon, and optional automatic
launch and quit with DaVinci Resolve.

[Download the 2.0.2 setup](https://github.com/renderender/resolve-timecode-window/releases/tag/v2.0.2)
and follow the [installation guide](HOWTO.md).

Requires macOS 14 or later. Developed for DaVinci Resolve 21 Studio.
Supports Apple silicon and Intel. Playback uses local OCR of selected
viewer regions, can lag, and is not frame-accurate. Orange duration values
are held pending fresh data. Screen Recording permission is required.

## Build from source

Install Apple Command Line Tools and Python 3, then run:

```sh
./build.sh
./build-setup.sh
python3 -B src/Bridge-Pruefung.py
```

The builds are ad-hoc signed and not Apple-notarized. Setup cannot grant
macOS permissions automatically.

## Status and license

Developed with AI assistance for a personal editing workflow. Contributions
and reproducible bug reports are welcome. Maintenance and support are not
guaranteed. Five tests cover timecode arithmetic; screen recognition,
installation and automatic launch depend on the local system.

MIT License. See LICENSE, NOTICE.md and PRIVACY.md. This project is not
affiliated with, endorsed by or supported by Blackmagic Design or Apple.
Product names belong to their respective owners.
