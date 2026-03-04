import SwiftUI
import ScryfallKit

// MARK: - RandomCardIntroView

struct RandomCardIntroView: View {
    var body: some View {
        ZStack {
            // Card + swooshes in the center
            cardAndSwooshes
                .offset(y: -20)

            // Squiggly arrow callout in the top-leading area
            squiggleCallout
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 24)
                .padding(.top, 16)

            // "swipe to begin" at the bottom
            Text("swipe to begin")
                .font(.subheadline)
                .foregroundStyle(.quaternary)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 60)
        }
    }

    // MARK: - Card + Swooshes

    private var cardAndSwooshes: some View {
        HStack(spacing: 0) {
            // The card
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray5))
                .aspectRatio(Card.aspectRatio, contentMode: .fit)
                .frame(height: 260)
                .overlay {
                    Image(systemName: "hand.point.up")
                        .font(.system(size: 44))
                        .foregroundStyle(.quaternary)
                        .offset(y: 20)
                }
                .rotationEffect(.degrees(-4))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

            // Swoosh motion lines
            VStack(spacing: 12) {
                TaperedArc(startThickness: 7, endThickness: 1)
                    .fill(Color(.quaternaryLabel))
                    .frame(width: 50, height: 20)

                TaperedArc(startThickness: 8, endThickness: 1.5)
                    .fill(Color(.quaternaryLabel))
                    .frame(width: 60, height: 24)

                TaperedArc(startThickness: 7, endThickness: 1)
                    .fill(Color(.quaternaryLabel))
                    .frame(width: 50, height: 20)
            }
            .offset(x: -8, y: -10)
        }
    }

    // MARK: - Squiggle Callout

    private var squiggleCallout: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Arrowhead + squiggle body
            TaperedSquiggle(startThickness: 5, endThickness: 1.5)
                .fill(Color(.quaternaryLabel))
                .frame(width: 40, height: 80)
                .overlay(alignment: .top) {
                    Arrowhead()
                        .fill(Color(.quaternaryLabel))
                        .frame(width: 12, height: 10)
                        .offset(y: -4)
                }

            Text("filter cards here")
                .font(.subheadline)
                .foregroundStyle(.quaternary)
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
            center: start, radius: startHalf,
            startAngle: startAngle + .degrees(180),
            endAngle: startAngle, clockwise: true
        )

        // Outer edge
        path.addQuadCurve(
            to: end.offset(by: nEnd, scale: endHalf),
            control: control.offset(by: nMid, scale: midHalf)
        )

        // Thin end cap
        let endAngle = Angle(radians: atan2(nEnd.y, nEnd.x))
        path.addArc(
            center: end, radius: endHalf,
            startAngle: endAngle,
            endAngle: endAngle + .degrees(180), clockwise: true
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

// MARK: - TaperedSquiggle

private struct TaperedSquiggle: Shape {
    var startThickness: CGFloat = 5
    var endThickness: CGFloat = 1.5

    func path(in rect: CGRect) -> Path {
        // Spine goes from bottom (thick) to top (thin)
        let p0 = CGPoint(x: rect.midX * 0.9, y: rect.maxY)
        let c1 = CGPoint(x: rect.maxX * 1.1, y: rect.maxY * 0.6)
        let c2 = CGPoint(x: rect.minX - rect.width * 0.1, y: rect.maxY * 0.3)
        let p3 = CGPoint(x: rect.midX, y: rect.minY)

        let startHalf = startThickness / 2
        let endHalf = endThickness / 2

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
            center: p0, radius: startHalf,
            startAngle: startAngle,
            endAngle: startAngle + .degrees(180), clockwise: true
        )

        // Inner edge (left side going up)
        path.addCurve(
            to: p3.offset(by: n1, scale: -endHalf),
            control1: c1.offset(by: nA, scale: -halfA),
            control2: c2.offset(by: nB, scale: -halfB)
        )

        // Thin end cap (top)
        let endAngle = Angle(radians: atan2(n1.y, n1.x))
        path.addArc(
            center: p3, radius: endHalf,
            startAngle: endAngle + .degrees(180),
            endAngle: endAngle, clockwise: true
        )

        // Outer edge (right side going down)
        path.addCurve(
            to: p0.offset(by: n0, scale: startHalf),
            control1: c2.offset(by: nB, scale: halfB),
            control2: c1.offset(by: nA, scale: halfA)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Arrowhead

private struct Arrowhead: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Bezier Helpers

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

private extension CGPoint {
    func offset(by normal: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: x + normal.x * scale, y: y + normal.y * scale)
    }
}

// MARK: - Preview

#Preview {
    RandomCardIntroView()
}
