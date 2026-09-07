import AppKit
import Security

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let policyStore = PolicyStore()
    private let familyStateStore = FamilyStateStore()
    private let ruleEngine = RuleEngine()
    private let loginItemManager = LoginItemManager()
    private let cloudPairingService = CloudPairingService()
    private lazy var monitor = ApplicationMonitor(
        policyStore: policyStore,
        ruleEngine: ruleEngine,
        shouldAutoProtectDetectedEntertainment: { [weak self] in
            self?.cloudPairingService.isPaired == false
        }
    )
    private let shieldController = ShieldWindowController()
    private let webController = WebWindowController()
    private var statusItem: NSStatusItem?
    private var familySyncTimer: Timer?
    private var applicationInventoryTimer: Timer?
    private var cloudHeartbeatTimer: Timer?
    private var cloudHeartbeatInFlight = false
    private var pendingCloudApplicationInventory: [InstalledApplicationRecord]?
    private var pendingCloudEvents: [CloudDeviceEvent] = []
    private var cloudEventInFlight = false
    private var pendingCloudExtraTimeRequests: [UUID: Int] = [:]
    private var cloudExtraTimeRequestInFlight = false
    private var lastDeliveredFamilyRevision = 0
    private var lastFamilyHeartbeatAt = Date.distantPast
    private var lastApplicationInventoryFingerprint = Data()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        configureStatusItem()
        connectComponents()
        enableLoginProtection()
        startFamilyStateSync()
        restorePendingCloudExtraTimeRequests()
        startCloudHeartbeat()
        revokeStalePlaySession()
        ensureAlertOnlyMode()
        publishInstalledApplications()
        monitor.start()
        webController.show(.child)
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
        endPlaySession()
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
        monitor.onBlockedApplication = { [weak self] application, reason, mode, shouldNotifyParent in
            if shouldNotifyParent {
                self?.webController.sendNativeEvent(type: "application-blocked", payload: [
                    "bundleIdentifier": application.bundleIdentifier ?? "unknown",
                    "applicationName": application.localizedName ?? "Entertainment app",
                    "mode": mode.rawValue,
                    "message": "\(application.localizedName ?? "An entertainment app") triggered the TimeBoxer shield outside approved Play time: \(reason.title).",
                ])
                self?.enqueueCloudViolation(
                    eventType: "app_blocked",
                    subjectLabel: application.localizedName ?? "Entertainment app",
                    payload: [
                        "bundleIdentifier": application.bundleIdentifier ?? "unknown",
                        "reason": reason.title,
                        "response": mode.shouldTerminateEntertainment ? "blocked" : "shielded",
                    ]
                )
            }
            self?.shieldController.show(
                applicationName: application.localizedName ?? "Entertainment app",
                reason: reason,
                mode: mode
            )
        }

        monitor.onBlockedWebsite = { [weak self] application, host, reason, mode, shouldNotifyParent in
            let browserName = application.localizedName ?? "Browser"
            let contentName = host ?? "Browser supervision"
            if shouldNotifyParent {
                self?.webController.sendNativeEvent(type: "application-blocked", payload: [
                    "bundleIdentifier": application.bundleIdentifier ?? "unknown",
                    "applicationName": browserName,
                    "host": host ?? "unknown",
                    "mode": mode.rawValue,
                    "message": "\(contentName) in \(browserName) triggered the TimeBoxer shield outside approved Play time: \(reason.title).",
                ])
                self?.enqueueCloudViolation(
                    eventType: "website_blocked",
                    subjectLabel: host ?? "Protected website",
                    payload: [
                        "browser": browserName,
                        "host": host ?? "unknown",
                        "reason": reason.title,
                        "response": mode.shouldTerminateEntertainment ? "blocked" : "shielded",
                    ]
                )
            }
            self?.shieldController.show(
                applicationName: host.map { "\($0) in \(browserName)" } ?? browserName,
                reason: reason,
                mode: mode
            )
        }

        shieldController.onEarnTime = { [weak self] in
            self?.webController.show(.child)
        }
        shieldController.onAskParent = { [weak self] in
            let requestID = UUID()
            self?.submitCloudExtraTimeRequest(id: requestID, minutes: 10)
            self?.webController.show(.child)
            self?.webController.sendNativeEvent(type: "shield-request-extra", payload: [
                "minutes": 10,
                "requestId": requestID.uuidString,
            ])
        }
        shieldController.onReturnToHomework = { [weak self] in
            self?.webController.show(.child)
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
            } else if type == "focus-restored" {
                self.webController.acknowledgeFocusReturn()
            } else if type == "play-session-started" {
                self.startPlaySession(payload)
            } else if type == "play-session-ended" {
                self.endPlaySession()
            } else if type == "authorize-parent-pin-setup",
                      let requestID = payload["requestId"] as? String {
                self.authorizeParentPINSetup(requestID: requestID)
            } else if type == "extra-time-requested",
                      let requestIDValue = payload["requestId"] as? String,
                      let requestID = UUID(uuidString: requestIDValue) {
                self.submitCloudExtraTimeRequest(
                    id: requestID,
                    minutes: payload["minutes"] as? Int ?? 10
                )
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
        applyStandaloneRecommendedProtection(applications)
        guard let fingerprint = try? JSONEncoder().encode(applications) else { return }
        let inventoryChanged = fingerprint != lastApplicationInventoryFingerprint
        guard force || inventoryChanged else { return }
        if inventoryChanged {
            lastApplicationInventoryFingerprint = fingerprint
            NSLog("TimeBoxer detected %d installed applications", applications.count)
            pendingCloudApplicationInventory = applications
            sendCloudHeartbeat()
        }
        webController.sendNativeEvent(
            type: "installed-apps-snapshot",
            payload: [
                "applications": applications.map(\.payload),
                "scannedAt": Int64(Date().timeIntervalSince1970 * 1_000),
            ]
        )
    }

    private func applyStandaloneRecommendedProtection(
        _ applications: [InstalledApplicationRecord]
    ) {
        guard !cloudPairingService.isPaired else { return }
        let recommended = InstalledApplicationScanner.recommendedBundleIdentifiers(in: applications)
        guard !recommended.isEmpty else { return }

        var policy = policyStore.policy
        let previous = policy.blockedBundleIdentifiers
        let modeChanged = policy.enforcementMode != .observe
        policy.blockedBundleIdentifiers.formUnion(recommended)
        policy.enforcementMode = .observe
        guard policy.blockedBundleIdentifiers != previous || modeChanged else { return }

        do {
            try policyStore.save(policy)
            NSLog(
                "TimeBoxer enabled standalone protection for %d detected entertainment apps",
                recommended.count
            )
        } catch {
            NSLog("TimeBoxer could not save standalone app protection: %@", error.localizedDescription)
        }
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
        guard
            let expectedPIN = familyStateStore.parentPIN,
            ParentPINPolicy.isSecure(expectedPIN)
        else {
            let setupAlert = NSAlert()
            setupAlert.messageText = "Parent PIN setup required"
            setupAlert.informativeText = "Open TimeBoxer and ask a parent to create a private PIN. The old default PIN is disabled."
            setupAlert.alertStyle = .warning
            setupAlert.runModal()
            return false
        }

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
        guard pinField.stringValue == expectedPIN else {
            NSSound.beep()
            return false
        }
        return true
    }

    private func authorizeParentPINSetup(requestID: String) {
        var authorizationReference: AuthorizationRef?
        let createStatus = AuthorizationCreate(
            nil,
            nil,
            [.interactionAllowed, .extendRights, .preAuthorize],
            &authorizationReference
        )
        guard createStatus == errAuthorizationSuccess, let authorizationReference else {
            sendParentAuthorizationResult(requestID: requestID, allowed: false)
            return
        }
        defer { AuthorizationFree(authorizationReference, []) }

        let status = "system.privilege.admin".withCString { authorizationName in
            var authorizationItem = AuthorizationItem(
                name: authorizationName,
                valueLength: 0,
                value: nil,
                flags: 0
            )
            return withUnsafeMutablePointer(to: &authorizationItem) { itemPointer in
                var authorizationRights = AuthorizationRights(count: 1, items: itemPointer)
                return AuthorizationCopyRights(
                    authorizationReference,
                    &authorizationRights,
                    nil,
                    [.interactionAllowed, .extendRights],
                    nil
                )
            }
        }
        sendParentAuthorizationResult(
            requestID: requestID,
            allowed: status == errAuthorizationSuccess
        )
    }

    private func sendParentAuthorizationResult(requestID: String, allowed: Bool) {
        webController.sendNativeEvent(
            type: "parent-authorization-result",
            payload: ["requestId": requestID, "allowed": allowed]
        )
    }

    private var loginItemTitle: String {
        loginItemManager.isEnabled ? "Stop Starting at Login" : "Start at Login"
    }

    private var enforcementModeTitle: String {
        policyStore.policy.enforcementMode.shouldTerminateEntertainment
            ? "Mode: Block"
            : "Mode: Focus Shield"
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
        let applicationInventory = pendingCloudApplicationInventory
        Task {
            do {
                let heartbeat = try await cloudPairingService.heartbeat(
                    applicationInventory: applicationInventory
                )
                if let applicationInventory,
                   pendingCloudApplicationInventory == applicationInventory {
                    pendingCloudApplicationInventory = nil
                    NSLog("TimeBoxer uploaded %d detected applications", applicationInventory.count)
                }
                if let cloudPolicy = heartbeat.policy {
                    try applyCloudPolicy(cloudPolicy)
                    try cloudPairingService.acknowledgePolicyRevision(heartbeat.policyRevision)
                    NSLog("TimeBoxer applied cloud policy revision %ld", heartbeat.policyRevision)
                }
                if let requestUpdates = heartbeat.requestUpdates {
                    try applyCloudRequestUpdates(requestUpdates)
                }
                NSLog("TimeBoxer cloud heartbeat completed at policy revision %ld", heartbeat.policyRevision)
                cloudHeartbeatInFlight = false
                flushNextCloudEvent()
                flushNextCloudExtraTimeRequest()
                if pendingCloudApplicationInventory != nil {
                    sendCloudHeartbeat()
                }
            } catch {
                cloudHeartbeatInFlight = false
                NSLog("TimeBoxer cloud heartbeat failed: %@", error.localizedDescription)
            }
        }
    }

    private func enqueueCloudViolation(
        eventType: String,
        subjectLabel: String,
        payload: [String: String]
    ) {
        let event = CloudDeviceEvent(
            clientEventId: UUID(),
            eventType: eventType,
            severity: "violation",
            subjectLabel: String(subjectLabel.prefix(160)),
            occurredAt: ISO8601DateFormatter().string(from: .now),
            payload: payload
        )
        pendingCloudEvents.append(event)
        if pendingCloudEvents.count > 100 {
            pendingCloudEvents.removeFirst(pendingCloudEvents.count - 100)
        }
        flushNextCloudEvent()
    }

    private func flushNextCloudEvent() {
        guard
            cloudPairingService.isPaired,
            !cloudEventInFlight,
            let event = pendingCloudEvents.first
        else { return }
        cloudEventInFlight = true
        Task {
            do {
                try await cloudPairingService.record(event: event)
                if pendingCloudEvents.first?.clientEventId == event.clientEventId {
                    pendingCloudEvents.removeFirst()
                }
                cloudEventInFlight = false
                flushNextCloudEvent()
            } catch {
                cloudEventInFlight = false
                NSLog("TimeBoxer cloud event upload failed: %@", error.localizedDescription)
            }
        }
    }

    private func submitCloudExtraTimeRequest(id: UUID, minutes: Int) {
        pendingCloudExtraTimeRequests[id] = min(60, max(1, minutes))
        flushNextCloudExtraTimeRequest()
    }

    private func flushNextCloudExtraTimeRequest() {
        guard
            cloudPairingService.isPaired,
            !cloudExtraTimeRequestInFlight,
            let request = pendingCloudExtraTimeRequests.first
        else { return }
        cloudExtraTimeRequestInFlight = true
        Task {
            do {
                try await cloudPairingService.requestExtraTime(
                    clientRequestID: request.key,
                    minutes: request.value
                )
                pendingCloudExtraTimeRequests.removeValue(forKey: request.key)
                cloudExtraTimeRequestInFlight = false
                NSLog("TimeBoxer uploaded an extra-time request")
                flushNextCloudExtraTimeRequest()
            } catch {
                cloudExtraTimeRequestInFlight = false
                NSLog("TimeBoxer extra-time request upload failed: %@", error.localizedDescription)
            }
        }
    }

    private func restorePendingCloudExtraTimeRequests() {
        guard
            let state = familyStateStore.loadEnvelope()?["state"] as? [String: Any],
            let requests = state["pendingRequests"] as? [[String: Any]]
        else { return }
        for request in requests where request["status"] as? String == "pending" {
            guard
                let idValue = request["id"] as? String,
                let id = UUID(uuidString: idValue)
            else { continue }
            pendingCloudExtraTimeRequests[id] = min(60, max(1, request["minutes"] as? Int ?? 10))
        }
    }

    private func applyCloudRequestUpdates(_ updates: [CloudRequestUpdate]) throws {
        guard
            !updates.isEmpty,
            var state = familyStateStore.loadEnvelope()?["state"] as? [String: Any],
            var requests = state["pendingRequests"] as? [[String: Any]]
        else { return }
        var changed = false
        for update in updates {
            guard let index = requests.firstIndex(where: {
                guard let id = $0["id"] as? String else { return false }
                return UUID(uuidString: id) == update.clientRequestId
            }) else { continue }
            if requests[index]["status"] as? String != update.status {
                requests[index]["status"] = update.status
                if let resolvedAt = update.resolvedAt,
                   let date = ISO8601DateFormatter().date(from: resolvedAt) {
                    requests[index]["resolvedAt"] = Int64(date.timeIntervalSince1970 * 1_000)
                }
                changed = true
            }
        }
        guard changed else { return }
        state["pendingRequests"] = requests
        let envelope = try familyStateStore.save(state: state, sourceId: "cloud-request")
        lastDeliveredFamilyRevision = envelope["revision"] as? Int ?? lastDeliveredFamilyRevision
        webController.sendNativeEvent(type: "family-state-snapshot", payload: envelope)
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
        policy.blockedBundleIdentifiers = Set(document.protectedApplications)
        policy.restrictedDomains = Set(document.protectedDomains)
        policy.enforcementMode = .observe
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
        policy.enforcementMode = .observe
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
        policy.enforcementMode = .observe
        do {
            try policyStore.save(policy)
        } catch {
            NSLog("TimeBoxer could not start Play permission: %@", error.localizedDescription)
        }
    }

    private func endPlaySession() {
        do {
            try policyStore.revokeActiveEntertainmentPermission()
        } catch {
            NSLog("TimeBoxer could not end Play permission: %@", error.localizedDescription)
        }
    }

    private func revokeStalePlaySession() {
        do {
            if try policyStore.revokeActiveEntertainmentPermission() {
                NSLog("TimeBoxer revoked a stale Play permission during launch")
            }
        } catch {
            NSLog("TimeBoxer could not revoke stale Play permission: %@", error.localizedDescription)
        }
    }

    private func ensureAlertOnlyMode() {
        guard policyStore.policy.enforcementMode != .observe else { return }
        var policy = policyStore.policy
        policy.enforcementMode = .observe
        do {
            try policyStore.save(policy)
            NSLog("TimeBoxer migrated protection to alerts-only mode")
        } catch {
            NSLog("TimeBoxer could not save alerts-only mode: %@", error.localizedDescription)
        }
    }
}
