import SwiftUI

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
