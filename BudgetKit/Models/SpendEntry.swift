import Foundation
import SwiftData

/// Which budget an entry is spent against. Weekly and monthly entries still
/// carry the day they were recorded on, but they belong to the overall budget
/// for that week or month, so day-level math leaves them out.
enum SpendScope: String, Hashable {
    case day, week, month
}

/// One recorded expense. Entries are removable but never editable.
@Model
final class SpendEntry {
    var timestamp: Date = Date.now
    var dayKey: Date = Calendar.current.startOfDay(for: .now)
    var categoryName: String = ""
    var amount: Decimal = 0
    var scopeRaw: String = SpendScope.day.rawValue

    init(dayKey: Date, categoryName: String, amount: Decimal, scope: SpendScope = .day) {
        self.timestamp = .now
        self.dayKey = Calendar.current.startOfDay(for: dayKey)
        self.categoryName = categoryName
        self.amount = amount
        self.scopeRaw = scope.rawValue
    }

    var scope: SpendScope {
        get { SpendScope(rawValue: scopeRaw) ?? .day }
        set { scopeRaw = newValue.rawValue }
    }
}
