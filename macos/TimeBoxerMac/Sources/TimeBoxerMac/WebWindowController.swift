@preconcurrency import AppKit
@preconcurrency import WebKit

@MainActor
final class WebWindowController: NSWindowController, WKScriptMessageHandler, WKNavigationDelegate {
    enum ViewMode: String {
        case child
        case parent
    }

    var onBridgeMessage: ((String, [String: Any]) -> Void)?

    private let webView: WKWebView
    private var requestedMode: ViewMode = .child
    private var hasStartedLoading = false
    private var isPageReady = false
    private var pendingEvents: [(type: String, payload: [String: Any])] = []

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
        webView.navigationDelegate = self
        contentController.add(self, name: "timeboxer")
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
