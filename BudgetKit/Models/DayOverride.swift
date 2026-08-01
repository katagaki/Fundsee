import Foundation
import SwiftData

/// Replaces the scheduled template for one specific calendar day.
@Model
final class DayOverride {
    var dayKey: Date = Calendar.current.startOfDay(for: .now)
    var template: BudgetTemplate?

    init(dayKey: Date, template: BudgetTemplate?) {
        self.dayKey = Calendar.current.startOfDay(for: dayKey)
        self.template = template
    }
}
