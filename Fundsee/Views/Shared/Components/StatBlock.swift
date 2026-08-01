import SwiftUI

struct StatBlock: View {
    var title: LocalizedStringKey
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
