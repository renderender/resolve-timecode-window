import Cocoa

final class Installer: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var title: NSTextField!
    private var subtitle: NSTextField!
    private var install: NSButton!
    private var reset: NSButton!
    private var progress: NSProgressIndicator!
    private var details: NSButton!
    private var errorText = ""
    private var busy = false
    private var complete = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Resolve Timecode Window Setup"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        let root = window.contentView!
        let image = NSImageView(frame: NSRect(x: 184, y: 284, width: 112, height: 112))
        image.image = NSImage(contentsOf: Bundle.main.resourceURL!.appendingPathComponent("SetupIcon.png"))
        image.imageScaling = .scaleProportionallyUpOrDown
        root.addSubview(image)
        title = label("Your timecodes. One window.", size: 24, weight: .semibold, y: 236, height: 34)
        subtitle = label("Install or update Resolve Timecode Window.", size: 14, weight: .regular, y: 198, height: 40)
        subtitle.textColor = .secondaryLabelColor
        reset = NSButton(checkboxWithTitle: "Refresh Screen Recording permission", target: nil, action: nil)
        reset.frame = NSRect(x: 79, y: 158, width: 330, height: 24)
        reset.state = .on
        root.addSubview(reset)
        install = NSButton(title: "Install", target: self, action: #selector(start))
        install.bezelStyle = .rounded
        install.controlSize = .large
        install.keyEquivalent = "\r"
        install.frame = NSRect(x: 150, y: 91, width: 180, height: 44)
        root.addSubview(install)
        progress = NSProgressIndicator(frame: NSRect(x: 80, y: 144, width: 320, height: 8))
        progress.style = .bar
        progress.isIndeterminate = true
        progress.isHidden = true
        root.addSubview(progress)
        details = NSButton(title: "Show details", target: self, action: #selector(showDetails))
        details.bezelStyle = .inline
        details.frame = NSRect(x: 170, y: 55, width: 140, height: 25)
        details.isHidden = true
        root.addSubview(details)
        let footer = label("App 2.0  ·  macOS 14+", size: 11, weight: .regular, y: 24, height: 20)
        footer.textColor = .tertiaryLabelColor
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight,
                       y: CGFloat, height: CGFloat) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.alignment = .center
        field.frame = NSRect(x: 24, y: y, width: 432, height: height)
        window.contentView!.addSubview(field)
        return field
    }

    @objc private func start() {
        if complete { NSApp.terminate(nil); return }
        guard !busy else { return }
        busy = true
        let refresh = reset.state == .on
        reset.isHidden = true
        details.isHidden = true
        install.isEnabled = false
        window.standardWindowButton(.closeButton)?.isEnabled = false
        title.stringValue = "Installing…"
        subtitle.stringValue = "Your saved areas and settings stay with you."
        progress.isHidden = false
        progress.startAnimation(nil)
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [Bundle.main.resourceURL!.appendingPathComponent("install.sh").path]
                + (refresh ? ["--reset-screen-permission"] : [])
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            var failure: String?
            do {
                try process.run()
                let output = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    failure = String(data: output, encoding: .utf8) ?? "Installation failed."
                }
            } catch { failure = error.localizedDescription }
            DispatchQueue.main.async {
                self.busy = false
                self.progress.stopAnimation(nil)
                self.progress.isHidden = true
                self.install.isEnabled = true
                self.window.standardWindowButton(.closeButton)?.isEnabled = true
                NSApp.activate(ignoringOtherApps: true)
                self.window.makeKeyAndOrderFront(nil)
                if let failure {
                    self.errorText = failure
                    self.title.stringValue = "One more step needed"
                    self.subtitle.stringValue = "Installation could not finish. Check the details and try again."
                    self.details.isHidden = false
                    self.install.title = "Try Again"
                    self.reset.isHidden = false
                } else {
                    self.complete = true
                    self.title.stringValue = "✓  Ready to go"
                    self.title.textColor = .systemGreen
                    self.subtitle.stringValue = "The app is installed. Follow any permission prompt, then reopen it."
                    self.install.title = "Done"
                }
            }
        }
    }

    @objc private func showDetails() {
        let alert = NSAlert()
        alert.messageText = "Installation details"
        alert.informativeText = errorText
        alert.runModal()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        busy ? .terminateCancel : .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let app = NSApplication.shared
let installer = Installer()
app.setActivationPolicy(.regular)
app.delegate = installer
app.run()
withExtendedLifetime(installer) {}
