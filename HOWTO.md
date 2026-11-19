# Resolve Timecode Window 1.6.13

A floating macOS display for **Master TC**, **In-Out Duration**, and **Total Duration**, in that order.

## Install and set up

1. Unzip the download and drag **Resolve Timecode Window.app** into Applications. If you have an older copy running, quit it first. This build requires macOS 14 or later and supports Apple silicon and Intel. It was developed for DaVinci Resolve 21 Studio.
2. In Resolve Studio, go to **Preferences → System → General**. Set **External scripting using** to **Local**, save, and restart Resolve if prompted. Open a timeline on the Edit page, then open the app.
3. Right-click the floating window and choose **Set Master TC Capture Area…**. If prompted, allow **Screen & System Audio Recording** in **System Settings → Privacy & Security** and relaunch the app. Select just the timeline timecode digits above the timeline viewer. In a dual-viewer layout, use the timeline viewer on the right.
4. Optionally choose **Set In-Out Duration Capture Area…** and mark just the number next to **DURATION** in the viewer’s IN/OUT bar. Leave the word DURATION outside the rectangle.
5. Drag the floating window where you want it. Use the grip in the lower-right corner to resize it. The app remembers its position and capture areas. If your Resolve layout changes, mark the areas again. Keep the selected digits visible and clear of other windows.

The app is locally signed and has not been notarized by Apple. If macOS blocks the first launch, **Privacy & Security** may offer **Open Anyway** after that attempt. Use it if you trust the download.

## What the display means

- **Master TC** reads the visible viewer digits during detected playback. The app shows hours, minutes and seconds with frames replaced by dashes, for example `01:04:12:--`. Screen capture and local text recognition introduce a delay, so the playback display is approximate and may lag. In the stopped state, frame digits return when Resolve's scripting API responds.
- **In-Out Duration** can stay green during playback when the app successfully reads the marked DURATION field. It can also use Resolve's scripting API when stopped.
- **Total Duration** comes from Resolve's scripting API. During detected playback it holds the last available value in orange. A duration can also turn orange if a fresh API response is unavailable. Green returns when the app gets a fresh value from the applicable source.
- For interlaced projects, use **Timecode Format → 50i with Field Indicator** if automatic detection needs help. The star denotes the second field on the API-derived Master TC. Durations are shown in whole frames.

The app processes the marked regions locally and saves no screenshots. There is no need to enable Data Burn-In. Click the red close button to quit.

## Version and capture rate (1.6.13)

Right-click the floating window and select About / Capture Info to see the
version, build, configured capture rate and duration of the last Master TC
capture and OCR pass. This timing is not a measurement of end-to-end latency.

Capture Rate offers Automatic (low load), 2, 4 or 8 reads per second.
The selection is saved. Higher rates increase load. They are targets;
capture and OCR may take longer. Try 4 reads per second before 8.

In 1.6.13 the selected In-Out Duration region is read on every capture
cycle and a new result is displayed immediately after recognition.
Capture Rate now controls both viewer readings. More frequent duration
recognition increases load. The old 1.5-second delay has been removed.

Double-click the floating timecode window to open Settings.
Settings is also available in the right-click menu. Changes are saved
automatically. Selecting a capture area hides Settings for selection.
Closing Settings leaves the timecode app running. Closing the main
timecode window quits the app.

Show Saved Capture Areas outlines the saved regions in yellow for four
seconds. The preview allows clicks through to Resolve. The Settings
window hides while the preview is visible.
This ad-hoc signed build may require Screen Recording permission again
after an update. A consistent Developer ID signing identity is needed
for a reliable distribution identity across future releases.
