import SwiftUI

struct TimeBoxerBrand: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 10 : 13) {
            TimeBoxerCubeMark(size: compact ? 42 : 50)
            HStack(spacing: 0) {
                Text("TIME")
                    .foregroundStyle(
                        .linearGradient(
                            colors: [
                                Color(red: 0.66, green: 0.68, blue: 0.71),
                                Color(red: 0.22, green: 0.24, blue: 0.28),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text("BOXER")
                    .foregroundStyle(TimeBoxerColors.green)
            }
            .font(.system(size: compact ? 23 : 28, weight: .black, design: .default))
            .italic()
            .tracking(compact ? -1.4 : -1.8)
        }
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("TimeBoxer")
    }
}

struct TimeBoxerCubeMark: View {
    let size: CGFloat

    var body: some View {
        TimeBoxerCubeShape()
            .stroke(
                TimeBoxerColors.green,
                style: StrokeStyle(
                    lineWidth: size * 0.067,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        .frame(width: size, height: size)
    }
}

private struct TimeBoxerCubeShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x / 48, y: rect.minY + rect.height * y / 48)
        }

        var path = Path()
        path.move(to: point(24, 4))
        path.addLine(to: point(42, 14.5))
        path.addLine(to: point(42, 33.5))
        path.addLine(to: point(24, 44))
        path.addLine(to: point(6, 33.5))
        path.addLine(to: point(6, 14.5))
        path.closeSubpath()

        path.move(to: point(6.8, 14.8))
        path.addLine(to: point(24, 24.8))
        path.addLine(to: point(41.2, 14.8))

        path.move(to: point(24, 24.8))
        path.addLine(to: point(24, 44))
        return path
    }
}

enum TimeBoxerColors {
    static let green = Color(red: 0.13, green: 0.93, blue: 0.16)
    static let dark = Color(red: 0.035, green: 0.045, blue: 0.09)
    static let background = Color(red: 0.973, green: 0.98, blue: 0.973)
    static let violet = Color(red: 0.43, green: 0.33, blue: 0.94)
}
