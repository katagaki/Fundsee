import SwiftUI

struct BudgetRingLabel: View {
    var used: Decimal
    var budget: Decimal
    var caption: String
    var alignment: HorizontalAlignment = .leading

    private var overBudget: Bool { used > budget }

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(overBudget ? LocalizedStringKey("Ring.OverBy") : LocalizedStringKey("Ring.Remaining"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text((overBudget ? used - budget : budget - used).currencyString)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(overBudget ? .red : .primary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
    }
}
