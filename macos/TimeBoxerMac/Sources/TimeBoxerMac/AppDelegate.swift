import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let policyStore = PolicyStore()
    private let ruleEngine = RuleEngine()
    private let loginItemManager = LoginItemManager()
    private lazy var monitor = ApplicationMonitor(policyStore: policyStore, ruleEngine: ruleEngine)
    private let shieldController = ShieldWindowController()
    private let webController = WebWindowController()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        configureStatusItem()
        connectComponents()
        monitor.start()
        webController.show(.child)

        if CommandLine.arguments.contains("--demo-shield") {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.shieldController.showDemo()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func connectComponents() {
        monitor.onBlockedApplication = { [weak self] application, reason, mode in
            self?.webController.sendNativeEvent(type: "application-blocked", payload: [
                "bundleIdentifier": application.bundleIdentifier ?? "unknown",
                "applicationName": application.localizedName ?? "Entertainment app",
                "mode": mode.rawValue,
                "message": "\(application.localizedName ?? "An entertainment app") was \(mode == .enforce ? "blocked" : "observed"): \(reason.title).",
            ])
            guard mode == .enforce else { return }
            self?.shieldController.show(
                applicationName: application.localizedName ?? "Entertainment app",
                reason: reason
            )
        }

        shieldController.onEarnTime = { [weak self] in
            self?.webController.show(.child)
        }
        shieldController.onAskParent = { [weak self] in
            self?.webController.show(.child)
            self?.webController.sendNativeEvent(type: "shield-request-extra", payload: ["minutes": 10])
        }

        webController.onBridgeMessage = { [weak self] type, payload in
            guard let self else { return }
            if type == "policy-snapshot" {
                self.applyPolicySnapshot(payload)
            } else {
                NSLog("TimeBoxer bridge event %@: %@", type, String(describing: payload))
            }
        }
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        mainMenu.addItem(applicationItem)

        let applicationMenu = NSMenu()
        applicationMenu.addItem(withTitle: "About TimeBoxer", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "Quit TimeBoxer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationItem.submenu = applicationMenu
        NSApp.mainMenu = mainMenu
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "hourglass.circle.fill", accessibilityDescription: "TimeBoxer")

        let menu = NSMenu()
        menu.addItem(makeStatusMenuItem("Open Child View", action: #selector(openChildView)))
        menu.addItem(makeStatusMenuItem("Open Parent Preview", action: #selector(openParentView)))
        menu.addItem(.separator())
        menu.addItem(makeStatusMenuItem("Show Demo Shield", action: #selector(showDemoShield)))
        menu.addItem(makeStatusMenuItem("Reload Local Policy", action: #selector(reloadPolicy)))
        menu.addItem(makeStatusMenuItem(loginItemTitle, action: #selector(toggleLoginItem)))
        let modeItem = NSMenuItem(title: enforcementModeTitle, action: nil, keyEquivalent: "")
        modeItem.isEnabled = false
        menu.addItem(modeItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        item.menu = menu
        statusItem = item
    }

    @objc private func openChildView() {
        webController.show(.child)
    }

    @objc private func openParentView() {
        webController.show(.parent)
    }

    @objc private func showDemoShield() {
        shieldController.showDemo()
    }

    @objc private func reloadPolicy() {
        policyStore.reload()
        let mode = policyStore.policy.enforcementMode == .enforce ? "Enforce" : "Observe Only"
        statusItem?.menu?.items.first(where: { $0.title.hasPrefix("Mode:") })?.title = "Mode: \(mode)"
    }

    @objc private func toggleLoginItem() {
        do {
            try loginItemManager.toggle()
            statusItem?.menu?.items.first(where: {
                $0.title == "Start at Login" || $0.title == "Stop Starting at Login"
            })?.title = loginItemTitle
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change login setting"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private var loginItemTitle: String {
        loginItemManager.isEnabled ? "Stop Starting at Login" : "Start at Login"
    }

    private var enforcementModeTitle: String {
        policyStore.policy.enforcementMode == .enforce ? "Mode: Enforce" : "Mode: Observe Only"
    }

    private func makeStatusMenuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func applyPolicySnapshot(_ payload: [String: Any]) {
        var policy = policyStore.policy
        policy.childName = payload["childName"] as? String ?? policy.childName
        policy.bedtime = payload["bedtime"] as? String ?? policy.bedtime
        policy.bedtimeBufferMinutes = payload["bedtimeBufferMinutes"] as? Int ?? policy.bedtimeBufferMinutes
        policy.limits.school = payload["schoolLimit"] as? Int ?? policy.limits.school
        policy.limits.weekend = payload["weekendLimit"] as? Int ?? policy.limits.weekend
        policy.limits.holiday = payload["holidayLimit"] as? Int ?? policy.limits.holiday
        policy.usedMinutesToday = payload["usedMinutesToday"] as? Int ?? policy.usedMinutesToday
        policy.bonusMinutesToday = payload["bonusMinutesToday"] as? Int ?? policy.bonusMinutesToday
        if let rawDayType = payload["dayOverride"] as? String {
            policy.dayOverride = TimeBoxerDayType(rawValue: rawDayType)
        } else {
            policy.dayOverride = nil
        }

        do {
            try policyStore.save(policy)
        } catch {
            NSLog("TimeBoxer could not save web policy snapshot: %@", error.localizedDescription)
        }
    }
}
