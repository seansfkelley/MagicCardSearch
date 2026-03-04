import SwiftUI

// MARK: - RandomCardIntroView

struct RandomCardIntroView: View {
    var body: some View {
        ZStack {
            CardPlaceholderView(name: nil, cornerRadius: 16)
                .frame(height: 260)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "hand.point.up.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(Color(.quaternaryLabel))
                        .offset(x: 15, y: 30)
                }
                .compositingGroup()
                .rotationEffect(.degrees(-4))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

            VStack(spacing: 20) {
                swooshLine(width: 80, height: 24, startThickness: 8, endThickness: 1.5)
                swooshLine(width: 65, height: 20, startThickness: 7, endThickness: 1)
                swooshLine(width: 50, height: 20, startThickness: 7, endThickness: 1)
            }
            .rotationEffect(.degrees(2))
            .offset(x: 130, y: -40)

            // Squiggly arrow callout
            squiggleCallout
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 16)
                .padding(.top, 8)

            // Bottom text
            Text("swipe left to begin")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 60)
        }
    }

    // MARK: - Swoosh

    private func swooshLine(width: CGFloat, height: CGFloat, startThickness: CGFloat, endThickness: CGFloat) -> some View {
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
                .padding(.leading, -startThickness) // don't clip the round cap
            }
    }

    // MARK: - Squiggle Callout

    private var squiggleCallout: some View {
        VStack(alignment: .leading, spacing: 2) {
            FilterArrow()
                .fill(Color(.quaternaryLabel))
                .frame(width: 70, height: 100)

            Text("filter cards")
                .font(.title3)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(4), anchor: .leading)
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
        return taperedQuadPath(from: start, control: control, to: end,
                               startThickness: startThickness, endThickness: endThickness)
    }
}

// MARK: - FilterArrow

private struct FilterArrow: Shape {
    func path(in rect: CGRect) -> Path {
        // Spine: bottom (thick) to top (thin), S-curve that bows right then sweeps up-left.
        let p0 = CGPoint(x: rect.midX * 0.8, y: rect.maxY)
        let c1 = CGPoint(x: rect.maxX, y: rect.maxY * 0.65)
        let c2 = CGPoint(x: rect.minX, y: rect.maxY * 0.35)
        let p3 = CGPoint(x: rect.midX * 0.7, y: rect.minY + 14)

        var path = taperedCubicPath(from: p0, control1: c1, control2: c2, to: p3,
                                     startThickness: 5, endThickness: 2)

        // Arrowhead: chevron pointing up-left, aligned to tangent at tip
        let tangent = cubicDerivative(at: 1, p0: p0, c1: c1, c2: c2, p3: p3)
        let normal = CGPoint(x: -tangent.y, y: tangent.x)
        let arrowLen: CGFloat = 14
        let arrowSpread: CGFloat = 7

        let tip = CGPoint(x: p3.x + tangent.x * 5, y: p3.y + tangent.y * 5)
        let wing1 = CGPoint(
            x: p3.x - tangent.x * arrowLen + normal.x * arrowSpread,
            y: p3.y - tangent.y * arrowLen + normal.y * arrowSpread
        )
        let wing2 = CGPoint(
            x: p3.x - tangent.x * arrowLen - normal.x * arrowSpread,
            y: p3.y - tangent.y * arrowLen - normal.y * arrowSpread
        )

        path.move(to: tip)
        path.addLine(to: wing1)
        path.addLine(to: p3)
        path.addLine(to: wing2)
        path.closeSubpath()

        return path
    }
}

// MARK: - Tapered Path Builders

private func taperedQuadPath(
    from start: CGPoint, control: CGPoint, to end: CGPoint,
    startThickness: CGFloat, endThickness: CGFloat
) -> Path {
    let startHalf = startThickness / 2
    let endHalf = endThickness / 2
    let midHalf = (startHalf + endHalf) / 2

    let nStart = quadDerivative(at: 0, p0: start, p1: control, p2: end).normal
    let nMid = quadDerivative(at: 0.5, p0: start, p1: control, p2: end).normal
    let nEnd = quadDerivative(at: 1, p0: start, p1: control, p2: end).normal

    var path = Path()

    let startAngle = atan2(nStart.y, nStart.x)
    path.addArc(center: start, radius: startHalf,
                startAngle: .radians(startAngle + .pi), endAngle: .radians(startAngle), clockwise: true)

    path.addQuadCurve(to: end + nEnd * endHalf, control: control + nMid * midHalf)

    let endAngle = atan2(nEnd.y, nEnd.x)
    path.addArc(center: end, radius: endHalf,
                startAngle: .radians(endAngle), endAngle: .radians(endAngle + .pi), clockwise: true)

    path.addQuadCurve(to: start - nStart * startHalf, control: control - nMid * midHalf)

    path.closeSubpath()
    return path
}

private func taperedCubicPath(
    from p0: CGPoint, control1 c1: CGPoint, control2 c2: CGPoint, to p3: CGPoint,
    startThickness: CGFloat, endThickness: CGFloat
) -> Path {
    let startHalf = startThickness / 2
    let endHalf = endThickness / 2

    let n0 = cubicDerivative(at: 0, p0: p0, c1: c1, c2: c2, p3: p3).normal
    let nA = cubicDerivative(at: 0.33, p0: p0, c1: c1, c2: c2, p3: p3).normal
    let nB = cubicDerivative(at: 0.67, p0: p0, c1: c1, c2: c2, p3: p3).normal
    let n1 = cubicDerivative(at: 1, p0: p0, c1: c1, c2: c2, p3: p3).normal

    let halfA = startHalf + (endHalf - startHalf) * 0.33
    let halfB = startHalf + (endHalf - startHalf) * 0.67

    var path = Path()

    let startAngle = atan2(n0.y, n0.x)
    path.addArc(center: p0, radius: startHalf,
                startAngle: .radians(startAngle), endAngle: .radians(startAngle + .pi), clockwise: true)

    path.addCurve(to: p3 - n1 * endHalf, control1: c1 - nA * halfA, control2: c2 - nB * halfB)

    let endAngle = atan2(n1.y, n1.x)
    path.addArc(center: p3, radius: endHalf,
                startAngle: .radians(endAngle + .pi), endAngle: .radians(endAngle), clockwise: true)

    path.addCurve(to: p0 + n0 * startHalf, control1: c2 + nB * halfB, control2: c1 + nA * halfA)

    path.closeSubpath()
    return path
}

// MARK: - Bezier Derivatives

// swiftlint:disable identifier_name

/// Returns the unit tangent of a quadratic bezier at parameter `t`.
private func quadDerivative(at t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
    let dx = 2 * (1 - t) * (p1.x - p0.x) + 2 * t * (p2.x - p1.x)
    let dy = 2 * (1 - t) * (p1.y - p0.y) + 2 * t * (p2.y - p1.y)
    let len = hypot(dx, dy)
    return CGPoint(x: dx / len, y: dy / len)
}

/// Returns the unit tangent of a cubic bezier at parameter `t`.
private func cubicDerivative(at t: CGFloat, p0: CGPoint, c1: CGPoint, c2: CGPoint, p3: CGPoint) -> CGPoint {
    let mt = 1 - t
    let dx = 3 * mt * mt * (c1.x - p0.x) + 6 * mt * t * (c2.x - c1.x) + 3 * t * t * (p3.x - c2.x)
    let dy = 3 * mt * mt * (c1.y - p0.y) + 6 * mt * t * (c2.y - c1.y) + 3 * t * t * (p3.y - c2.y)
    let len = hypot(dx, dy)
    return CGPoint(x: dx / len, y: dy / len)
}

// swiftlint:enable identifier_name

// MARK: - CGPoint Helpers

private extension CGPoint {
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
    RandomCardIntroView()
}
