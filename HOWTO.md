# Resolve Timecode Window 2.0

A floating display for Master TC, In-Out Duration and Total Duration.
Requires macOS 14 or later and DaVinci Resolve 21 Studio.
Universal app for Apple silicon and Intel.

## Install or update

1. Download the **Resolve-Timecode-Window-2.0-Setup.zip** asset from the
   GitHub release page and extract it.
2. Open **Install Resolve Timecode Window.app** and click **Install**.
   Setup closes the existing TC app and its launcher, installs the new
   app in /Applications, and preserves saved settings and capture areas.
   macOS may ask for administrator credentials. Resolve can stay open.
3. **Refresh Screen Recording permission** is selected by default.
   Keep it selected if updating from an ad-hoc signed build with stale
   authorization. This resets permission for this utility only.
4. After installation the TC app opens. If prompted, choose **Open System
   Settings**, allow **Resolve Timecode Window** under Privacy & Security →
   Screen & System Audio Recording, then quit and reopen the TC app.
   macOS wording varies. If a stale entry remains, remove it and add the
   installed app from Applications manually.

The installer and app are ad-hoc signed and not Apple-notarized. macOS
may block their first launch. Privacy & Security may offer Open Anyway
after a launch attempt. Only approve software you trust. The installer
cannot grant macOS permissions on your behalf.

## Connect to Resolve and choose areas

1. In Resolve Studio, open Preferences → System → General and set
   External scripting using to Local. Save and restart Resolve if asked.
2. Open a timeline on the Edit page.
3. Double-click the TC window to open Settings.
4. Choose **Set Master TC Capture Area…** and drag a rectangle around
   just the timeline timecode digits above the timeline viewer.
5. Choose **Set In-Out Duration Capture Area…** and select only the
   number next to DURATION in the viewer's IN/OUT bar.
6. Use **Show Saved Capture Areas** to display labeled yellow outlines
   for four seconds. Esc cancels a new selection.

Areas persist across app restarts. Re-select them if you move the viewer,
change the display arrangement or change the Resolve layout. The selected
digits must remain visible and unobscured.

## Readouts and colors

The rows are Master TC, In-Out Duration and Total Duration, from top to bottom.

During detected playback the app reads the selected viewer regions using
local text recognition. Master TC shows HH:MM:SS:--. It can lag and is
not frame-accurate. Frame digits return when playback stops and the
Resolve API provides a value. Scrubbing can also trigger playback detection.

In-Out Duration stays green when a valid value is read from its capture
region. Total Duration comes from the API and holds its last value in
orange during detected playback. Orange can also mean a fresh API response
is unavailable. Green returns after a valid update.

Capture Rate offers Automatic (low load), 2, 4 or 8 reads per second.
Higher rates increase load. Rates are targets and depend on capture and
recognition time. Capture Info shows version and recent recognition time;
that timing is not an end-to-end latency measurement.

For 50i, use Timecode Format → 50i with Field Indicator if automatic
detection needs help. API-derived Master TC can mark the second field
with a star. Durations use whole frames.

## Start and quit with Resolve

Keep one copy in Applications. In Settings, enable **Launch and quit with
DaVinci Resolve**. Approve the helper under General → Login Items &
Extensions if macOS asks. The launcher checks for Resolve every two seconds.
The Project Manager is sufficient; no project needs to be open.

Resolve starting opens the TC app. Resolve quitting closes it. Manually
closing the TC window keeps it closed until the next Resolve launch.
Disable this option before uninstalling the app.

The launcher is named ResolveWatcher / Resolve Timecode Launcher. It has
no screen or audio capture code. The main TC app needs Screen Recording
for OCR. Early development builds could attribute capture requests to the
launcher. If a new request still names ResolveWatcher, decline it and
report the version. Disable any old Screen Recording grant for the helper.

## Window and privacy

Drag the window to position it. Resize with the lower-right grip. Monitor,
window placement and settings persist. Settings remains above other
windows and hides when selecting or previewing capture areas.
Closing Settings leaves the app running. Closing the TC window quits it.

The app processes images locally, saves no screenshots and records no
system audio. macOS may mention audio in its standard permission dialog.
Data Burn-In is not needed. See PRIVACY.md and NOTICE.md.

## Validation and limits

Universal builds, signatures, archive integrity and five arithmetic tests
are checked. The installer and automatic-launch flow received iterative
user feedback; full end-to-end behavior across macOS versions has not
been systematically verified. Permission retention across updates is
not guaranteed. This community utility is provided under the MIT License.
