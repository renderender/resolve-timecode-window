import Cocoa
import Foundation

final class TimecodePanel: NSPanel {
    var optionsMenu: NSMenu?
    var openSettings: (() -> Void)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .rightMouseDown, let optionsMenu, let contentView {
            NSMenu.popUpContextMenu(optionsMenu, with: event, for: contentView)
            return
        }
        if event.type == .leftMouseDown && event.clickCount == 2 {
            openSettings?()
            return
        }
        super.sendEvent(event)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class ResizeGrip: NSView {
    private var initialFrame = NSRect.zero
    private var initialMouse = NSPoint.zero

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.secondaryLabelColor.setStroke()
        let path = NSBezierPath()
        for length in [CGFloat(4), 8, 12] {
            path.move(to: NSPoint(x: bounds.maxX - 3 - length, y: 3))
            path.line(to: NSPoint(x: bounds.maxX - 3, y: 3 + length))
        }
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        initialFrame = window?.frame ?? .zero
        initialMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window else { return }
        let mouse = NSEvent.mouseLocation
        let delta = (mouse.x - initialMouse.x + initialMouse.y - mouse.y) / 2
        let width = max(window.minSize.width, initialFrame.width + delta)
        let height = max(window.minSize.height, width / 1.6)
        window.setFrame(NSRect(x: initialFrame.minX, y: initialFrame.maxY - height,
                               width: width, height: height), display: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?
    private var ratePicker: NSPopUpButton?
    private var formatPicker: NSPopUpButton?
    private var panel: TimecodePanel!
    private var stack: NSStackView!
    private var labels: [NSTextField] = []
    private var timer: Timer?
    private var task: Process?
    private var output: FileHandle?
    private var generation = UUID()
    private var bridgeStarted = ProcessInfo.processInfo.systemUptime
    private var buffer = Data()
    private var lastUpdate: TimeInterval = 0
    private let viewer = ViewerReader()
    private var previousViewerTC: String?
    private var lastMotion: TimeInterval = 0
    private var motionSamples = 0
    private var playing = false
    private var viewerDurationValid = false
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = TimecodePanel(contentRect: NSRect(x: 160, y: 450, width: 320, height: 200), styleMask: [.titled, .closable, .nonactivatingPanel, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        panel.openSettings = { [weak self] in self?.showSettings() }
        panel.title = "Timecode"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor(calibratedWhite: 0.045, alpha: 0.98)
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.minSize = NSSize(width: 176, height: 110)
        panel.aspectRatio = NSSize(width: 1.6, height: 1)
        panel.isReleasedWhenClosed = false
        let root = NSView(frame: panel.contentView!.bounds)
        root.wantsLayer = true
        panel.contentView = root
        stack = NSStackView()
        stack.orientation = .vertical
        stack.distribution = .fillEqually
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 25),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12)
        ])
        for title in ["Master TC", "In-Out Duration", "Total Duration"] {
            let label = NSTextField(labelWithString: "--:--:--:--\u{00A0}")
            label.setAccessibilityLabel(title)
            label.toolTip = title
            label.textColor = NSColor(calibratedRed: 0.54, green: 0.97, blue: 0.33, alpha: 1)
            label.alignment = .center
            label.lineBreakMode = .byClipping
            label.maximumNumberOfLines = 1
            label.font = NSFont.monospacedDigitSystemFont(ofSize: 38, weight: .medium)
            let row = NSView()
            stack.addArrangedSubview(row)
            label.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(label)
            NSLayoutConstraint.activate([
                row.widthAnchor.constraint(equalTo: stack.widthAnchor),
                label.centerXAnchor.constraint(equalTo: row.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                label.widthAnchor.constraint(equalTo: row.widthAnchor)
            ])
            labels.append(label)
        }
        let grip = ResizeGrip()
        grip.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(grip)
        NSLayoutConstraint.activate([
            grip.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            grip.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            grip.widthAnchor.constraint(equalToConstant: 19),
            grip.heightAnchor.constraint(equalToConstant: 19)
        ])
        restoreWindowPlacement()
        showPanel()
        panel.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(resizeFonts), name: NSWindow.didResizeNotification, object: panel)
        resizeFonts()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "TC"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "About / Capture Info…", action: #selector(showInfo), keyEquivalent: ""))
        let sampling = NSMenuItem(title: "Capture Rate", action: nil, keyEquivalent: "")
        let rates = NSMenu()
        for (rate, title) in [(0, "Automatic (low load)"), (2, "2 reads / second"),
                              (4, "4 reads / second"), (8, "8 reads / second")] {
            let item = NSMenuItem(title: title, action: #selector(setCaptureRate(_:)), keyEquivalent: "")
            item.tag = rate
            item.target = self
            item.state = viewer.captureRate == rate ? .on : .off
            rates.addItem(item)
        }
        sampling.submenu = rates
        menu.addItem(sampling)
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(showPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Restart Resolve Connection", action: #selector(restartBridge), keyEquivalent: ""))
        let format = NSMenuItem(title: "Timecode Format", action: nil, keyEquivalent: "")
        let formats = NSMenu()
        for (index, title) in ["Automatic", "50i with Field Indicator", "Progressive"].enumerated() {
            let item = NSMenuItem(title: title, action: #selector(setDisplayMode(_:)), keyEquivalent: "")
            item.tag = index
            item.target = self
            item.state = index == UserDefaults.standard.integer(forKey: "DisplayMode") ? .on : .off
            formats.addItem(item)
        }
        format.submenu = formats
        menu.addItem(format)
        menu.items.forEach { $0.target = self }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        menu.items.last?.target = self
        for (title, action) in [
            ("Set Master TC Capture Area…", #selector(pickMaster)),
            ("Set In-Out Duration Capture Area…", #selector(pickDuration)),
            ("Show Saved Capture Areas", #selector(showAreas)),
                ("Reset Capture Areas", #selector(resetViewer))
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.insertItem(item, at: max(0, menu.items.count - 2))
        }
        panel.optionsMenu = menu.copy() as? NSMenu
        statusItem.menu = menu
        viewer.onValues = { [weak self] master, duration in self?.readViewer(master, duration) }
        viewer.start()
        restartBridge()
        let watchdog = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = ProcessInfo.processInfo.systemUptime
            if now - self.lastUpdate > 3 { self.setDurationStale(true) }
            if self.task?.isRunning != true || now - max(self.lastUpdate, self.bridgeStarted) > 10 {
                self.restartBridge()
            }
        }
        timer = watchdog
        RunLoop.main.add(watchdog, forMode: .common)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewer.stop()
        timer?.invalidate()
        stopBridge()
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 440),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Resolve Timecode Window — Settings"
            window.isReleasedWhenClosed = false
            window.level = .screenSaver
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 12
            stack.translatesAutoresizingMaskIntoConstraints = false
            window.contentView!.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 22),
                stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -22),
                stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 22)
            ])
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
            stack.addArrangedSubview(NSTextField(labelWithString: "Version " + version))
            let rate = NSPopUpButton()
            for (value, title) in [(0, "Automatic (low load)"), (2, "2 reads / second"),
                                   (4, "4 reads / second"), (8, "8 reads / second")] {
                rate.addItem(withTitle: title)
                rate.lastItem?.tag = value
            }
            rate.target = self
            rate.action = #selector(changeSettingsRate(_:))
            ratePicker = rate
            let rateRow = NSStackView(views: [NSTextField(labelWithString: "Capture rate"), rate])
            rateRow.spacing = 16
            stack.addArrangedSubview(rateRow)
            let format = NSPopUpButton()
            format.addItems(withTitles: ["Automatic", "50i with Field Indicator", "Progressive"])
            format.target = self
            format.action = #selector(changeSettingsFormat(_:))
            formatPicker = format
            let formatRow = NSStackView(views: [NSTextField(labelWithString: "Timecode format"), format])
            formatRow.spacing = 16
            stack.addArrangedSubview(formatRow)
            for (title, action) in [
                ("Set Master TC Capture Area…", #selector(settingsMaster)),
                ("Set In-Out Duration Capture Area…", #selector(settingsDuration)),
                ("Show Saved Capture Areas", #selector(showAreas)),
                ("Reset Capture Areas", #selector(resetViewer)),
                ("Restart Resolve Connection", #selector(restartBridge)),
                ("Capture Info…", #selector(showInfo))
            ] {
                stack.addArrangedSubview(NSButton(title: title, target: self, action: action))
            }
            let note = NSTextField(wrappingLabelWithString: "Changes are saved automatically. Higher capture rates increase load. Playback timecode is approximate.")
            note.textColor = .secondaryLabelColor
            note.preferredMaxLayoutWidth = 410
            stack.addArrangedSubview(note)
            window.center()
            settingsWindow = window
        }
        ratePicker?.selectItem(withTag: viewer.captureRate)
        formatPicker?.selectItem(at: min(2, max(0, UserDefaults.standard.integer(forKey: "DisplayMode"))))
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func changeSettingsRate(_ sender: NSPopUpButton) {
        guard let selected = sender.selectedItem else { return }
        setCaptureRate(selected)
    }

    @objc private func changeSettingsFormat(_ sender: NSPopUpButton) {
        let item = NSMenuItem()
        item.tag = sender.indexOfSelectedItem
        setDisplayMode(item)
    }

    @objc private func showAreas() {
        settingsWindow?.orderOut(nil)
        viewer.showAreas()
    }

    @objc private func settingsMaster() {
        settingsWindow?.orderOut(nil)
        pickMaster()
    }

    @objc private func settingsDuration() {
        settingsWindow?.orderOut(nil)
        pickDuration()
    }

    @objc private func setCaptureRate(_ sender: NSMenuItem) {
        viewer.captureRate = sender.tag
        for root in [statusItem.menu, panel.optionsMenu].compactMap({ $0 }) {
            let rates = root.items.first { $0.title == "Capture Rate" }?.submenu
            rates?.items.forEach { $0.state = $0.tag == sender.tag ? .on : .off }
        }
    }

    @objc private func showInfo() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let rate = viewer.captureRate
        let mode = rate == 0 ? "Automatic (low load)" : "\(rate) reads / second"
        let alert = NSAlert()
        alert.messageText = "Resolve Timecode Window \(version)"
        alert.informativeText = """
        Build \(build)
        Capture rate: \(mode)
        Last Master TC capture + OCR: \(Int(viewer.lastReadMilliseconds)) ms

        Rates are targets. Capture and text recognition may take longer.
        Higher rates increase system load. Playback readout is approximate.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func pickMaster() { viewer.pick("master") }
    @objc private func pickDuration() { viewer.pick("inout") }
    @objc private func resetViewer() {
        playing = false
        viewer.reset()
    }

    private func setDurationStale(_ stale: Bool) {
        labels[1].textColor = stale && !viewerDurationValid ? .systemOrange : labels[0].textColor
        labels[2].textColor = stale ? .systemOrange : labels[0].textColor
    }

    private func display(_ index: Int, _ value: String) {
        let text = value.hasSuffix("*") ? value : value + "\u{00A0}"
        if labels[index].stringValue != text { labels[index].stringValue = text }
    }

    private func readViewer(_ master: String?, _ duration: String?) {
        let now = ProcessInfo.processInfo.systemUptime
        if let master {
            if let previousViewerTC, master != previousViewerTC {
                motionSamples = now - lastMotion < 0.8 ? motionSamples + 1 : 1
                lastMotion = now
                if motionSamples >= 2 {
                    playing = true
                    setDurationStale(true)
                }
            } else if playing && now - lastMotion > 0.75 {
                playing = false
                motionSamples = 0
            }
            previousViewerTC = master
            if playing { display(0, String(master.prefix(8)) + ":--") }
        } else {
            previousViewerTC = nil
            motionSamples = 0
        }
        viewerDurationValid = duration != nil
        if let duration {
            display(1, duration)
            labels[1].textColor = labels[0].textColor
        } else if playing {
            labels[1].textColor = .systemOrange
        }
    }

    private func stopBridge() {
        generation = UUID()
        output?.readabilityHandler = nil
        output = nil
        if task?.isRunning == true { task?.terminate() }
        task = nil
        buffer.removeAll()
    }
    @objc private func setDisplayMode(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: "DisplayMode")
        for root in [statusItem.menu, panel.optionsMenu].compactMap({ $0 }) {
            root.items.first { $0.title == "Timecode Format" }?.submenu?.items.forEach {
                $0.state = $0.tag == sender.tag ? .on : .off
            }
        }
        restartBridge()
    }

    @objc private func resizeFonts() {
        let w = panel.contentView!.bounds.width - 20
        let h = max(1, (panel.contentView!.bounds.height - 41) / 3)
        let reference = NSFont.monospacedSystemFont(ofSize: 100, weight: .medium)
        let width = ("00:00:00:00*" as NSString).size(withAttributes: [.font: reference]).width
        let size = max(8, min(h * 0.84, 100 * (w - 6) / width))
        for label in labels { label.font = NSFont.monospacedSystemFont(ofSize: size, weight: .medium) }
    }
    private func displayIdentifier(_ screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value) else { return nil }
        return CFUUIDCreateString(nil, uuid.takeRetainedValue()) as String
    }

    fileprivate func saveWindowPlacement() {
        guard let screen = panel.screen, let identifier = displayIdentifier(screen) else { return }
        let area = screen.visibleFrame
        let frame = panel.frame
        UserDefaults.standard.set([
            "display": identifier,
            "frame": NSStringFromRect(frame),
            "right": area.maxX - frame.maxX,
            "bottom": frame.minY - area.minY
        ], forKey: "TimecodeWindowPlacement")
    }

    private func restoreWindowPlacement() {
        let defaults = UserDefaults.standard
        guard let saved = defaults.dictionary(forKey: "TimecodeWindowPlacement"),
              let identifier = saved["display"] as? String,
              let storedFrame = saved["frame"] as? String,
              let right = saved["right"] as? Double, let bottom = saved["bottom"] as? Double else {
            panel.setFrameUsingName("ResolveTimecodePanelV12")
            return
        }
        let screen = NSScreen.screens.first { displayIdentifier($0) == identifier } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        var frame = NSRectFromString(storedFrame)
        frame.size.width = min(frame.width, area.width)
        frame.size.height = min(frame.height, area.height)
        frame.origin.x = min(max(area.maxX - frame.width - right, area.minX), area.maxX - frame.width)
        frame.origin.y = min(max(area.minY + bottom, area.minY), area.maxY - frame.height)
        panel.setFrame(frame, display: false)
    }

    @objc private func showPanel() { panel.orderFrontRegardless() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func restartBridge() {
        stopBridge()
        setDurationStale(true)
        lastUpdate = 0
        bridgeStarted = ProcessInfo.processInfo.systemUptime
        let currentGeneration = generation
        let script = Bundle.main.resourceURL!.appendingPathComponent("bridge.py").path
        let pythonCandidates = ["/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Applications/ResolvePython", "/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]
        guard let executable = pythonCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        var environment = ProcessInfo.processInfo.environment
        let mode = UserDefaults.standard.integer(forKey: "DisplayMode")
        environment["TIMECODE_DISPLAY_MODE"] = ["auto", "50i", "progressive"][min(2, max(0, mode))]
        p.environment = environment
        p.arguments = ["-u", script]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.standardError
        let reader = pipe.fileHandleForReading
        output = reader
        reader.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            DispatchQueue.main.async {
                guard let self = self, self.generation == currentGeneration else { return }
                self.buffer.append(data)
                while let index = self.buffer.firstIndex(of: 10) {
                    let line = Data(self.buffer.prefix(upTo: index))
                    self.buffer.removeSubrange(...index)
                    if let json = try? JSONSerialization.jsonObject(with: line) as? [String: String] {
                        let blank = "--:--:--:--"
                        let master = json["master"] ?? blank
                        if !self.playing && master != blank {
                            self.display(0, master)
                            if !self.viewerDurationValid { self.display(1, json["inout"] ?? blank) }
                            self.display(2, json["total"] ?? blank)
                            self.setDurationStale(false)
                        }
                        self.lastUpdate = ProcessInfo.processInfo.systemUptime
                    }
                }
            }
        }
        do {
            try p.run()
            task = p
        } catch {
            stopBridge()
            NSLog("Could not start the Python bridge: %@", String(describing: error))
        }
    }
}
extension AppDelegate: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) { saveWindowPlacement() }
    func windowDidResize(_ notification: Notification) { saveWindowPlacement() }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}
@main
enum TimecodeWindow {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
