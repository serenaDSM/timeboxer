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
                NavigationLink {
                    ParentAlertsView(alerts: model.snapshot.alerts)
                } label: {
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
                    Text("\(model.snapshot.currentDayPlan.title) plan")
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
                NavigationLink {
                    TodayPlanSettingsView()
                } label: {
                    settingsRow("Change today’s plan", icon: "calendar")
                }
                .buttonStyle(.plain)
                Divider()
                NavigationLink {
                    AvailableTimeSettingsView()
                } label: {
                    settingsRow("Adjust available time", icon: "clock.badge.plus")
                }
                .buttonStyle(.plain)
                Divider()
                NavigationLink {
                    ProtectionSettingsView()
                } label: {
                    settingsRow("Protected apps and websites", icon: "shield.lefthalf.filled")
                }
                .buttonStyle(.plain)
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
                NavigationLink {
                    FamilyProfileView(device: model.snapshot.device)
                } label: {
                    settingsRow("Family profile", icon: "person.2.fill")
                }
                .buttonStyle(.plain)
                Divider()
                NavigationLink {
                    SubscriptionView()
                } label: {
                    settingsRow("Subscription", icon: "creditcard.fill")
                }
                .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "wifi.exclamationmark")
                .font(.caption)
                .foregroundStyle(Color.orange)
            Button {
                Task { await model.refresh() }
            } label: {
                Label(model.isRefreshing ? "Refreshing…" : "Try again", systemImage: "arrow.clockwise")
                    .font(.caption.bold())
            }
            .disabled(model.isRefreshing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .timeBoxerCard(background: Color.orange.opacity(0.08), border: Color.orange.opacity(0.2))
    }
}

private struct TodayPlanSettingsView: View {
    @EnvironmentObject private var model: ParentAppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                settingsStatus(
                    title: "Current plan",
                    detail: "\(model.snapshot.currentDayPlan.title) · \(model.snapshot.device.dailyLimit) entertainment minutes",
                    icon: "calendar.badge.checkmark"
                )
                planCard(.school, detail: "Short and predictable for learning days")
                planCard(.weekend, detail: "A little more flexibility with the same boundaries")
                planCard(.holiday, detail: "The most flexible built-in family template")
                cloudWriteNote("This choice applies to today and is saved to the TimeBoxer cloud. The child Mac will use it after policy download is connected.")
            }
            .padding(16)
        }
        .background(TimeBoxerColors.background)
        .navigationTitle("Today’s plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func planCard(_ plan: FamilyDayPlan, detail: String) -> some View {
        let selected = model.snapshot.currentDayPlan == plan
        let minutes = model.snapshot.policy.document.dayPlans[plan].baseMinutes
        return Button {
            Task { await model.selectTodayPlan(plan) }
        } label: {
            HStack(spacing: 13) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? TimeBoxerColors.green : Color.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title).font(.headline).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(minutes) min").font(.headline).foregroundStyle(TimeBoxerColors.green)
            }
            .timeBoxerCard(border: selected ? TimeBoxerColors.green.opacity(0.45) : Color.black.opacity(0.08))
        }
        .buttonStyle(.plain)
        .disabled(model.isSavingPolicy)
    }
}

private struct AvailableTimeSettingsView: View {
    @EnvironmentObject private var model: ParentAppModel
    @State private var bonusMinutes = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                settingsStatus(
                    title: "\(model.snapshot.device.availableMinutes) minutes available",
                    detail: "\(model.snapshot.policy.document.dayPlans[model.snapshot.currentDayPlan].baseMinutes) base minutes · \(model.snapshot.device.usedMinutes) used today",
                    icon: "clock.badge.checkmark"
                )
                VStack(alignment: .leading, spacing: 16) {
                    Text("Parent extra time").font(.headline)
                    Stepper(value: $bonusMinutes, in: 0...120, step: 5) {
                        Text("+\(bonusMinutes) minutes today")
                            .font(.title3.bold())
                            .foregroundStyle(TimeBoxerColors.green)
                    }
                    HStack(spacing: 8) {
                        ForEach([0, 5, 10, 20], id: \.self) { minutes in
                            Button(minutes == 0 ? "Reset" : "+\(minutes)") {
                                bonusMinutes = minutes
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    Button(model.isSavingPolicy ? "Saving…" : "Save for today") {
                        Task { await model.setParentBonusMinutes(bonusMinutes) }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(model.isSavingPolicy)
                }
                .timeBoxerCard()
                cloudWriteNote("Extra time is stored separately from the base plan and expires at the end of today.")
            }
            .padding(16)
        }
        .background(TimeBoxerColors.background)
        .navigationTitle("Available time")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            bonusMinutes = model.snapshot.policy.document.parentBonusMinutes ?? 0
        }
    }
}

private struct ProtectionSettingsView: View {
    @EnvironmentObject private var model: ParentAppModel
    @State private var domain = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                settingsStatus(
                    title: "Protection configured",
                    detail: "The paired Mac keeps enforcing its last downloaded family rules.",
                    icon: "checkmark.shield.fill"
                )
                protectionCard("Applications", detail: "Games and entertainment apps detected on the child Mac", icon: "square.grid.2x2")
                VStack(alignment: .leading, spacing: 12) {
                    Label("Websites", systemImage: "globe")
                        .font(.headline)
                        .foregroundStyle(TimeBoxerColors.green)
                    HStack {
                        TextField("youtube.com", text: $domain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            let value = domain
                            domain = ""
                            Task { await model.addProtectedDomain(value) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TimeBoxerColors.green)
                        .disabled(domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSavingPolicy)
                    }
                    if model.snapshot.policy.document.protectedDomains.isEmpty {
                        Text("No custom websites yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.snapshot.policy.document.protectedDomains, id: \.self) { protectedDomain in
                            HStack {
                                Text(protectedDomain).font(.subheadline)
                                Spacer()
                                Button(role: .destructive) {
                                    Task { await model.removeProtectedDomain(protectedDomain) }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .disabled(model.isSavingPolicy)
                            }
                            Divider()
                        }
                    }
                }
                .timeBoxerCard()
                cloudWriteNote("Website changes now save to the cloud. Detected Mac applications will become editable after the device uploads its app inventory in the next sync step.")
            }
            .padding(16)
        }
        .background(TimeBoxerColors.background)
        .navigationTitle("Apps and websites")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func protectionCard(_ title: String, detail: String, icon: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(TimeBoxerColors.green)
        }
        .timeBoxerCard()
    }
}

private struct FamilyProfileView: View {
    let device: ChildDeviceSummary

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                settingsStatus(title: device.childName, detail: "Child profile", icon: "person.crop.circle.fill")
                settingsStatus(title: device.deviceName, detail: "Paired child Mac", icon: "laptopcomputer")
                cloudWriteNote("Profile editing will be enabled together with family policy sync. The information shown above is already loaded from the TimeBoxer cloud.")
            }
            .padding(16)
        }
        .background(TimeBoxerColors.background)
        .navigationTitle("Family profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SubscriptionView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                settingsStatus(title: "Pilot plan", detail: "Active for this test family", icon: "checkmark.seal.fill")
                cloudWriteNote("Billing is not active during the private pilot. Subscription choices will be connected before public release.")
            }
            .padding(16)
        }
        .background(TimeBoxerColors.background)
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ParentAlertsView: View {
    let alerts: [FamilyAlert]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if alerts.isEmpty {
                    settingsStatus(title: "No recent alerts", detail: "Blocked activity and requests will appear here.", icon: "bell.badge")
                } else {
                    ForEach(alerts) { alert in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(alert.title).font(.headline)
                            Text(alert.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .timeBoxerCard()
                    }
                }
            }
            .padding(16)
        }
        .background(TimeBoxerColors.background)
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func settingsStatus(title: String, detail: String, icon: String) -> some View {
    HStack(spacing: 13) {
        Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(TimeBoxerColors.green)
            .frame(width: 30)
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
    }
    .timeBoxerCard()
}

private func cloudWriteNote(_ text: String) -> some View {
    Label(text, systemImage: "info.circle.fill")
        .font(.caption)
        .foregroundStyle(.secondary)
        .timeBoxerCard(background: Color.blue.opacity(0.05), border: Color.blue.opacity(0.12))
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
