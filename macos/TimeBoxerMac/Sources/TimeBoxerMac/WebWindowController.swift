@preconcurrency import AppKit
@preconcurrency import WebKit

@MainActor
final class WebWindowController: NSWindowController, WKScriptMessageHandler, WKNavigationDelegate, NSWindowDelegate {
    enum ViewMode: String {
        case child
    }

    var onBridgeMessage: ((String, [String: Any]) -> Void)?

    private let webView: WKWebView
    private var requestedMode: ViewMode = .child
    private var hasStartedLoading = false
    private var isPageReady = false
    private var pendingEvents: [(type: String, payload: [String: Any])] = []
    private var focusProtection = FocusProtectionSessionState()
    private let focusAlarmPlayer = FocusAlarmPlayer()
    private var focusProtectionArmedAt = Date.distantFuture
    private var focusMonitorTimer: Timer?
    private var focusRestoreScheduled = false
    private var isFullscreenTransitionInProgress = false
    private var isSystemSuspended = false

    init() {
        let contentController = WKUserContentController()
        contentController.addUserScript(WKUserScript(
            source: "window.__TIMEBOXER_MAC__ = true;",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        webView = WKWebView(frame: .zero, configuration: configuration)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TimeBoxer"
        window.minSize = NSSize(width: 820, height: 620)
        window.center()
        window.contentView = webView

        super.init(window: window)
        window.delegate = self
        webView.navigationDelegate = self
        contentController.add(self, name: "timeboxer")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: NSApp
        )
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self,
            selector: #selector(systemWillSuspend),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(systemWillSuspend),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(systemWillSuspend),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(systemDidResume),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(systemDidResume),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(systemDidResume),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(_ mode: ViewMode) {
        requestedMode = mode
        if !hasStartedLoading {
            load(mode)
        } else if isPageReady {
            deliverNativeEvent(type: "view-mode", payload: ["view": mode.rawValue])
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func sendNativeEvent(type: String, payload: [String: Any]) {
        guard isPageReady else {
            pendingEvents.append((type, payload))
            return
        }
        deliverNativeEvent(type: type, payload: payload)
    }

    func setFocusFullscreen(_ enabled: Bool) {
        guard let window else { return }
        if enabled {
            focusProtection.enable()
            focusProtectionArmedAt = Date().addingTimeInterval(1.8)
            isSystemSuspended = false
            focusAlarmPlayer.stop()
            startFocusMonitor()
        } else {
            disableFocusProtection()
        }

        let isFullscreen = window.styleMask.contains(.fullScreen)
        guard enabled != isFullscreen else {
            if enabled {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            return
        }
        isFullscreenTransitionInProgress = true
        window.toggleFullScreen(nil)
    }

    func acknowledgeFocusReturn() {
        guard focusProtection.isEnabled else { return }
        guard
            NSApp.isActive,
            window?.styleMask.contains(.fullScreen) == true
        else {
            handleFocusViolation(reason: .focusNotRestored)
            return
        }
        if focusProtection.acknowledgeReturn() {
            focusAlarmPlayer.stop()
        }
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        isFullscreenTransitionInProgress = false
        if focusProtection.isEnabled {
            focusProtectionArmedAt = Date()
        }
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        isFullscreenTransitionInProgress = false
        handleFocusViolation(reason: .leftFullscreen)
    }

    @objc private func applicationDidResignActive(_ notification: Notification) {
        guard !isSystemSuspended else { return }
        handleFocusViolation(reason: .applicationSwitch)
    }

    @objc private func checkFocusProtection() {
        guard
            focusProtection.isEnabled,
            !isSystemSuspended,
            !isFullscreenTransitionInProgress,
            Date() >= focusProtectionArmedAt
        else { return }
        guard
            NSApp.isActive,
            window?.styleMask.contains(.fullScreen) == true
        else {
            handleFocusViolation(reason: .focusCheck)
            return
        }
    }

    @objc private func systemWillSuspend(_ notification: Notification) {
        guard focusProtection.isEnabled else { return }
        isSystemSuspended = true
        let shouldNotifyWeb = focusProtection.recordViolation()
        focusAlarmPlayer.stop()
        if shouldNotifyWeb {
            sendNativeEvent(
                type: "focus-suspended",
                payload: ["reason": FocusInterruptionReason.systemSuspension.rawValue]
            )
        }
    }

    @objc private func systemDidResume(_ notification: Notification) {
        guard focusProtection.isEnabled else {
            isSystemSuspended = false
            return
        }
        isSystemSuspended = false
        restoreProtectedWindow()
    }

    private func startFocusMonitor() {
        guard focusMonitorTimer == nil else { return }
        focusMonitorTimer = Timer.scheduledTimer(
            timeInterval: 0.25,
            target: self,
            selector: #selector(checkFocusProtection),
            userInfo: nil,
            repeats: true
        )
    }

    private func disableFocusProtection() {
        focusProtection.disable()
        focusProtectionArmedAt = .distantFuture
        focusAlarmPlayer.stop()
        focusMonitorTimer?.invalidate()
        focusMonitorTimer = nil
        focusRestoreScheduled = false
        isFullscreenTransitionInProgress = false
        isSystemSuspended = false
    }

    private func handleFocusViolation(reason: FocusInterruptionReason) {
        guard
            focusProtection.isEnabled,
            !isSystemSuspended,
            Date() >= focusProtectionArmedAt
        else { return }
        let shouldNotifyWeb = focusProtection.recordViolation()
        if reason.shouldSoundAlarm {
            focusAlarmPlayer.start()
        } else {
            focusAlarmPlayer.stop()
        }
        if shouldNotifyWeb {
            sendNativeEvent(type: "focus-violation", payload: ["reason": reason.rawValue])
        }
        restoreProtectedWindow()
    }

    private func restoreProtectedWindow() {
        guard !focusRestoreScheduled else { return }
        focusRestoreScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            self.focusRestoreScheduled = false
            guard self.focusProtection.isEnabled else { return }
            self.showWindow(nil)
            self.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if self.window?.styleMask.contains(.fullScreen) != true,
               !self.isFullscreenTransitionInProgress {
                self.isFullscreenTransitionInProgress = true
                self.window?.toggleFullScreen(nil)
            }
        }
    }

    private func deliverNativeEvent(type: String, payload: [String: Any]) {
        let event: [String: Any] = ["type": type, "payload": payload]
        guard
            JSONSerialization.isValidJSONObject(event),
            let data = try? JSONSerialization.data(withJSONObject: event),
            let json = String(data: data, encoding: .utf8)
        else { return }

        let script = "window.dispatchEvent(new CustomEvent('timeboxer:native-event', { detail: \(json) }));"
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                NSLog("TimeBoxer could not deliver native event: %@", error.localizedDescription)
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            message.name == "timeboxer",
            let body = message.body as? [String: Any],
            let type = body["type"] as? String
        else { return }
        if type == "web-ready" {
            NSLog("TimeBoxer web bridge ready")
            completeWebHandshake()
            return
        }
        onBridgeMessage?(type, body["payload"] as? [String: Any] ?? [:])
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        hasStartedLoading = false
        isPageReady = false
        NSLog("TimeBoxer web view navigation failed: %@", error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // React sends a `web-ready` bridge message after its native-event
        // listener is installed. Do not flush events at document load time.
    }

    private func completeWebHandshake() {
        isPageReady = true
        deliverNativeEvent(type: "view-mode", payload: ["view": requestedMode.rawValue])

        let queuedEvents = pendingEvents
        pendingEvents.removeAll()
        for event in queuedEvents {
            deliverNativeEvent(type: event.type, payload: event.payload)
        }
    }

    private func load(_ mode: ViewMode) {
        requestedMode = mode
        hasStartedLoading = true
        isPageReady = false
        if let webAppDirectory = bundledWebAppDirectory(),
           FileManager.default.fileExists(atPath: webAppDirectory.appendingPathComponent("index.html").path) {
            let url = webAppDirectory.appendingPathComponent("index.html")
            webView.loadFileURL(url, allowingReadAccessTo: webAppDirectory)
            return
        }

        // Development fallback when running the Swift executable directly.
        if let developmentURL = URL(string: "http://127.0.0.1:5173/?view=\(mode.rawValue)") {
            webView.load(URLRequest(url: developmentURL))
        } else {
            hasStartedLoading = false
        }
    }

    private func bundledWebAppDirectory() -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent("WebApp", isDirectory: true)
    }
}
