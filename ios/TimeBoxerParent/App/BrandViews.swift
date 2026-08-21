import SwiftUI

struct TimeBoxerBrand: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            TimeBoxerCubeMark(size: compact ? 32 : 38)
            HStack(spacing: 0) {
                Text("TIME")
                    .foregroundStyle(.primary)
                Text("BOXER")
                    .foregroundStyle(TimeBoxerColors.green)
            }
            .font(.system(size: compact ? 16 : 19, weight: .black, design: .rounded))
            .italic()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("TimeBoxer")
    }
}

struct TimeBoxerCubeMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Color(red: 0.035, green: 0.045, blue: 0.055))

            Image(systemName: "cube.transparent")
                .font(.system(size: size * 0.58, weight: .bold))
                .foregroundStyle(TimeBoxerColors.green)
        }
        .frame(width: size, height: size)
    }
}

enum TimeBoxerColors {
    static let green = Color(red: 0.13, green: 0.93, blue: 0.16)
    static let dark = Color(red: 0.035, green: 0.045, blue: 0.09)
    static let background = Color(red: 0.973, green: 0.98, blue: 0.973)
    static let violet = Color(red: 0.43, green: 0.33, blue: 0.94)
}
