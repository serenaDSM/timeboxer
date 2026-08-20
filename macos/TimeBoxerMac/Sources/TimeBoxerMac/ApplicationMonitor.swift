import AppKit

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
    private let reportCooldown: TimeInterval = 60

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
            timeInterval: 5,
            target: self,
            selector: #selector(checkFrontmostApplication),
            userInfo: nil,
            repeats: true
        )
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

    @objc private func checkFrontmostApplication() {
        guard let application = workspace.frontmostApplication else { return }
        evaluate(application)
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
            policyStore.policy.blockedBundleIdentifiers.contains(bundleIdentifier)
        else { return }

        let now = Date()
        let decision = ruleEngine.decision(
            for: policyStore.policy,
            date: now,
            calendar: calendar
        )
        guard let reason = decision.reason else {
            lastReports.removeValue(forKey: bundleIdentifier)
            return
        }

        let mode = policyStore.policy.enforcementMode
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

        // Safety boundary: observe is the default. Enforcement only requests a
        // graceful quit and never force-terminates an app in this prototype.
        if mode == .enforce {
            _ = application.terminate()
        }
    }
}
