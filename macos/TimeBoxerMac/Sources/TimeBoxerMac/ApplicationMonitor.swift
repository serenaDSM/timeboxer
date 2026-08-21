import AppKit

enum EntertainmentClassification {
    static func isGameCategory(_ category: String) -> Bool {
        category == "public.app-category.games"
            || (category.hasPrefix("public.app-category.") && category.hasSuffix("-games"))
    }
}

enum WebsiteClassification {
    static let supportedBrowserBundleIdentifiers: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
    ]

    static let defaultRestrictedDomains: Set<String> = [
        "bilibili.com",
        "crazygames.com",
        "disneyplus.com",
        "iqiyi.com",
        "mgtv.com",
        "miniclip.com",
        "netflix.com",
        "now.gg",
        "poki.com",
        "roblox.com",
        "tiktok.com",
        "twitch.tv",
        "v.qq.com",
        "youku.com",
        "youtube.com",
    ]

    static let domainAliases: [String: Set<String>] = [
        "youtube.com": ["youtu.be", "youtube-nocookie.com"],
    ]

    static func safeReplacementURL(for bundleIdentifier: String) -> String? {
        switch bundleIdentifier {
        case "com.apple.Safari": "about:blank"
        case "com.google.Chrome": "chrome://newtab/"
        default: nil
        }
    }

    static func host(from urlString: String) -> String? {
        guard let host = URLComponents(string: urlString)?.host?.lowercased() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    static func isRestrictedHost(
        _ host: String,
        restrictedDomains: Set<String> = defaultRestrictedDomains
    ) -> Bool {
        let normalizedHost = host.lowercased()
        let effectiveDomains = restrictedDomains.reduce(into: restrictedDomains) { result, domain in
            result.formUnion(domainAliases[domain] ?? [])
        }
        return effectiveDomains.contains { domain in
            normalizedHost == domain || normalizedHost.hasSuffix(".\(domain)")
        }
    }
}

@MainActor
final class ApplicationMonitor: NSObject {
    typealias BlockHandler = (NSRunningApplication, BlockReason, EnforcementMode) -> Void
    typealias WebsiteBlockHandler = (NSRunningApplication, String?, BlockReason, EnforcementMode) -> Void

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
    private var lastWebsiteReports: [String: (reason: BlockReason, mode: EnforcementMode, date: Date)] = [:]
    private var terminationRequestedAt: [pid_t: Date] = [:]
    private var browserURLRetryAfter = Date.distantPast
    private let reportCooldown: TimeInterval = 60
    private let forceTerminationDelay: TimeInterval = 2
    private let browserURLRetryDelay: TimeInterval = 5

    var onBlockedApplication: BlockHandler?
    var onBlockedWebsite: WebsiteBlockHandler?

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
        evaluateFrontmostBrowser()
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
        _ = application
        return policyStore.policy.blockedBundleIdentifiers.contains(bundleIdentifier)
    }

    private func evaluateFrontmostBrowser() {
        guard
            let application = workspace.frontmostApplication,
            let bundleIdentifier = application.bundleIdentifier,
            WebsiteClassification.supportedBrowserBundleIdentifiers.contains(bundleIdentifier)
        else { return }

        let now = Date()
        let decision = ruleEngine.decision(for: policyStore.policy, date: now, calendar: calendar)
        guard let ruleReason = decision.reason else {
            clearWebsiteReports(bundleIdentifier: bundleIdentifier)
            return
        }

        let urlString = activeBrowserURL(bundleIdentifier: bundleIdentifier)
        let host = urlString.flatMap(WebsiteClassification.host(from:))
        let reason: BlockReason
        if urlString != nil, host == nil {
            // Browser-owned pages such as Safari Start Page or chrome://newtab
            // have no web host but still prove that Automation access works.
            clearWebsiteReports(bundleIdentifier: bundleIdentifier)
            return
        } else if let host {
            guard WebsiteClassification.isRestrictedHost(
                host,
                restrictedDomains: policyStore.policy.restrictedDomains
            ) else {
                clearWebsiteReports(bundleIdentifier: bundleIdentifier)
                return
            }
            reason = ruleReason
        } else {
            reason = .browserSupervisionUnavailable
        }

        let mode = policyStore.policy.enforcementMode
        if mode == .enforce {
            if host != nil {
                replaceActiveBrowserTab(bundleIdentifier: bundleIdentifier)
            }
            _ = application.hide()
        }

        let reportKey = "\(bundleIdentifier):\(host ?? "permission")"
        if let lastReport = lastWebsiteReports[reportKey],
           lastReport.reason == reason,
           lastReport.mode == mode,
           now.timeIntervalSince(lastReport.date) < reportCooldown {
            return
        }
        lastWebsiteReports[reportKey] = (reason, mode, now)
        onBlockedWebsite?(application, host, reason, mode)
    }

    private func clearWebsiteReports(bundleIdentifier: String) {
        let prefix = "\(bundleIdentifier):"
        lastWebsiteReports = lastWebsiteReports.filter { !$0.key.hasPrefix(prefix) }
    }

    private func activeBrowserURL(bundleIdentifier: String) -> String? {
        let now = Date()
        guard now >= browserURLRetryAfter else { return nil }

        let source: String
        switch bundleIdentifier {
        case "com.apple.Safari":
            source = """
            tell application "Safari"
                if (count of windows) is 0 then return ""
                return URL of current tab of front window
            end tell
            """
        case "com.google.Chrome":
            source = """
            tell application "Google Chrome"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        default:
            return nil
        }

        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil, let url = result.stringValue, !url.isEmpty else {
            browserURLRetryAfter = now.addingTimeInterval(browserURLRetryDelay)
            if let error {
                NSLog("TimeBoxer could not read the browser URL: %@", String(describing: error))
            }
            return nil
        }
        browserURLRetryAfter = .distantPast
        return url
    }

    private func replaceActiveBrowserTab(bundleIdentifier: String) {
        guard let replacementURL = WebsiteClassification.safeReplacementURL(
            for: bundleIdentifier
        ) else { return }

        let source: String
        switch bundleIdentifier {
        case "com.apple.Safari":
            source = """
            tell application "Safari"
                if (count of windows) is 0 then return
                set URL of current tab of front window to "\(replacementURL)"
            end tell
            """
        case "com.google.Chrome":
            source = """
            tell application "Google Chrome"
                if (count of windows) is 0 then return
                set URL of active tab of front window to "\(replacementURL)"
            end tell
            """
        default:
            return
        }

        guard let script = NSAppleScript(source: source) else { return }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        if let error {
            NSLog("TimeBoxer could not stop the restricted browser tab: %@", String(describing: error))
        }
    }
}
