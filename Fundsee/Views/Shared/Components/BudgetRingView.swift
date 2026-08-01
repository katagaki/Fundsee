import SwiftUI

struct ExtraArc: Equatable {
    var used: Decimal
    var budget: Decimal
    var color: Color = .accentColor
}

struct BudgetRingView: View {
    var used: Decimal
    var budget: Decimal
    var centerCaption: String
    var carryover: Decimal = 0
    var spendPalette: [SpendSlice] = []
    var extraArcs: [ExtraArc] = []

    @Environment(\.colorScheme) private var colorScheme

    private static let showsGuides = UserDefaults.standard.bool(forKey: "ringGuides")

    private var overBudget: Bool { used > budget }
    private var remaining: Decimal { budget - used }

    private var planUsed: Decimal { used - extraArcs.reduce(0) { $0 + $1.used } }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let thickness = size * 0.115

            let cap = (thickness / 2) / (.pi * (size - thickness))

            let corner = thickness * 0.3

            ZStack {
                ForEach(Array(spans(cap: cap).enumerated()), id: \.offset) { _, span in
                    let track = RingSegment(
                        start: span.start,
                        end: span.end,
                        thickness: thickness,
                        cornerRadius: corner
                    )

                    track.fill(Color.gray.opacity(0.2))

                    ZStack {
                        if let carried = span.carried {
                            RingSegment(start: carried, end: span.end, thickness: thickness, cornerRadius: corner)
                                .fill(Color.accentColor.opacity(0.3))
                        }

                        if let filled = span.filled {
                            RingSegment(start: span.start, end: filled, thickness: thickness, cornerRadius: corner)
                                .fill(span.style)
                        }
                    }
                    .clipShape(track)
                }
            }
            .shadow(color: colorScheme == .light ? .black.opacity(0.12) : .clear, radius: 8, y: 3)
            .rotationEffect(.degrees(-90))
            .overlay {
                if Self.showsGuides {
                    ZStack {
                        Circle().stroke(Color.red, lineWidth: 0.5)
                        Circle().inset(by: thickness / 2).stroke(Color.red, lineWidth: 0.5)
                        Circle().inset(by: thickness).stroke(Color.red, lineWidth: 0.5)
                    }
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay {
            VStack(spacing: 4) {
                Text(overBudget ? LocalizedStringKey("Ring.OverBy") : LocalizedStringKey("Ring.Remaining"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text((overBudget ? used - budget : remaining).currencyString)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(overBudget ? .red : .primary)
                    .contentTransition(.numericText())
                Text(centerCaption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .multilineTextAlignment(.center)
        }
    }

    private typealias Span = (start: Double, end: Double, filled: Double?, carried: Double?, style: AnyShapeStyle)

    private func spans(cap: Double) -> [Span] {
        guard budget > 0 else { return [] }

        let extras = extraArcs.filter { $0.budget > 0 }
        let planBudget = budget - extras.reduce(0) { $0 + $1.budget }
        var parts: [(budget: Decimal, used: Decimal, color: Color?, carryover: Decimal)] = []
        if planBudget > 0 {
            parts.append((planBudget, max(0, planUsed), nil, carryover))
        }
        for arc in extras {
            parts.append((arc.budget, arc.used, arc.color, 0))
        }
        guard !parts.isEmpty else { return [] }

        let gap = parts.count > 1 ? 0.007 : 0
        let available = 1 - gap * Double(parts.count)
        let minimum = min(available / Double(parts.count), 4 * cap)
        var widths = parts.map { $0.budget.doubleValue / budget.doubleValue * available }
        let owed = widths.reduce(0) { $0 + max(0, minimum - $1) }
        let spare = widths.reduce(0) { $0 + max(0, $1 - minimum) }
        if owed > 0, spare > 0 {
            let shrink = (spare - owed) / spare
            widths = widths.map { $0 < minimum ? minimum : minimum + ($0 - minimum) * shrink }
        }

        var result: [Span] = []
        var cursor = gap / 2
        for (index, part) in parts.enumerated() {
            let span = widths[index]
            let usedShare = min(1, max(0, part.used.doubleValue / part.budget.doubleValue))
            let carried = max(Decimal(0), min(part.carryover, part.budget - part.used))

            let start = cursor
            let end = cursor + span
            let filled = usedShare > 0 ? min(end, max(start, start + (end - start) * usedShare)) : nil
            let style: AnyShapeStyle
            if part.used > part.budget {
                style = AnyShapeStyle(Color.red)
            } else if let color = part.color {
                style = AnyShapeStyle(color)
            } else {
                style = spentStyle(from: start, to: filled ?? end)
            }
            result.append((
                start: start,
                end: end,
                filled: filled,
                carried: carried > 0
                    ? end - (end - start) * (carried.doubleValue / part.budget.doubleValue)
                    : nil,
                style: style
            ))
            cursor += span + gap
        }
        return result
    }

    private func spentStyle(from start: Double, to end: Double) -> AnyShapeStyle {
        let slices = spendPalette.filter { $0.weight > 0 }
        let total = slices.reduce(0) { $0 + $1.weight }
        guard slices.count > 1, total > 0, end > start else {
            return AnyShapeStyle(slices.first?.color ?? .accentColor)
        }

        var stops: [Gradient.Stop] = []
        var cursor = 0.0
        for slice in slices {
            let share = slice.weight / total
            stops.append(.init(color: slice.color, location: start + (cursor + share / 2) * (end - start)))
            cursor += share
        }
        if let first = stops.first, let last = stops.last {
            stops.insert(.init(color: first.color, location: start), at: 0)
            stops.append(.init(color: last.color, location: end))
            stops.insert(.init(color: first.color, location: 0), at: 0)
            let capOverhang = 0.06
            if end + capOverhang < 1 {
                stops.append(.init(color: last.color, location: end + capOverhang))
                stops.append(.init(color: first.color, location: 1))
            } else {
                stops.append(.init(color: last.color, location: 1))
            }
        }

        return AnyShapeStyle(
            AngularGradient(
                stops: stops,
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )
        )
    }
}

struct RingSegment: Shape {
    var start: Double
    var end: Double
    var thickness: Double
    var cornerRadius: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = max(0, outer - thickness)
        let sweep = (end - start) * 2 * .pi
        guard sweep > 0, inner > 0 else { return path }

        let radius = min(cornerRadius, thickness / 2, sweep * inner / 2)
        let a0 = start * 2 * .pi
        let a1 = end * 2 * .pi
        let outerInset = radius / outer
        let innerInset = radius / inner

        func point(_ r: Double, _ angle: Double) -> CGPoint {
            CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
        }

        path.move(to: point(outer, a0 + outerInset))
        path.addArc(
            center: center,
            radius: outer,
            startAngle: .radians(a0 + outerInset),
            endAngle: .radians(a1 - outerInset),
            clockwise: false
        )
        path.addQuadCurve(to: point(outer - radius, a1), control: point(outer, a1))
        path.addLine(to: point(inner + radius, a1))
        path.addQuadCurve(to: point(inner, a1 - innerInset), control: point(inner, a1))
        path.addArc(
            center: center,
            radius: inner,
            startAngle: .radians(a1 - innerInset),
            endAngle: .radians(a0 + innerInset),
            clockwise: true
        )
        path.addQuadCurve(to: point(inner + radius, a0), control: point(inner, a0))
        path.addLine(to: point(outer - radius, a0))
        path.addQuadCurve(to: point(outer, a0 + outerInset), control: point(outer, a0))
        path.closeSubpath()
        return path
    }
}
