import SwiftUI

/// Spending against an overall budget, drawn as its own segment of the ring.
struct ExtraArc: Equatable {
    var used: Decimal
    var budget: Decimal
    var color: Color = .accentColor
}

/// Donut gauge showing used vs. remaining budget with a headline figure in the
/// middle. Overall budgets get their own arcs inside the main one, so a bulk
/// buy does not distort the daily plan's ring.
///
/// Drawn with shapes rather than Swift Charts: a chart resolves a shape style
/// inside each mark's own bounds, so an angular gradient across the spent arc
/// lands at the wrong angles.
struct BudgetRingView: View {
    /// Totals, including any overall budgets. These drive the figure in the middle.
    var used: Decimal
    var budget: Decimal
    var centerCaption: String
    /// Positive carried-over amount, rendered as its own ring segment.
    var carryover: Decimal = 0
    /// Where the spending went, used to shade the spent arc. Empty falls back
    /// to a flat accent fill.
    var spendPalette: [SpendSlice] = []
    /// Overall budgets folded into `used`/`budget`, each drawn as an inner arc.
    var extraArcs: [ExtraArc] = []

    private var overBudget: Bool { used > budget }
    private var remaining: Decimal { budget - used }

    /// Spending on the daily plans: what the overall-budget segments show is
    /// already part of `used`, so it is taken out of the first segment.
    private var planUsed: Decimal { used - extraArcs.reduce(0) { $0 + $1.used } }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let thickness = size * 0.14

            ZStack {
                ForEach(Array(spans.enumerated()), id: \.offset) { _, span in
                    Circle()
                        .inset(by: thickness / 2)
                        .trim(from: span.start, to: span.end)
                        .stroke(Color.gray.opacity(0.2), lineWidth: thickness)

                    if let carried = span.carried {
                        Circle()
                            .inset(by: thickness / 2)
                            .trim(from: carried, to: span.end)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: thickness)
                    }

                    if let filled = span.filled {
                        Circle()
                            .inset(by: thickness / 2)
                            .trim(from: span.start, to: filled)
                            .stroke(span.style, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                    }
                }
            }
            .rotationEffect(.degrees(-90))
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

    /// The ring is divided by budget, not by spending: the daily plans take the
    /// first stretch, and each overall budget owns the stretch after it, past
    /// the plan's gray remainder. Every stretch fills from its own start.
    private var spans: [Span] {
        guard budget > 0 else { return [] }

        let extras = extraArcs.filter { $0.budget > 0 }
        let planBudget = budget - extras.reduce(0) { $0 + $1.budget }
        var parts: [(budget: Decimal, used: Decimal, color: Color?, carryover: Decimal)] = []
        if planBudget > 0 {
            // nil color means the plan's own category gradient.
            parts.append((planBudget, max(0, planUsed), nil, carryover))
        }
        for arc in extras {
            parts.append((arc.budget, arc.used, arc.color, 0))
        }
        guard !parts.isEmpty else { return [] }

        let gap = parts.count > 1 ? 0.01 : 0
        let scale = (1 - gap * Double(parts.count)) / budget.doubleValue
        var result: [Span] = []
        var cursor = gap / 2
        for part in parts {
            let span = part.budget.doubleValue * scale
            let usedShare = min(1, max(0, part.used.doubleValue / part.budget.doubleValue))
            let filled = usedShare > 0 ? cursor + span * usedShare : nil
            let carried = max(Decimal(0), min(part.carryover, part.budget - part.used))
            let style: AnyShapeStyle
            if part.used > part.budget {
                style = AnyShapeStyle(Color.red)
            } else if let color = part.color {
                style = AnyShapeStyle(color)
            } else {
                style = spentStyle(from: cursor, to: filled ?? cursor + span)
            }
            result.append((
                start: cursor,
                end: cursor + span,
                filled: filled,
                carried: carried > 0
                    ? cursor + span * (1 - carried.doubleValue / part.budget.doubleValue)
                    : nil,
                style: style
            ))
            cursor += span + gap
        }
        return result
    }

    /// The spent arc runs through the category colors in share order, each at
    /// full strength over the middle of its own share.
    private func spentStyle(from start: Double, to end: Double) -> AnyShapeStyle {
        let slices = spendPalette.filter { $0.weight > 0 }
        let total = slices.reduce(0) { $0 + $1.weight }
        guard slices.count > 1, total > 0, end > start else {
            return AnyShapeStyle(slices.first?.color ?? .accentColor)
        }

        // One stop at the middle of each category's share, so the colors blend
        // continuously instead of holding flat and stepping at the seams. The
        // shape spans the whole circle, so the stops are placed on that scale.
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
