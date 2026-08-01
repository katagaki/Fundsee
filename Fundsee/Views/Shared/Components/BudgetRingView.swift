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
                Circle()
                    .inset(by: thickness / 2)
                    .stroke(Color.gray.opacity(0.2), lineWidth: thickness)

                if let carried = carriedFraction {
                    Circle()
                        .inset(by: thickness / 2)
                        .trim(from: max(0, 1 - carried), to: 1)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: thickness)
                }

                ForEach(Array(spans.enumerated()), id: \.offset) { _, span in
                    Circle()
                        .inset(by: thickness / 2)
                        .trim(from: span.start, to: span.end)
                        .stroke(span.style, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
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

    /// Consecutive stretches of the one ring: the plan's spending first, then a
    /// segment per overall budget that has been spent against, each separated by
    /// a small gap. All are measured against the same total budget.
    private var spans: [(start: Double, end: Double, style: AnyShapeStyle)] {
        guard budget > 0 else { return [] }
        if overBudget {
            return [(0, 1, AnyShapeStyle(Color.red))]
        }
        let total = budget.doubleValue
        let gap = 0.008
        var result: [(start: Double, end: Double, style: AnyShapeStyle)] = []
        var cursor = 0.0

        let planFraction = min(1, max(0, planUsed.doubleValue / total))
        if planFraction > 0 {
            result.append((cursor, cursor + planFraction, spentStyle(fraction: planFraction)))
            cursor += planFraction + gap
        }
        for arc in extraArcs where arc.used > 0 {
            let share = min(1, max(0, arc.used.doubleValue / total))
            guard cursor + share <= 1 else { break }
            result.append((cursor, cursor + share, AnyShapeStyle(arc.color)))
            cursor += share + gap
        }
        return result
    }

    private var carriedFraction: Double? {
        let carried = max(Decimal(0), min(carryover, remaining))
        guard carried > 0, budget > 0 else { return nil }
        return carried.doubleValue / budget.doubleValue
    }

    /// The spent arc runs through the category colors in share order, each at
    /// full strength over the middle of its own share.
    private func spentStyle(fraction: Double) -> AnyShapeStyle {
        let slices = spendPalette.filter { $0.weight > 0 }
        let total = slices.reduce(0) { $0 + $1.weight }
        guard slices.count > 1, total > 0 else {
            return AnyShapeStyle(slices.first?.color ?? .accentColor)
        }

        // One stop at the middle of each category's share, so the colors blend
        // continuously across the arc instead of holding flat and stepping.
        var stops: [Gradient.Stop] = []
        var cursor = 0.0
        for slice in slices {
            let share = slice.weight / total
            stops.append(.init(color: slice.color, location: cursor + share / 2))
            cursor += share
        }
        if let first = stops.first, let last = stops.last {
            stops.insert(.init(color: first.color, location: 0), at: 0)
            stops.append(.init(color: last.color, location: 1))
        }

        // The shape spans the whole circle, so the sweep is scaled to the arc.
        return AnyShapeStyle(
            AngularGradient(
                stops: stops,
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360 * fraction)
            )
        )
    }
}
