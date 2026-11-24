# Privacy

The app requests macOS Screen Recording access to read two screen regions selected by the user. Apple ScreenCaptureKit captures those regions and Apple Vision processes the images locally. The app does not save screenshots, upload captured images, include analytics, or include an update service.

Capture coordinates, display identifiers, window placement and format preferences are stored in macOS UserDefaults. A separate Python process communicates locally with the installed DaVinci Resolve scripting interface and sends timecode values to the app.

Screen Recording permission is broader than a single region. Select only the intended timecode digits and review the source if needed. Revoke permission in macOS Privacy & Security when no longer wanted.

Public GitHub issues and contributions are handled by GitHub under its own terms. Remove personal details, project names and confidential footage before posting diagnostics or screenshots.

When Launch and quit with Resolve is enabled, a login agent inside the
app checks the local running-application list every two seconds. It uses Resolve's
bundle identifier to launch the TC app. The helper does not use screen
recording or transmit data. Registration is managed by macOS
ServiceManagement. Disable the option to unregister it.

Setup may close the TC app and launcher and reset Screen Recording
authorization for local.resolve.timecodewindow if the user selects that
option. It preserves app preferences and opens the installed app.
No credentials are collected by the installer; administrator authorization,
if needed, uses the macOS system prompt. Diagnostic launch status is
stored locally in UserDefaults and may include the installed app path.
