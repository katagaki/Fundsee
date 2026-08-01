import SwiftUI

extension BudgetEngine {
    /// Category colors weighted by what was spent, largest share first.
    func spendPalette(in interval: DateInterval) -> [SpendSlice] {
        palette(from: spentByCategory(in: interval))
    }

    func spendPalette(on date: Date) -> [SpendSlice] {
        palette(from: spentByCategory(on: date))
    }

    private func palette(from breakdown: [(name: String, amount: Decimal)]) -> [SpendSlice] {
        breakdown.compactMap { item in
            guard item.amount > 0 else { return nil }
            let icon = categoryIconName(item.name) ?? "tag.fill"
            return SpendSlice(color: CategoryIconPalette.color(for: icon), weight: item.amount.doubleValue)
        }
    }
}

struct SpendSlice: Equatable {
    let color: Color
    let weight: Double
}
