import Foundation

@MainActor
final class ParentAppModel: ObservableObject {
    @Published private(set) var snapshot = ParentDashboardSnapshot.preview
    @Published private(set) var pairingSession: PairingSession?
    @Published private(set) var isRefreshing = false
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
        } catch {
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
}
