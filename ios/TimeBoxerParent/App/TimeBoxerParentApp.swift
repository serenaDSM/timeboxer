import SwiftUI

@main
struct TimeBoxerParentApp: App {
    @StateObject private var model = ParentAppModel(service: PreviewFamilyCloudService())

    var body: some Scene {
        WindowGroup {
            ParentRootView()
                .environmentObject(model)
                .preferredColorScheme(.light)
        }
    }
}

private struct ParentRootView: View {
    @EnvironmentObject private var model: ParentAppModel

    var body: some View {
        NavigationStack {
            ParentDashboardView()
        }
        .task {
            await model.refresh()
        }
        .sheet(isPresented: $model.isPairingPresented) {
            PairChildMacView()
                .environmentObject(model)
        }
    }
}
