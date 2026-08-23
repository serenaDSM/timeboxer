import SwiftUI

@main
struct TimeBoxerParentApp: App {
    @StateObject private var authentication = AuthenticationModel()
    @StateObject private var model = ParentAppModel(service: SupabaseFamilyCloudService())

    var body: some Scene {
        WindowGroup {
            ParentAppRootView()
                .environmentObject(authentication)
                .environmentObject(model)
                .preferredColorScheme(.light)
        }
    }
}

private struct ParentAppRootView: View {
    @EnvironmentObject private var authentication: AuthenticationModel

    var body: some View {
        Group {
            switch authentication.state {
            case .loading:
                ZStack {
                    TimeBoxerColors.background.ignoresSafeArea()
                    ProgressView("Connecting to TimeBoxer…")
                }
            case .signedOut:
                ParentAuthView()
            case .signedIn:
                ParentRootView()
            }
        }
        .task {
            if authentication.state == .loading {
                await authentication.restoreSession()
            }
        }
    }
}

private struct ParentRootView: View {
    @EnvironmentObject private var authentication: AuthenticationModel
    @EnvironmentObject private var model: ParentAppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ParentDashboardView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Sign out") {
                            Task { await authentication.signOut() }
                        }
                    }
                }
        }
        .task {
            await model.refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await model.refresh() }
        }
        .sheet(isPresented: $model.isPairingPresented) {
            PairChildMacView()
                .environmentObject(model)
        }
    }
}
