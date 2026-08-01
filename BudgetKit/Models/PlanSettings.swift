import Foundation
import SwiftData

/// Singleton-ish plan configuration (first fetched record wins).
@Model
final class PlanSettings {
    /// Template UUID per weekday, indexed by `Calendar` weekday − 1 (0 = Sunday … 6 = Saturday).
    var weekdayTemplateUUIDs: [String] = ["", "", "", "", "", "", ""]
    var weeklyOverallBudget: Decimal = 0
    var monthlyOverallBudget: Decimal = 0
    var carryoverRaw: String = CarryoverBehavior.leaveAsIs.rawValue

    init() {}

    var carryover: CarryoverBehavior {
        get { CarryoverBehavior(rawValue: carryoverRaw) ?? .leaveAsIs }
        set { carryoverRaw = newValue.rawValue }
    }

    func templateUUID(forWeekday weekday: Int) -> String? {
        let index = weekday - 1
        guard weekdayTemplateUUIDs.indices.contains(index) else { return nil }
        let id = weekdayTemplateUUIDs[index]
        return id.isEmpty ? nil : id
    }

    func setTemplateUUID(_ uuid: String?, forWeekday weekday: Int) {
        var ids = weekdayTemplateUUIDs
        while ids.count < 7 { ids.append("") }
        ids[weekday - 1] = uuid ?? ""
        weekdayTemplateUUIDs = ids
    }
}
