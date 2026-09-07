import Foundation

@MainActor
final class ParentAppModel: ObservableObject {
    @Published private(set) var snapshot = ParentDashboardSnapshot.preview
    @Published private(set) var pairingSession: PairingSession?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isSavingPolicy = false
    @Published var isPairingPresented = false
    @Published var errorMessage: String?

    private let service: any FamilyCloudService

    init(service: any FamilyCloudService) {
        self.service = service
    }

    var unreadAlertCount: Int {
        snapshot.alerts.filter { !$0.isRead }.count
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            snapshot = try await service.loadDashboard()
            errorMessage = nil
        } catch is CancellationError {
            // SwiftUI cancels refresh tasks when the view moves to the
            // background. That is not a connectivity failure and should not
            // replace a valid dashboard with an alarming offline banner.
            return
        } catch {
            NSLog("TimeBoxer family dashboard refresh failed: %@", String(describing: error))
            errorMessage = "The family service could not be reached. Cached rules remain active on the child’s Mac."
        }
    }

    func resolve(_ request: ExtraTimeRequest, approved: Bool) async {
        do {
            try await service.resolveRequest(id: request.id, approved: approved)
            await refresh()
        } catch {
            errorMessage = "The request could not be updated. Please try again."
        }
    }

    func beginPairing() async {
        do {
            pairingSession = try await service.createPairingSession()
            isPairingPresented = true
        } catch {
            errorMessage = "A pairing code could not be created."
        }
    }

    func selectTodayPlan(_ plan: FamilyDayPlan) async {
        var document = snapshot.policy.document
        document.todayPlan = plan
        document.todayPlanDate = Self.localDateKey(.now)
        await savePolicy(document)
    }

    func setParentBonusMinutes(_ minutes: Int) async {
        var document = snapshot.policy.document
        document.parentBonusMinutes = min(120, max(0, minutes))
        document.parentBonusDate = Self.localDateKey(.now)
        await savePolicy(document)
    }

    func addProtectedDomain(_ rawDomain: String) async {
        let domain = Self.normalizedDomain(rawDomain)
        guard !domain.isEmpty else {
            errorMessage = "Enter a valid website such as youtube.com."
            return
        }
        var document = snapshot.policy.document
        guard !document.protectedDomains.contains(domain) else { return }
        document.protectedDomains.append(domain)
        document.protectedDomains.sort()
        await savePolicy(document)
    }

    func removeProtectedDomain(_ domain: String) async {
        var document = snapshot.policy.document
        document.protectedDomains.removeAll { $0 == domain }
        await savePolicy(document)
    }

    func setApplicationProtected(_ bundleIdentifier: String, isProtected: Bool) async {
        var document = snapshot.policy.document
        var identifiers = Set(document.protectedApplications)
        if isProtected {
            identifiers.insert(bundleIdentifier)
        } else {
            identifiers.remove(bundleIdentifier)
        }
        document.protectedApplications = identifiers.sorted()
        await savePolicy(document)
    }

    private func savePolicy(_ document: FamilyPolicyDocument) async {
        guard !isSavingPolicy else { return }
        isSavingPolicy = true
        defer { isSavingPolicy = false }
        do {
            let saved = try await service.savePolicy(
                FamilyPolicy(revision: snapshot.policy.revision, document: document)
            )
            snapshot.policy = saved
            errorMessage = nil
            await refresh()
        } catch is CancellationError {
            return
        } catch {
            NSLog("TimeBoxer policy save failed: %@", String(describing: error))
            errorMessage = "The family rule could not be saved. Refresh and try again."
        }
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

    private static func normalizedDomain(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "" }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let host = URL(string: candidate)?.host else { return "" }
        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")
        guard domain.rangeOfCharacter(from: allowed.inverted) == nil, domain.contains(".") else { return "" }
        return domain
    }
}
