import Charts
import SwiftUI

/// Donut gauge showing used vs. remaining budget with a headline figure in the middle.
struct BudgetRingView: View {
    var used: Decimal
    var budget: Decimal
    var centerCaption: String
    /// Positive carried-over amount, rendered as its own ring segment.
    var carryover: Decimal = 0
    /// Where the spending went, used to shade the spent arc. Empty falls back
    /// to a flat accent fill.
    var spendPalette: [SpendSlice] = []

    /// Fraction of each category's share given over to blending into its neighbors.
    private static let boundaryBlend = 0.2

    private var overBudget: Bool { used > budget }
    private var remaining: Decimal { budget - used }

    private var segments: [(name: String, value: Double, style: AnyShapeStyle)] {
        if budget <= 0 {
            return [("None", 1, AnyShapeStyle(Color.gray.opacity(0.25)))]
        }
        if overBudget {
            return [("Used", used.doubleValue, AnyShapeStyle(Color.red))]
        }
        let carried = max(Decimal(0), min(carryover, remaining))
        let baseRemaining = remaining - carried
        var result: [(name: String, value: Double, style: AnyShapeStyle)] = [
            ("Used", used.doubleValue, usedStyle),
            ("Remaining", baseRemaining.doubleValue, AnyShapeStyle(Color.gray.opacity(0.2))),
        ]
        if carried > 0 {
            result.append(("Carried Over", carried.doubleValue, AnyShapeStyle(Color.accentColor.opacity(0.3))))
        }
        return result
    }

    private var usedStyle: AnyShapeStyle {
        let slices = spendPalette.filter { $0.weight > 0 }
        if slices.count == 1, let only = slices.first {
            return AnyShapeStyle(only.color)
        }
        return spendSweep.map(AnyShapeStyle.init) ?? AnyShapeStyle(Color.accentColor)
    }

    /// Each category holds its color across its own share of the spent arc,
    /// blending only at the boundaries. Starts at twelve o'clock like the sectors.
    private var spendSweep: AngularGradient? {
        let slices = spendPalette.filter { $0.weight > 0 }
        guard slices.count > 1, budget > 0 else { return nil }
        let total = slices.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }

        var stops: [Gradient.Stop] = []
        var cursor = 0.0
        for slice in slices {
            let share = slice.weight / total
            let blend = share * Self.boundaryBlend
            stops.append(.init(color: slice.color, location: cursor + blend))
            stops.append(.init(color: slice.color, location: cursor + share - blend))
            cursor += share
        }

        let sweep = min(1, used.doubleValue / budget.doubleValue)
        return AngularGradient(
            stops: stops,
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * sweep)
        )
    }

    var body: some View {
        Chart(segments, id: \.name) { segment in
            SectorMark(
                angle: .value("Chart.Series.Amount", segment.value),
                innerRadius: .ratio(0.72),
                angularInset: 2
            )
            .cornerRadius(6)
            .foregroundStyle(segment.style)
        }
        .chartLegend(.hidden)
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
}
