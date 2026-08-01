import Charts
import SwiftUI

/// Donut gauge showing used vs. remaining budget with a headline figure in the middle.
struct BudgetRingView: View {
    var used: Decimal
    var budget: Decimal
    var centerCaption: String
    /// Positive carried-over amount, rendered as its own ring segment.
    var carryover: Decimal = 0

    private var overBudget: Bool { used > budget }
    private var remaining: Decimal { budget - used }

    private var segments: [(name: String, value: Double, color: Color)] {
        if budget <= 0 {
            return [("None", 1, Color.gray.opacity(0.25))]
        }
        if overBudget {
            return [("Used", used.doubleValue, .red)]
        }
        let carried = max(Decimal(0), min(carryover, remaining))
        let baseRemaining = remaining - carried
        var result: [(name: String, value: Double, color: Color)] = [
            ("Used", used.doubleValue, .accentColor),
            ("Remaining", baseRemaining.doubleValue, Color.gray.opacity(0.2)),
        ]
        if carried > 0 {
            result.append(("Carried Over", carried.doubleValue, Color.accentColor.opacity(0.3)))
        }
        return result
    }

    var body: some View {
        Chart(segments, id: \.name) { segment in
            SectorMark(
                angle: .value("Amount", segment.value),
                innerRadius: .ratio(0.72),
                angularInset: 2
            )
            .cornerRadius(6)
            .foregroundStyle(segment.color)
        }
        .chartLegend(.hidden)
        .overlay {
            VStack(spacing: 4) {
                Text(overBudget ? "Over by" : "Remaining")
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

/// Small labeled amount used in summary rows.
struct StatBlock: View {
    var title: String
    var amount: Decimal
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount.currencyString)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Horizontal used/budget bar for a single category or day.
struct UsageBar: View {
    var used: Decimal
    var budget: Decimal

    var body: some View {
        GeometryReader { proxy in
            let fraction = budget > 0 ? min(1, used.doubleValue / budget.doubleValue) : (used > 0 ? 1 : 0)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.18))
                Capsule()
                    .fill(used > budget ? Color.red : Color.accentColor)
                    .frame(width: max(fraction > 0 ? 6 : 0, proxy.size.width * fraction))
            }
        }
        .frame(height: 8)
    }
}

extension View {
    func fundseeCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.background.secondary, in: .rect(cornerRadius: 24))
    }
}

extension Date {
    var isToday: Bool { Calendar.current.isDateInToday(self) }
}

