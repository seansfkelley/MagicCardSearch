import SwiftUI

// MARK: - RandomCardIntroView

struct RandomCardOnboardingView: View {
    var body: some View {
        ZStack {
            PlaceholderCardView(name: nil, cornerRadius: 16, with: .image("shuffle"))
                .frame(height: 260)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "hand.point.up.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(Color(.systemGray3))
                        .offset(x: 15, y: 30)
                }
                .compositingGroup()
                .rotationEffect(.degrees(-4))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 25) {
                swooshLine(width: 80, height: 24, startThickness: 8, endThickness: 1.5)
                    .offset(x: 10)
                swooshLine(width: 65, height: 20, startThickness: 7, endThickness: 1)
                    .offset(x: 15)
                swooshLine(width: 50, height: 16, startThickness: 6, endThickness: 0.75)
                    .offset(x: 20)
            }
            .rotationEffect(.degrees(2))
            .offset(x: 130, y: -40)

            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.tertiary)
                    .offset(x: 6)

                Text("filter cards")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(-4), anchor: .leading)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 57)

            Text("swipe left to explore")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 60)
        }
    }

    // MARK: - Swoosh

    private func swooshLine(
        width: CGFloat,
        height: CGFloat,
        startThickness: CGFloat,
        endThickness: CGFloat
    ) -> some View {
        TaperedArc(startThickness: startThickness, endThickness: endThickness)
            .fill(Color(.quaternaryLabel))
            .frame(width: width, height: height)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.5),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .padding(.leading, -startThickness)
            }
    }
}

// MARK: - TaperedArc

private struct TaperedArc: Shape {
    var startThickness: CGFloat = 7
    var endThickness: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        let start = CGPoint(x: rect.minX, y: rect.midY)
        let control = CGPoint(x: rect.midX, y: rect.minY)
        let end = CGPoint(x: rect.maxX, y: rect.midY)
        return taperedQuadPath(
            from: start,
            control: control,
            to: end,
            startThickness: startThickness,
            endThickness: endThickness
        )
    }
}

// MARK: - Tapered Path Builders

private func taperedQuadPath(
    from start: CGPoint,
    control: CGPoint,
    to end: CGPoint,
    startThickness: CGFloat,
    endThickness: CGFloat
) -> Path {
    let startHalf = startThickness / 2
    let endHalf = endThickness / 2
    let midHalf = (startHalf + endHalf) / 2

    let nStart = quadDerivative(at: 0, p0: start, p1: control, p2: end).normal
    let nMid = quadDerivative(at: 0.5, p0: start, p1: control, p2: end).normal
    let nEnd = quadDerivative(at: 1, p0: start, p1: control, p2: end).normal

    var path = Path()

    let startAngle = atan2(nStart.y, nStart.x)
    path.addArc(
        center: start,
        radius: startHalf,
        startAngle: .radians(startAngle + .pi),
        endAngle: .radians(startAngle),
        clockwise: true
    )

    path.addQuadCurve(to: end + nEnd * endHalf, control: control + nMid * midHalf)

    let endAngle = atan2(nEnd.y, nEnd.x)
    path.addArc(
        center: end,
        radius: endHalf,
        startAngle: .radians(endAngle),
        endAngle: .radians(endAngle + .pi),
        clockwise: true
    )

    path.addQuadCurve(to: start - nStart * startHalf, control: control - nMid * midHalf)

    path.closeSubpath()
    return path
}

// MARK: - Bezier Helpers

// swiftlint:disable:next identifier_name
private func quadDerivative(at t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
    let dx = 2 * (1 - t) * (p1.x - p0.x) + 2 * t * (p2.x - p1.x)
    let dy = 2 * (1 - t) * (p1.y - p0.y) + 2 * t * (p2.y - p1.y)
    let len = hypot(dx, dy)
    return CGPoint(x: dx / len, y: dy / len)
}

fileprivate extension CGPoint {
    var normal: CGPoint { CGPoint(x: -y, y: x) }

    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}

// MARK: - Preview

#Preview {
    RandomCardOnboardingView()
}
