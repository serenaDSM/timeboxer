import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let policyStore = PolicyStore()
    private let familyStateStore = FamilyStateStore()
    private let ruleEngine = RuleEngine()
    private let loginItemManager = LoginItemManager()
    private let cloudPairingService = CloudPairingService()
    private lazy var monitor = ApplicationMonitor(policyStore: policyStore, ruleEngine: ruleEngine)
    private let shieldController = ShieldWindowController()
    private let webController = WebWindowController()
    private var statusItem: NSStatusItem?
    private var familySyncTimer: Timer?
    private var applicationInventoryTimer: Timer?
    private var cloudHeartbeatTimer: Timer?
    private var cloudHeartbeatInFlight = false
    private var lastDeliveredFamilyRevision = 0
    private var lastFamilyHeartbeatAt = Date.distantPast
    private var lastApplicationInventoryFingerprint = Data()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        configureStatusItem()
        connectComponents()
        enableLoginProtection()
        startFamilyStateSync()
        startCloudHeartbeat()
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

        if let pairingArgument = CommandLine.arguments.first(where: { $0.hasPrefix("--pair-code=") }) {
            let code = String(pairingArgument.dropFirst("--pair-code=".count))
            Task {
                do {
                    _ = try await cloudPairingService.pair(code: code)
                    refreshPairingMenuItem()
                    sendCloudHeartbeat()
                    NSLog("TimeBoxer cloud pairing completed")
                } catch {
                    NSLog("TimeBoxer cloud pairing failed: %@", error.localizedDescription)
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
        cloudHeartbeatTimer?.invalidate()
        cloudHeartbeatTimer = nil
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
        let pairingItem = makeStatusMenuItem(pairingMenuTitle, action: #selector(pairWithParent))
        pairingItem.isEnabled = !cloudPairingService.isPaired
        menu.addItem(pairingItem)
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

    @objc private func pairWithParent() {
        let alert = NSAlert()
        alert.messageText = "Pair this Mac with a parent"
        alert.informativeText = "Enter the six-digit code shown in TimeBoxer Parent on the iPhone."
        alert.addButton(withTitle: "Pair Mac")
        alert.addButton(withTitle: "Cancel")

        let codeField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 28))
        codeField.placeholderString = "000 000"
        alert.accessoryView = codeField
        alert.window.initialFirstResponder = codeField
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Task {
            do {
                _ = try await cloudPairingService.pair(code: codeField.stringValue)
                let success = NSAlert()
                success.messageText = "Mac paired"
                success.informativeText = "This Mac is now linked to the family in TimeBoxer Parent."
                success.runModal()
                refreshPairingMenuItem()
            } catch {
                let failure = NSAlert(error: error)
                failure.messageText = "Could not pair this Mac"
                failure.runModal()
            }
        }
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

    private var pairingMenuTitle: String {
        cloudPairingService.isPaired ? "Paired with Parent" : "Pair with Parent…"
    }

    private func refreshPairingMenuItem() {
        guard let item = statusItem?.menu?.items.first(where: {
            $0.title == "Pair with Parent…" || $0.title == "Paired with Parent"
        }) else { return }
        item.title = pairingMenuTitle
        item.isEnabled = !cloudPairingService.isPaired
    }

    private func startCloudHeartbeat() {
        cloudHeartbeatTimer?.invalidate()
        sendCloudHeartbeat()
        cloudHeartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sendCloudHeartbeat()
            }
        }
    }

    private func sendCloudHeartbeat() {
        guard cloudPairingService.isPaired, !cloudHeartbeatInFlight else { return }
        cloudHeartbeatInFlight = true
        Task {
            defer { cloudHeartbeatInFlight = false }
            do {
                let heartbeat = try await cloudPairingService.heartbeat()
                if let cloudPolicy = heartbeat.policy {
                    try applyCloudPolicy(cloudPolicy)
                    try cloudPairingService.acknowledgePolicyRevision(heartbeat.policyRevision)
                    NSLog("TimeBoxer applied cloud policy revision %ld", heartbeat.policyRevision)
                }
                NSLog("TimeBoxer cloud heartbeat completed at policy revision %ld", heartbeat.policyRevision)
            } catch {
                NSLog("TimeBoxer cloud heartbeat failed: %@", error.localizedDescription)
            }
        }
    }

    private func applyCloudPolicy(_ document: CloudPolicyDocument) throws {
        var policy = policyStore.policy
        policy.bedtimeBufferMinutes = document.bedtimeBufferMinutes
        policy.limits = DailyLimits(
            school: document.dayPlans.school.baseMinutes,
            weekend: document.dayPlans.weekend.baseMinutes,
            holiday: document.dayPlans.holiday.baseMinutes
        )

        let today = Self.localDateKey(.now)
        policy.dayOverride = document.todayPlanDate == today ? document.todayPlan : nil
        policy.bonusMinutesToday = document.parentBonusDate == today
            ? min(120, max(0, document.parentBonusMinutes ?? 0))
            : 0
        policy.blockedBundleIdentifiers = FamilyPolicy.safeDefault.blockedBundleIdentifiers
            .union(document.protectedApplications)
        policy.restrictedDomains = WebsiteClassification.defaultRestrictedDomains
            .union(document.protectedDomains)
        policy.enforcementMode = .enforce
        try policyStore.save(policy)

        guard var state = familyStateStore.loadEnvelope()?["state"] as? [String: Any] else { return }
        var webPolicy = state["policy"] as? [String: Any] ?? [:]
        webPolicy["id"] = "cloud"
        webPolicy["name"] = "Family plan"
        webPolicy["schoolLimit"] = document.dayPlans.school.baseMinutes
        webPolicy["weekendLimit"] = document.dayPlans.weekend.baseMinutes
        webPolicy["holidayLimit"] = document.dayPlans.holiday.baseMinutes
        webPolicy["schoolEarnCapMinutes"] = document.dayPlans.school.earnCapMinutes
        webPolicy["weekendEarnCapMinutes"] = document.dayPlans.weekend.earnCapMinutes
        webPolicy["holidayEarnCapMinutes"] = document.dayPlans.holiday.earnCapMinutes
        webPolicy["maxSessionMinutes"] = document.maxSessionMinutes
        webPolicy["cooldownMinutes"] = document.cooldownMinutes
        webPolicy["cooldownTriggerMinutes"] = document.cooldownTriggerMinutes
        webPolicy["bedtimeBufferMinutes"] = document.bedtimeBufferMinutes
        webPolicy["blockedBundleIdentifiers"] = Array(policy.blockedBundleIdentifiers).sorted()
        webPolicy["restrictedDomains"] = Array(policy.restrictedDomains).sorted()
        state["policy"] = webPolicy

        var overrides = state["dayOverrides"] as? [String: Any] ?? [:]
        if document.todayPlanDate == today, let day = document.todayPlan {
            overrides[today] = day.rawValue
        } else {
            overrides.removeValue(forKey: today)
        }
        state["dayOverrides"] = overrides

        var bonuses = state["dailyBonuses"] as? [String: Any] ?? [:]
        bonuses[today] = policy.bonusMinutesToday
        state["dailyBonuses"] = bonuses
        state["lastPolicyUpdatedAt"] = Int64(Date().timeIntervalSince1970 * 1_000)

        let envelope = try familyStateStore.save(state: state, sourceId: "cloud-policy")
        lastDeliveredFamilyRevision = envelope["revision"] as? Int ?? lastDeliveredFamilyRevision
        webController.sendNativeEvent(type: "family-state-snapshot", payload: envelope)
    }

    private static func localDateKey(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
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
