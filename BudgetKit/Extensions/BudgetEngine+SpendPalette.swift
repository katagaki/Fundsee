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
        // Overall-budget spending has no category of its own, so it takes the
        // accent color its cards use.
        let overallNames = Set(entries.filter { $0.scope != .day }.map(\.categoryName))
        return breakdown.compactMap { item in
            guard item.amount > 0 else { return nil }
            if overallNames.contains(item.name) {
                return SpendSlice(color: .accentColor, weight: item.amount.doubleValue)
            }
            let icon = categoryIconName(item.name) ?? "tag.fill"
            return SpendSlice(color: CategoryIconPalette.color(for: icon), weight: item.amount.doubleValue)
        }
    }
}

struct SpendSlice: Equatable {
    let color: Color
    let weight: Double
}
