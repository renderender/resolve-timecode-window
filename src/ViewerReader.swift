import Cocoa
import ScreenCaptureKit
import Vision
import CoreGraphics

final class CropWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class Selection: NSView {
    var start = NSPoint.zero
    var region = NSRect.zero
    var onSelect: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() }
    }
    override func mouseDown(with event: NSEvent) {
        region = .zero
        start = convert(event.locationInWindow, from: nil)
    }
    override func mouseDragged(with event: NSEvent) {
        let end = convert(event.locationInWindow, from: nil)
        region = NSRect(x: min(start.x, end.x), y: min(start.y, end.y),
                        width: abs(end.x - start.x), height: abs(end.y - start.y))
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if region.width >= 30 && region.height >= 12 { onSelect?(region) }
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.23).setFill()
        bounds.fill()
        NSColor.systemYellow.setStroke()
        NSBezierPath(rect: region).stroke()
    }
}

final class ViewerReader {
    private struct Crop: Codable {
        let display: UInt32
        let rect: CGRect
        let size: CGSize
    }

    private var crops: [String: Crop] = [:]
    private var windows: [NSWindow] = []
    private var previewGeneration = UUID()
    private var task: Task<Void, Never>?
    private(set) var lastReadMilliseconds = 0.0
    var captureRate: Int {
        get { UserDefaults.standard.integer(forKey: "CaptureRate") }
        set { UserDefaults.standard.set(newValue, forKey: "CaptureRate") }
    }
    var onValues: ((String?, String?) -> Void)?

    init() {
        if let data = UserDefaults.standard.data(forKey: "ViewerCrops") {
            crops = (try? JSONDecoder().decode([String: Crop].self, from: data)) ?? [:]
        }
    }

    func pick(_ key: String) {
        finishSelection()
        if !CGPreflightScreenCaptureAccess() && !CGRequestScreenCaptureAccess() {
            let alert = NSAlert()
            alert.messageText = "Allow Screen Recording"
            alert.informativeText = "Allow Resolve Timecode Window under Privacy & Security → Screen & System Audio Recording, then restart the app."
            alert.runModal()
            return
        }
        stop()
        for screen in NSScreen.screens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let window = CropWindow(contentRect: screen.frame, styleMask: [.borderless],
                                    backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = Selection(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onCancel = { [weak self] in self?.finishSelection() }
            view.onSelect = { [weak self, weak view] rect in
                guard let self, let view else { return }
                self.crops[key] = Crop(display: id.uint32Value,
                    rect: CGRect(x: rect.minX, y: view.bounds.height - rect.maxY,
                                 width: rect.width, height: rect.height).integral,
                    size: screen.frame.size)
                UserDefaults.standard.set(try? JSONEncoder().encode(self.crops), forKey: "ViewerCrops")
                self.finishSelection()
            }
            window.contentView = view
            windows.append(window)
            window.orderFrontRegardless()
            window.makeKey()
            window.makeFirstResponder(view)
        }
    }

    func showAreas() {
        finishSelection()
        guard !crops.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No capture areas saved"
            alert.informativeText = "Set a Master TC or In-Out Duration capture area first."
            alert.runModal()
            return
        }
        for screen in NSScreen.screens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let matching = crops.filter { $0.value.display == id.uint32Value && $0.value.size == screen.frame.size }
            guard !matching.isEmpty else { continue }
            let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let root = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            for (key, crop) in matching {
                let rect = NSRect(x: crop.rect.minX, y: screen.frame.height - crop.rect.maxY,
                                  width: crop.rect.width, height: crop.rect.height)
                let border = NSView(frame: rect)
                border.wantsLayer = true
                border.layer?.borderWidth = 3
                border.layer?.borderColor = NSColor.systemYellow.cgColor
                root.addSubview(border)
                let title = NSTextField(labelWithString: key == "master" ? "Master TC" : "In-Out Duration")
                title.textColor = .black
                title.backgroundColor = .systemYellow
                title.drawsBackground = true
                title.sizeToFit()
                title.setFrameOrigin(NSPoint(x: rect.minX, y: max(0, rect.minY - title.frame.height)))
                root.addSubview(title)
            }
            window.contentView = root
            windows.append(window)
            window.orderFrontRegardless()
        }
        if windows.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Saved displays are unavailable"
            alert.informativeText = "Reconnect the saved display or select the capture areas again."
            alert.runModal()
            return
        }
        let generation = previewGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.previewGeneration == generation else { return }
            self.windows.forEach { $0.orderOut(nil) }
            self.windows.removeAll()
        }
    }

    func reset() {
        crops.removeAll()
        UserDefaults.standard.removeObject(forKey: "ViewerCrops")
        finishSelection()
    }

    private func finishSelection() {
        previewGeneration = UUID()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        start()
    }

    func stop() {
        task?.cancel()
        task = nil
        onValues?(nil, nil)
    }

    func start() {
        stop()
        guard !crops.isEmpty, CGPreflightScreenCaptureAccess() else { return }
        let saved = crops
        task = Task { @MainActor [weak self] in
            var previousSecond: Int?
            var previousSample = 0.0
            var boundary: Double?
            var settled = false
            var lastMaster: String?
            var lastMovement = 0.0
            var duration: String?
            while !Task.isCancelled {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    let filters = Dictionary(uniqueKeysWithValues: content.displays.map { display in
                        (display.displayID, SCContentFilter(display: display, excludingWindows: []))
                    })
                    let until = ProcessInfo.processInfo.systemUptime + 5
                    repeat {
                        let started = ProcessInfo.processInfo.systemUptime
                        let master = try await Self.read(saved["master"], filters, master: true)
                        try Task.checkCancellation()
                        self?.lastReadMilliseconds = (ProcessInfo.processInfo.systemUptime - started) * 1000
                        self?.onValues?(master, duration)
                        let second = master.flatMap { value -> Int? in
                            let parts = value.prefix(8).split(separator: ":").compactMap { Int($0) }
                            guard parts.count == 3 else { return nil }
                            return parts[0] * 3600 + parts[1] * 60 + parts[2]
                        }
                        if let master, master != lastMaster {
                            lastMovement = started
                        }
                        lastMaster = master
                        if let second, let previousSecond, second != previousSecond {
                            let candidate = (started + previousSample) / 2
                            if (second - previousSecond + 86400) % 86400 == 1
                                && started - previousSample < 0.65 {
                                settled = boundary.map { (0.72...1.28).contains(candidate - $0) } ?? false
                                boundary = candidate
                            } else {
                                boundary = nil
                                settled = false
                            }
                        } else if second == nil || started - lastMovement > 0.6
                                    || started - (boundary ?? started) > 1.25 {
                            boundary = nil
                            settled = false
                        }
                        previousSecond = second
                        previousSample = started

                        let age = started - (boundary ?? started)
                        duration = try await Self.read(saved["inout"], filters, master: false)
                        try Task.checkCancellation()
                        self?.onValues?(master, duration)
                        let idle = started - lastMovement > 0.6
                        let interval: Double
                        if idle || saved["master"] == nil {
                            interval = 0.5
                        } else if settled && age < 0.55 {
                            interval = 0.45
                        } else {
                            interval = 0.25
                        }
                        let rate = self?.captureRate ?? 0
                        let target = rate > 0 ? 1 / Double(rate) : interval
                        let remaining = max(0.01, target - (ProcessInfo.processInfo.systemUptime - started))
                        try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                    } while ProcessInfo.processInfo.systemUptime < until
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    boundary = nil
                    settled = false
                    lastMaster = nil
                    previousSecond = nil
                    duration = nil
                    self?.onValues?(nil, nil)
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
    }

    private static func read(_ crop: Crop?, _ filters: [UInt32: SCContentFilter],
                             master: Bool) async throws -> String? {
        guard let crop, let filter = filters[crop.display],
              filter.contentRect.size == crop.size else { return nil }
        let config = SCStreamConfiguration()
        config.sourceRect = crop.rect
        config.width = Int(crop.rect.width * max(2, CGFloat(filter.pointPixelScale)))
        config.height = Int(crop.rect.height * max(2, CGFloat(filter.pointPixelScale)))
        config.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil else { return nil as String? }
            let pattern = master ? #"^[0-9]{2}:[0-5][0-9]:[0-5][0-9][:.;][0-5][0-9][*.]?$"# :
                #"^[0-9]{2}:[0-5][0-9]:[0-5][0-9][:;][0-5][0-9]$"#
            let values = (request.results ?? []).compactMap { observation -> String? in
                guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.5 else { return nil }
                let value = candidate.string.filter { !$0.isWhitespace }
                return value.range(of: pattern, options: .regularExpression) == nil ? nil : value
            }
            return values.count == 1 ? values[0] : nil
        }.value
    }
}
