import SwiftUI

struct PairChildMacView: View {
    @EnvironmentObject private var model: ParentAppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TimeBoxerCubeMark(size: 64)

                VStack(spacing: 7) {
                    Text("Pair a child Mac")
                        .font(.title2.bold())
                    Text("Open TimeBoxer Child on the Mac and enter this one-time code. It expires after 10 minutes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let session = model.pairingSession {
                    Text(formattedCode(session.code))
                        .font(.system(size: 38, weight: .black, design: .monospaced))
                        .tracking(5)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .background(TimeBoxerColors.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
                        .accessibilityLabel("Pairing code \(session.code)")

                    Text("The Mac will appear here after you approve the connection.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView("Creating a secure code…")
                }

                Spacer()
            }
            .padding(24)
            .background(TimeBoxerColors.background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func formattedCode(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }
}
