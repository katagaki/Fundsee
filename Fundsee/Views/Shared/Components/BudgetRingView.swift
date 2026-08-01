import SwiftUI

/// An overall budget drawn as its own arc inside the main ring.
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

    /// Fraction of each category's share given over to blending into its neighbors.
    private static let boundaryBlend = 0.2

    private var overBudget: Bool { used > budget }
    private var remaining: Decimal { budget - used }

    /// The main ring covers the plan only: what the inner arcs show is taken out.
    private var planBudget: Decimal { budget - extraArcs.reduce(0) { $0 + $1.budget } }
    private var planUsed: Decimal { used - extraArcs.reduce(0) { $0 + $1.used } }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let thickness = size * 0.14
            let extraThickness = size * 0.05
            let gap = size * 0.025

            ZStack {
                planRing(thickness: thickness)

                ForEach(Array(extraArcs.enumerated()), id: \.offset) { index, arc in
                    let inset = thickness + gap + Double(index) * (extraThickness + gap)
                    arcRing(
                        used: arc.used,
                        budget: arc.budget,
                        style: AnyShapeStyle(arc.color),
                        inset: inset,
                        thickness: extraThickness
                    )
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

    @ViewBuilder
    private func planRing(thickness: Double) -> some View {
        let fraction = fraction(used: planUsed, budget: planBudget)
        let carried = max(Decimal(0), min(carryover, planBudget - planUsed))

        ZStack {
            Circle()
                .inset(by: thickness / 2)
                .stroke(Color.gray.opacity(0.2), lineWidth: thickness)

            if carried > 0, planBudget > 0 {
                let carriedFraction = carried.doubleValue / planBudget.doubleValue
                Circle()
                    .inset(by: thickness / 2)
                    .trim(from: max(0, 1 - carriedFraction), to: 1)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: thickness)
            }

            if fraction > 0 {
                Circle()
                    .inset(by: thickness / 2)
                    .trim(from: 0, to: fraction)
                    .stroke(spentStyle(fraction: fraction), style: StrokeStyle(lineWidth: thickness, lineCap: .round))
            }
        }
    }

    @ViewBuilder
    private func arcRing(used: Decimal, budget: Decimal, style: AnyShapeStyle, inset: Double, thickness: Double) -> some View {
        let fraction = fraction(used: used, budget: budget)
        ZStack {
            Circle()
                .inset(by: inset + thickness / 2)
                .stroke(Color.gray.opacity(0.15), lineWidth: thickness)
            if fraction > 0 {
                Circle()
                    .inset(by: inset + thickness / 2)
                    .trim(from: 0, to: fraction)
                    .stroke(
                        used > budget ? AnyShapeStyle(Color.red) : style,
                        style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                    )
            }
        }
    }

    private func fraction(used: Decimal, budget: Decimal) -> Double {
        guard budget > 0 else { return used > 0 ? 1 : 0 }
        return min(1, max(0, used.doubleValue / budget.doubleValue))
    }

    /// Each category holds its color across its own share of the spent arc,
    /// blending only at the boundaries.
    private func spentStyle(fraction: Double) -> AnyShapeStyle {
        if planUsed > planBudget { return AnyShapeStyle(Color.red) }
        let slices = spendPalette.filter { $0.weight > 0 }
        let total = slices.reduce(0) { $0 + $1.weight }
        guard slices.count > 1, total > 0 else {
            return AnyShapeStyle(slices.first?.color ?? .accentColor)
        }

        var stops: [Gradient.Stop] = []
        var cursor = 0.0
        for slice in slices {
            let share = slice.weight / total
            let blend = share * Self.boundaryBlend
            stops.append(.init(color: slice.color, location: cursor + blend))
            stops.append(.init(color: slice.color, location: cursor + share - blend))
            cursor += share
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
