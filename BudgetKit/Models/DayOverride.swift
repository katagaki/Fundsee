import Foundation
import SwiftData

@Model
final class DayOverride {
    var dayKey: Date = Calendar.current.startOfDay(for: .now)
    var template: BudgetTemplate?

    init(dayKey: Date, template: BudgetTemplate?) {
        self.dayKey = Calendar.current.startOfDay(for: dayKey)
        self.template = template
    }
}
