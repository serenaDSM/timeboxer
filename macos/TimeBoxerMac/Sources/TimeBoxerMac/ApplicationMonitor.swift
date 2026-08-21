import AppKit

enum EntertainmentClassification {
    static func isGameCategory(_ category: String) -> Bool {
        category == "public.app-category.games"
            || (category.hasPrefix("public.app-category.") && category.hasSuffix("-games"))
    }
}

@MainActor
final class ApplicationMonitor: NSObject {
    typealias BlockHandler = (NSRunningApplication, BlockReason, EnforcementMode) -> Void

    private let workspace: NSWorkspace
    private let policyStore: PolicyStore
    private let ruleEngine: RuleEngine
    private let calendar: Calendar
    private let protectedBundleIdentifiers: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.systempreferences",
        "com.apple.systemsettings",
        "nz.co.timeboxer.mac",
    ]
    private var monitorTimer: Timer?
    private var lastReports: [String: (reason: BlockReason, mode: EnforcementMode, date: Date)] = [:]
    private var entertainmentClassificationCache: [String: Bool] = [:]
    private var terminationRequestedAt: [pid_t: Date] = [:]
    private let reportCooldown: TimeInterval = 60
    private let forceTerminationDelay: TimeInterval = 2

    var onBlockedApplication: BlockHandler?

    init(
        workspace: NSWorkspace = .shared,
        policyStore: PolicyStore,
        ruleEngine: RuleEngine = RuleEngine(),
        calendar: Calendar = .current
    ) {
        self.workspace = workspace
        self.policyStore = policyStore
        self.ruleEngine = ruleEngine
        self.calendar = calendar
        super.init()
    }

    func start() {
        let center = workspace.notificationCenter
        center.addObserver(
            self,
            selector: #selector(applicationDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        monitorTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(checkRunningApplications),
            userInfo: nil,
            repeats: true
        )
        checkRunningApplications()
    }

    func stop() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        workspace.notificationCenter.removeObserver(self)
    }

    @objc private func applicationDidLaunch(_ notification: Notification) {
        evaluate(notification)
    }

    @objc private func applicationDidActivate(_ notification: Notification) {
        evaluate(notification)
    }

    @objc private func checkRunningApplications() {
        let applications = workspace.runningApplications
        let runningProcessIdentifiers = Set(applications.map(\.processIdentifier))
        terminationRequestedAt = terminationRequestedAt.filter {
            runningProcessIdentifiers.contains($0.key)
        }
        for application in applications {
            evaluate(application)
        }
    }

    private func evaluate(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        evaluate(application)
    }

    private func evaluate(_ application: NSRunningApplication) {
        guard
            let bundleIdentifier = application.bundleIdentifier,
            !protectedBundleIdentifiers.contains(bundleIdentifier),
            isManagedEntertainmentApp(application, bundleIdentifier: bundleIdentifier)
        else { return }

        let now = Date()
        let decision = ruleEngine.decision(
            for: policyStore.policy,
            date: now,
            calendar: calendar
        )
        guard let reason = decision.reason else {
            lastReports.removeValue(forKey: bundleIdentifier)
            terminationRequestedAt.removeValue(forKey: application.processIdentifier)
            return
        }

        let mode = policyStore.policy.enforcementMode

        // Enforcement is never throttled. A child reopening the same game must
        // be stopped again even when the parent notification is deduplicated.
        if mode == .enforce {
            _ = application.hide()
            let processIdentifier = application.processIdentifier
            if let requestedAt = terminationRequestedAt[processIdentifier],
               now.timeIntervalSince(requestedAt) >= forceTerminationDelay {
                _ = application.forceTerminate()
                terminationRequestedAt.removeValue(forKey: processIdentifier)
            } else {
                _ = application.terminate()
                terminationRequestedAt[processIdentifier] = terminationRequestedAt[processIdentifier] ?? now
            }
        }

        if let lastReport = lastReports[bundleIdentifier],
           lastReport.reason == reason,
           lastReport.mode == mode,
           now.timeIntervalSince(lastReport.date) < reportCooldown {
            return
        }
        lastReports[bundleIdentifier] = (reason, mode, now)

        NSLog(
            "TimeBoxer %@ %@ (%@): %@",
            mode == .enforce ? "blocked" : "observed",
            application.localizedName ?? "application",
            bundleIdentifier,
            reason.title
        )

        onBlockedApplication?(application, reason, mode)
    }

    private func isManagedEntertainmentApp(
        _ application: NSRunningApplication,
        bundleIdentifier: String
    ) -> Bool {
        if policyStore.policy.blockedBundleIdentifiers.contains(bundleIdentifier) {
            return true
        }
        if let cached = entertainmentClassificationCache[bundleIdentifier] {
            return cached
        }
        guard
            let bundleURL = application.bundleURL,
            let bundle = Bundle(url: bundleURL),
            let category = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
        else {
            entertainmentClassificationCache[bundleIdentifier] = false
            return false
        }
        let isGame = EntertainmentClassification.isGameCategory(category)
        entertainmentClassificationCache[bundleIdentifier] = isGame
        return isGame
    }
}
