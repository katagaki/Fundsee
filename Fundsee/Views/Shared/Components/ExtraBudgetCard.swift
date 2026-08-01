import SwiftUI

/// The weekly or monthly overall budget, called out on its own so bulk buys do
/// not read as part of the daily plan they are folded into.
struct ExtraBudgetCard: View {
    var title: LocalizedStringKey
    var caption: LocalizedStringKey
    var amount: Decimal

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "basket.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Text(amount.currencyString)
                .font(.system(.headline, design: .rounded))
                .contentTransition(.numericText())
        }
        .fundseeCard()
        .shadow(color: colorScheme == .light ? .black.opacity(0.06) : .clear, radius: 8, y: 3)
    }
}
