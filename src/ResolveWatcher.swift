import AppKit
import MachO

func recordLaunchStatus(_ message: String) {
    let defaults = UserDefaults(suiteName: "local.resolve.timecodewindow")
    defaults?.set(message, forKey: "LastHelperLaunch")
    defaults?.synchronize()
}

final class Watcher: NSObject, NSApplicationDelegate {
    private var timer: Timer?
    private var previousPID: pid_t?
    private var launchedPID: pid_t?
    private var opening = false
    private let resolveID = "com.blackmagic-design.DaVinciResolve"

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkResolve()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.checkResolve() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func checkResolve() {
        let pid = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == resolveID }?.processIdentifier
        if pid != previousPID { launchedPID = nil; previousPID = pid }
        guard let pid, launchedPID != pid, !opening else { return }
        opening = true
        var length: UInt32 = 0
        _NSGetExecutablePath(nil, &length)
        var bytes = [CChar](repeating: 0, count: Int(length))
        guard _NSGetExecutablePath(&bytes, &length) == 0 else {
            opening = false
            return
        }
        var appURL = URL(fileURLWithPath: String(cString: bytes)).resolvingSymlinksInPath()
        while appURL.path != "/" {
            if let bundle = Bundle(url: appURL),
               bundle.bundleIdentifier == "local.resolve.timecodewindow" { break }
            appURL.deleteLastPathComponent()
        }
        guard appURL.path != "/", Bundle(url: appURL)?.bundleIdentifier == "local.resolve.timecodewindow" else {
            opening = false
            recordLaunchStatus("Could not locate the main app bundle.")
            return
        }
        let alreadyRunning = NSWorkspace.shared.runningApplications.contains {
            $0.executableURL?.lastPathComponent == "ResolveTimecodeWindow"
        }
        if alreadyRunning {
            opening = false
            launchedPID = pid
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                self?.opening = false
                if let error {
                    recordLaunchStatus("Launch failed: " + error.localizedDescription)
                } else {
                    self?.launchedPID = pid
                    recordLaunchStatus("Opened main app through Launch Services.")
                }
            }
        }
    }
}
let app = NSApplication.shared
let delegate = Watcher()
app.setActivationPolicy(.prohibited)
app.delegate = delegate
app.run()
withExtendedLifetime(delegate) {}
