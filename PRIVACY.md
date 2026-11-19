# Privacy

The app requests macOS Screen Recording access to read two screen regions selected by the user. Apple ScreenCaptureKit captures those regions and Apple Vision processes the images locally. The app does not save screenshots, upload captured images, include analytics, or include an update service.

Capture coordinates, display identifiers, window placement and format preferences are stored in macOS UserDefaults. A separate Python process communicates locally with the installed DaVinci Resolve scripting interface and sends timecode values to the app.

Screen Recording permission is broader than a single region. Select only the intended timecode digits and review the source if needed. Revoke permission in macOS Privacy & Security when no longer wanted.

Public GitHub issues and contributions are handled by GitHub under its own terms. Remove personal details, project names and confidential footage before posting diagnostics or screenshots.
