import SwiftUI

struct ParentDashboardView: View {
    @EnvironmentObject private var model: ParentAppModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if let message = model.errorMessage {
                    offlineMessage(message)
                }

                deviceStatusCard

                if let request = model.snapshot.pendingRequests.first {
                    requestCard(request)
                }

                if let alert = model.snapshot.alerts.first(where: { !$0.isRead }) {
                    alertCard(alert)
                }

                todayCard
                commonActions
                oneTimeSetup
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(TimeBoxerColors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TimeBoxerBrand(compact: true)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(.primary)
                        if model.unreadAlertCount > 0 {
                            Text("\(model.unreadAlertCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(.red, in: Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                .accessibilityLabel("\(model.unreadAlertCount) unread alerts")
            }
        }
        .refreshable {
            await model.refresh()
        }
    }

    private var deviceStatusCard: some View {
        let device = model.snapshot.device
        return VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(device.childName)’s Mac")
                        .font(.title2.bold())
                    Text(device.deviceName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label(device.state.isOnline ? "Online" : "Offline", systemImage: "circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(device.state.isOnline ? Color.green : Color.red)
            }

            HStack(spacing: 12) {
                Image(systemName: device.state.isOnline ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(TimeBoxerColors.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.currentActivity)
                        .font(.headline)
                    Text(device.state.isOnline ? "Protection is active" : "Using the last downloaded family rules")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .timeBoxerCard()
    }

    private func requestCard(_ request: ExtraTimeRequest) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Extra time request", systemImage: "hand.raised.fill")
                .font(.headline)
                .foregroundStyle(TimeBoxerColors.violet)
            Text("\(request.childName) is asking for \(request.minutes) more minutes.")
                .font(.title3.bold())
            HStack(spacing: 10) {
                Button("Not now", role: .cancel) {
                    Task { await model.resolve(request, approved: false) }
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button("Approve +\(request.minutes)") {
                    Task { await model.resolve(request, approved: true) }
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
        .timeBoxerCard(border: TimeBoxerColors.violet.opacity(0.25))
    }

    private func alertCard(_ alert: FamilyAlert) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Blocked activity", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            Text(alert.title)
                .font(.title3.bold())
            Text(alert.detail)
                .font(.subheadline)
                .opacity(0.85)
        }
        .foregroundStyle(Color.red)
        .timeBoxerCard(background: Color.red.opacity(0.07), border: Color.red.opacity(0.25))
    }

    private var todayCard: some View {
        let device = model.snapshot.device
        let progress = device.dailyLimit == 0 ? 0 : Double(device.usedMinutes) / Double(device.dailyLimit)
        return VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today")
                        .font(.headline)
                    Text("School day plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(device.availableMinutes) min left")
                    .font(.headline)
                    .foregroundStyle(TimeBoxerColors.green)
            }
            ProgressView(value: progress)
                .tint(TimeBoxerColors.green)
            Text("\(device.usedMinutes) of \(device.dailyLimit) entertainment minutes used")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .timeBoxerCard()
    }

    private var commonActions: some View {
        DisclosureGroup {
            VStack(spacing: 0) {
                settingsRow("Change today’s plan", icon: "calendar")
                Divider()
                settingsRow("Adjust available time", icon: "clock.badge.plus")
                Divider()
                settingsRow("Protected apps and websites", icon: "shield.lefthalf.filled")
            }
            .padding(.top, 10)
        } label: {
            Label("Common controls", systemImage: "slider.horizontal.3")
                .font(.headline)
        }
        .timeBoxerCard()
    }

    private var oneTimeSetup: some View {
        DisclosureGroup {
            VStack(spacing: 0) {
                Button {
                    Task { await model.beginPairing() }
                } label: {
                    settingsRow("Pair a child Mac", icon: "laptopcomputer.and.iphone")
                }
                .buttonStyle(.plain)
                Divider()
                settingsRow("Family profile", icon: "person.2.fill")
                Divider()
                settingsRow("Subscription", icon: "creditcard.fill")
            }
            .padding(.top, 10)
        } label: {
            Label("Family and account", systemImage: "gearshape.fill")
                .font(.headline)
        }
        .timeBoxerCard()
    }

    private func settingsRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(TimeBoxerColors.green)
            Text(title)
                .font(.subheadline.bold())
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 12)
    }

    private func offlineMessage(_ message: String) -> some View {
        Label(message, systemImage: "wifi.exclamationmark")
            .font(.caption)
            .foregroundStyle(Color.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .timeBoxerCard(background: Color.orange.opacity(0.08), border: Color.orange.opacity(0.2))
    }
}

private extension View {
    func timeBoxerCard(
        background: Color = .white,
        border: Color = Color.gray.opacity(0.14)
    ) -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(border, lineWidth: 1)
            }
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(TimeBoxerColors.dark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(TimeBoxerColors.green.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(configuration.isPressed ? 0.18 : 0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}
