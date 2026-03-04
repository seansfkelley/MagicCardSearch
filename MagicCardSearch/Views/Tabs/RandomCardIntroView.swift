import SwiftUI

// MARK: - RandomCardIntroView

struct RandomCardIntroView: View {
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                CardPlaceholderView(name: nil, cornerRadius: 16)
                    .frame(height: 260)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "hand.point.up.fill")
                            .font(.system(size: 100))
                            .foregroundStyle(.tertiary)
                            .offset(x: 15, y: 30)
                    }
                    .rotationEffect(.degrees(-4))
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

                // Swoosh motion lines
                VStack(spacing: 20) {
                    swooshLine(width: 60, height: 24, startThickness: 8, endThickness: 1.5)
                    swooshLine(width: 50, height: 20, startThickness: 7, endThickness: 1)
                    swooshLine(width: 40, height: 20, startThickness: 7, endThickness: 1)
                }
                .offset(x: 8, y: -10)
            }

            squiggleCallout
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 16)
                .padding(.top, 8)

            Text("swipe left to begin")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 80)
        }
    }

    // MARK: - Card + Swooshes

    private func swooshLine(width: CGFloat, height: CGFloat, startThickness: CGFloat, endThickness: CGFloat) -> some View {
        TaperedArc(startThickness: startThickness, endThickness: endThickness)
            .fill(Color(.quaternaryLabel))
            .frame(width: width, height: height)
            .mask {
                LinearGradient(
                    colors: [.white, .white, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
    }

    // MARK: - Squiggle Callout

    private var squiggleCallout: some View {
        VStack(alignment: .leading, spacing: 2) {
            FilterArrow()
                .fill(Color(.quaternaryLabel))
                .frame(width: 60, height: 100)

            Text("filter cards here")
                .font(.title3)
                .foregroundStyle(.secondary)
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

        let startHalf = startThickness / 2
        let endHalf = endThickness / 2

        let nStart = quadNormal(at: 0, p0: start, p1: control, p2: end)
        let nEnd = quadNormal(at: 1, p0: start, p1: control, p2: end)
        let nMid = quadNormal(at: 0.5, p0: start, p1: control, p2: end)
        let midHalf = (startHalf + endHalf) / 2

        var path = Path()

        // Thick end cap
        let startAngle = Angle(radians: atan2(nStart.y, nStart.x))
        path.addArc(
            center: start,
            radius: startHalf,
            startAngle: startAngle + .degrees(180),
            endAngle: startAngle,
            clockwise: true
        )

        // Outer edge
        path.addQuadCurve(
            to: end.offset(by: nEnd, scale: endHalf),
            control: control.offset(by: nMid, scale: midHalf)
        )

        // Thin end cap
        let endAngle = Angle(radians: atan2(nEnd.y, nEnd.x))
        path.addArc(
            center: end,
            radius: endHalf,
            startAngle: endAngle,
            endAngle: endAngle + .degrees(180),
            clockwise: true
        )

        // Inner edge (back)
        path.addQuadCurve(
            to: start.offset(by: nStart, scale: -startHalf),
            control: control.offset(by: nMid, scale: -midHalf)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - FilterArrow

private struct FilterArrow: Shape {
    func path(in rect: CGRect) -> Path {
        // Spine: starts at bottom-center (thick), curves up and left to top-left (thin).
        // Single cubic bezier that bows out to the right before curving up-left.
        let p0 = CGPoint(x: rect.midX, y: rect.maxY)
        let c1 = CGPoint(x: rect.maxX * 0.95, y: rect.maxY * 0.55)
        let c2 = CGPoint(x: rect.maxX * 0.6, y: rect.maxY * 0.15)
        let p3 = CGPoint(x: rect.midX * 0.5, y: rect.minY + 12)

        let startHalf: CGFloat = 2.5
        let endHalf: CGFloat = 1

        let n0 = cubicNormal(at: 0, p0: p0, c1: c1, c2: c2, p3: p3)
        let n1 = cubicNormal(at: 1, p0: p0, c1: c1, c2: c2, p3: p3)
        let nA = cubicNormal(at: 0.33, p0: p0, c1: c1, c2: c2, p3: p3)
        let nB = cubicNormal(at: 0.67, p0: p0, c1: c1, c2: c2, p3: p3)
        let halfA = startHalf + (endHalf - startHalf) * 0.33
        let halfB = startHalf + (endHalf - startHalf) * 0.67

        var path = Path()

        // Thick end cap (bottom)
        let startAngle = Angle(radians: atan2(n0.y, n0.x))
        path.addArc(
            center: p0,
            radius: startHalf,
            startAngle: startAngle,
            endAngle: startAngle + .degrees(180),
            clockwise: true
        )

        // Inner edge
        path.addCurve(
            to: p3.offset(by: n1, scale: -endHalf),
            control1: c1.offset(by: nA, scale: -halfA),
            control2: c2.offset(by: nB, scale: -halfB)
        )

        // Thin end cap (top)
        let endAngle = Angle(radians: atan2(n1.y, n1.x))
        path.addArc(
            center: p3,
            radius: endHalf,
            startAngle: endAngle + .degrees(180),
            endAngle: endAngle,
            clockwise: true
        )

        // Outer edge
        path.addCurve(
            to: p0.offset(by: n0, scale: startHalf),
            control1: c2.offset(by: nB, scale: halfB),
            control2: c1.offset(by: nA, scale: halfA)
        )

        path.closeSubpath()

        // Arrowhead at the tip
        let tangent = cubicTangent(at: 1, p0: p0, c1: c1, c2: c2, p3: p3)
        let arrowSize: CGFloat = 10
        let arrowSpread: CGFloat = 5

        let tipX = p3.x + tangent.x * 4
        let tipY = p3.y + tangent.y * 4
        let tip = CGPoint(x: tipX, y: tipY)
        let leftWing = CGPoint(
            x: p3.x - tangent.x * arrowSize + n1.x * arrowSpread,
            y: p3.y - tangent.y * arrowSize + n1.y * arrowSpread
        )
        let rightWing = CGPoint(
            x: p3.x - tangent.x * arrowSize - n1.x * arrowSpread,
            y: p3.y - tangent.y * arrowSize - n1.y * arrowSpread
        )

        path.move(to: tip)
        path.addLine(to: leftWing)
        path.addLine(to: rightWing)
        path.closeSubpath()

        return path
    }
}

// MARK: - Bezier Helpers

// swiftlint:disable identifier_name

private func quadNormal(at t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
    let dt: CGFloat = 0.001
    let a = quadBezier(t: max(0, t - dt), p0: p0, p1: p1, p2: p2)
    let b = quadBezier(t: min(1, t + dt), p0: p0, p1: p1, p2: p2)
    let dx = b.x - a.x
    let dy = b.y - a.y
    let len = hypot(dx, dy)
    return CGPoint(x: -dy / len, y: dx / len)
}

private func quadBezier(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
    let mt = 1 - t
    return CGPoint(
        x: mt * mt * p0.x + 2 * mt * t * p1.x + t * t * p2.x,
        y: mt * mt * p0.y + 2 * mt * t * p1.y + t * t * p2.y
    )
}

private func cubicTangent(at t: CGFloat, p0: CGPoint, c1: CGPoint, c2: CGPoint, p3: CGPoint) -> CGPoint {
    let dt: CGFloat = 0.001
    let a = cubicBezier(t: max(0, t - dt), p0: p0, c1: c1, c2: c2, p3: p3)
    let b = cubicBezier(t: min(1, t + dt), p0: p0, c1: c1, c2: c2, p3: p3)
    let dx = b.x - a.x
    let dy = b.y - a.y
    let len = hypot(dx, dy)
    return CGPoint(x: dx / len, y: dy / len)
}

private func cubicNormal(at t: CGFloat, p0: CGPoint, c1: CGPoint, c2: CGPoint, p3: CGPoint) -> CGPoint {
    let dt: CGFloat = 0.001
    let a = cubicBezier(t: max(0, t - dt), p0: p0, c1: c1, c2: c2, p3: p3)
    let b = cubicBezier(t: min(1, t + dt), p0: p0, c1: c1, c2: c2, p3: p3)
    let dx = b.x - a.x
    let dy = b.y - a.y
    let len = hypot(dx, dy)
    return CGPoint(x: -dy / len, y: dx / len)
}

private func cubicBezier(t: CGFloat, p0: CGPoint, c1: CGPoint, c2: CGPoint, p3: CGPoint) -> CGPoint {
    let mt = 1 - t
    return CGPoint(
        x: mt * mt * mt * p0.x + 3 * mt * mt * t * c1.x + 3 * mt * t * t * c2.x + t * t * t * p3.x,
        y: mt * mt * mt * p0.y + 3 * mt * mt * t * c1.y + 3 * mt * t * t * c2.y + t * t * t * p3.y
    )
}

// swiftlint:enable identifier_name

private extension CGPoint {
    func offset(by normal: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: x + normal.x * scale, y: y + normal.y * scale)
    }
}

// MARK: - Preview

#Preview {
    RandomCardIntroView()
}
