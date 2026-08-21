import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let policyStore = PolicyStore()
    private let familyStateStore = FamilyStateStore()
    private let ruleEngine = RuleEngine()
    private let loginItemManager = LoginItemManager()
    private lazy var monitor = ApplicationMonitor(policyStore: policyStore, ruleEngine: ruleEngine)
    private let shieldController = ShieldWindowController()
    private let webController = WebWindowController()
    private var statusItem: NSStatusItem?
    private var familySyncTimer: Timer?
    private var applicationInventoryTimer: Timer?
    private var lastDeliveredFamilyRevision = 0
    private var lastFamilyHeartbeatAt = Date.distantPast
    private var lastApplicationInventoryFingerprint = Data()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        configureStatusItem()
        connectComponents()
        enableLoginProtection()
        startFamilyStateSync()
        monitor.start()
        webController.show(.child)
        publishInstalledApplications()
        applicationInventoryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.publishInstalledApplications()
            }
        }

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
        familySyncTimer?.invalidate()
        familySyncTimer = nil
        applicationInventoryTimer?.invalidate()
        applicationInventoryTimer = nil
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        webController.show(.child)
        return true
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

        monitor.onBlockedWebsite = { [weak self] application, host, reason, mode in
            let browserName = application.localizedName ?? "Browser"
            let contentName = host ?? "Browser supervision"
            self?.webController.sendNativeEvent(type: "application-blocked", payload: [
                "bundleIdentifier": application.bundleIdentifier ?? "unknown",
                "applicationName": browserName,
                "host": host ?? "unknown",
                "mode": mode.rawValue,
                "message": "\(contentName) in \(browserName) was \(mode == .enforce ? "blocked" : "observed"): \(reason.title).",
            ])
            guard mode == .enforce else { return }
            self?.shieldController.show(
                applicationName: host.map { "\($0) in \(browserName)" } ?? browserName,
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
            if type == "family-state-request" {
                self.sendFamilyStateSnapshot()
                self.publishInstalledApplications(force: true)
            } else if type == "family-state-update" {
                self.applyFamilyStateUpdate(payload)
            } else if type == "policy-snapshot" {
                self.applyPolicySnapshot(payload)
            } else if type == "focus-fullscreen" {
                self.webController.setFocusFullscreen(payload["enabled"] as? Bool ?? false)
            } else if type == "play-session-started" {
                self.startPlaySession(payload)
            } else if type == "play-session-ended" {
                self.endPlaySession()
            } else {
                NSLog("TimeBoxer bridge event %@: %@", type, String(describing: payload))
            }
        }
    }

    private func startFamilyStateSync() {
        lastDeliveredFamilyRevision = familyStateStore.revision
        familySyncTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let revision = self.familyStateStore.revision
                if revision > self.lastDeliveredFamilyRevision {
                    self.sendFamilyStateSnapshot()
                }
                if Date().timeIntervalSince(self.lastFamilyHeartbeatAt) >= 5 {
                    self.familyStateStore.touchMacHeartbeat()
                    self.lastFamilyHeartbeatAt = Date()
                }
            }
        }
    }

    private func sendFamilyStateSnapshot() {
        guard let envelope = familyStateStore.loadEnvelope() else {
            webController.sendNativeEvent(type: "family-state-snapshot", payload: [
                "schemaVersion": 1,
                "revision": 0,
            ])
            return
        }
        lastDeliveredFamilyRevision = envelope["revision"] as? Int ?? lastDeliveredFamilyRevision
        webController.sendNativeEvent(type: "family-state-snapshot", payload: envelope)
    }

    private func publishInstalledApplications(force: Bool = false) {
        let applications = InstalledApplicationScanner.scan()
        guard let fingerprint = try? JSONEncoder().encode(applications),
              force || fingerprint != lastApplicationInventoryFingerprint
        else { return }
        lastApplicationInventoryFingerprint = fingerprint
        NSLog("TimeBoxer detected %d installed applications", applications.count)
        webController.sendNativeEvent(
            type: "installed-apps-snapshot",
            payload: [
                "applications": applications.map(\.payload),
                "scannedAt": Int64(Date().timeIntervalSince1970 * 1_000),
            ]
        )
    }

    private func applyFamilyStateUpdate(_ payload: [String: Any]) {
        guard let state = payload["state"] as? [String: Any] else { return }
        let sourceId = payload["sourceId"] as? String ?? "mac-web"
        do {
            let envelope = try familyStateStore.save(state: state, sourceId: sourceId)
            lastDeliveredFamilyRevision = envelope["revision"] as? Int ?? lastDeliveredFamilyRevision
            webController.sendNativeEvent(type: "family-state-snapshot", payload: envelope)
        } catch {
            NSLog("TimeBoxer could not save family state: %@", error.localizedDescription)
        }
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        mainMenu.addItem(applicationItem)

        let applicationMenu = NSMenu()
        applicationMenu.addItem(withTitle: "About TimeBoxer", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        applicationMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit TimeBoxer…", action: #selector(requestQuit), keyEquivalent: "q")
        quitItem.target = self
        applicationMenu.addItem(quitItem)
        applicationItem.submenu = applicationMenu
        NSApp.mainMenu = mainMenu
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "hourglass.circle.fill", accessibilityDescription: "TimeBoxer")

        let menu = NSMenu()
        menu.addItem(makeStatusMenuItem("Open Child View", action: #selector(openChildView)))
        menu.addItem(.separator())
        menu.addItem(makeStatusMenuItem("Show Demo Shield", action: #selector(showDemoShield)))
        menu.addItem(makeStatusMenuItem("Reload Local Policy", action: #selector(reloadPolicy)))
        menu.addItem(makeStatusMenuItem(loginItemTitle, action: #selector(toggleLoginItem)))
        let modeItem = NSMenuItem(title: enforcementModeTitle, action: nil, keyEquivalent: "")
        modeItem.isEnabled = false
        menu.addItem(modeItem)
        menu.addItem(.separator())
        let quitItem = makeStatusMenuItem("Quit (Parent PIN)…", action: #selector(requestQuit))
        menu.addItem(quitItem)
        item.menu = menu
        statusItem = item
    }

    @objc private func openChildView() {
        webController.show(.child)
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
        guard confirmParentPIN(
            title: "Change startup protection?",
            message: "A parent PIN is required to change whether TimeBoxer starts at login."
        ) else { return }
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

    @objc private func requestQuit() {
        NSApp.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        confirmParentPIN(
            title: "Quit TimeBoxer protection?",
            message: "Games will no longer be monitored until TimeBoxer starts again."
        ) ? .terminateNow : .terminateCancel
    }

    private func enableLoginProtection() {
        do {
            try loginItemManager.ensureEnabled()
            NSLog(
                "TimeBoxer login protection status: %@",
                loginItemManager.isEnabled ? "enabled" : "not enabled"
            )
        } catch {
            NSLog("TimeBoxer could not enable login protection: %@", error.localizedDescription)
        }
    }

    private func confirmParentPIN(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Confirm")
        alert.addButton(withTitle: "Cancel")

        let pinField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 28))
        pinField.placeholderString = "Parent PIN"
        alert.accessoryView = pinField
        alert.window.initialFirstResponder = pinField

        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        let expectedPIN = familyStateStore.parentPIN ?? "1234"
        guard pinField.stringValue == expectedPIN else {
            NSSound.beep()
            return false
        }
        return true
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
        policy.enforcementMode = .enforce
        if let identifiers = payload["blockedBundleIdentifiers"] as? [String] {
            policy.blockedBundleIdentifiers = Set(identifiers.compactMap { identifier in
                let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
                return normalized.isEmpty ? nil : normalized
            })
        } else {
            policy.blockedBundleIdentifiers.formUnion(FamilyPolicy.safeDefault.blockedBundleIdentifiers)
        }
        if let domains = payload["restrictedDomains"] as? [String] {
            policy.restrictedDomains = Set(domains.compactMap { domain in
                let normalized = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                return normalized.isEmpty ? nil : normalized
            })
        }
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

    private func startPlaySession(_ payload: [String: Any]) {
        let now = Date()
        let requestedMilliseconds = (payload["endsAt"] as? NSNumber)?.doubleValue ?? 0
        let requestedEnd = Date(timeIntervalSince1970: requestedMilliseconds / 1_000)
        let maximumEnd = now.addingTimeInterval(60 * 60)

        var policy = policyStore.policy
        policy.activeEntertainmentUntil = requestedEnd > now ? min(requestedEnd, maximumEnd) : nil
        policy.enforcementMode = .enforce
        do {
            try policyStore.save(policy)
        } catch {
            NSLog("TimeBoxer could not start Play permission: %@", error.localizedDescription)
        }
    }

    private func endPlaySession() {
        var policy = policyStore.policy
        policy.activeEntertainmentUntil = nil
        do {
            try policyStore.save(policy)
        } catch {
            NSLog("TimeBoxer could not end Play permission: %@", error.localizedDescription)
        }
    }
}
