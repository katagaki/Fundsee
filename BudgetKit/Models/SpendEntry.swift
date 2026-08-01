import Foundation
import SwiftData

/// One recorded expense. Entries are removable but never editable.
@Model
final class SpendEntry {
    var timestamp: Date = Date.now
    var dayKey: Date = Calendar.current.startOfDay(for: .now)
    var categoryName: String = ""
    var amount: Decimal = 0

    init(dayKey: Date, categoryName: String, amount: Decimal) {
        self.timestamp = .now
        self.dayKey = Calendar.current.startOfDay(for: dayKey)
        self.categoryName = categoryName
        self.amount = amount
    }
}
