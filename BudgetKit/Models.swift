import Foundation
import SwiftData

/// Shared SF Symbols so the same concept always gets the same glyph.
enum AppSymbol {
    static let budgetTemplate = "square.grid.2x2.fill"

    static let categoryIcons = [
        "sunrise.fill", "takeoutbag.and.cup.and.straw.fill", "fork.knife",
        "cup.and.saucer.fill", "gamecontroller.fill", "cart.fill",
        "car.fill", "tram.fill", "bag.fill", "gift.fill",
        "book.fill", "heart.fill", "pawprint.fill", "tag.fill",
    ]
}

// All properties have defaults and all relationships are optional,
// as required for CloudKit-backed SwiftData stores.

@Model
final class BudgetTemplate {
    var uuid: String = UUID().uuidString
    var name: String = ""
    var iconName: String = AppSymbol.budgetTemplate
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \TemplateCategory.template)
    var categories: [TemplateCategory]? = []

    init(name: String, iconName: String) {
        self.uuid = UUID().uuidString
        self.name = name
        self.iconName = iconName
        self.createdAt = .now
    }

    var sortedCategories: [TemplateCategory] {
        (categories ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var total: Decimal {
        (categories ?? []).reduce(0) { $0 + $1.amount }
    }
}

@Model
final class TemplateCategory {
    var name: String = ""
    var amount: Decimal = 0
    var sortOrder: Int = 0
    var iconName: String = "tag.fill"
    var template: BudgetTemplate?

    init(name: String, amount: Decimal, sortOrder: Int, iconName: String = "tag.fill") {
        self.name = name
        self.amount = amount
        self.sortOrder = sortOrder
        self.iconName = iconName
    }
}

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

enum CarryoverBehavior: String, CaseIterable, Identifiable {
    case leaveAsIs
    case nextDay
    case nextWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leaveAsIs: "Leave As-Is"
        case .nextDay: "Carry to Next Day"
        case .nextWeek: "Carry to Next Week"
        }
    }

    var subtitle: String {
        switch self {
        case .leaveAsIs: "Each day's budget stands on its own."
        case .nextDay: "Unused budget increases tomorrow; overspend reduces it. Resets each week."
        case .nextWeek: "Last week's leftover or overspend adjusts this week's budget."
        }
    }
}

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

enum DefaultData {
    static let categoryNames = ["Breakfast", "Lunch", "Dinner", "Beverages", "Entertainment"]
    static let categoryIcons = ["sunrise.fill", "takeoutbag.and.cup.and.straw.fill", "fork.knife", "cup.and.saucer.fill", "gamecontroller.fill"]

    struct TemplateSeed {
        let name: String
        let iconName: String
        let amounts: [Decimal]
    }

    static let templates: [TemplateSeed] = [
        TemplateSeed(name: "Working from Office", iconName: "building.2.fill", amounts: [6, 14, 16, 6, 5]),
        TemplateSeed(name: "Working from Home", iconName: "house.fill", amounts: [4, 9, 14, 3, 5]),
        TemplateSeed(name: "Not Working", iconName: "sofa.fill", amounts: [6, 12, 16, 5, 12]),
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let templateCount = (try? context.fetchCount(FetchDescriptor<BudgetTemplate>())) ?? 0
        var seeded: [BudgetTemplate] = []
        if templateCount == 0 {
            for seed in templates {
                let template = BudgetTemplate(name: seed.name, iconName: seed.iconName)
                context.insert(template)
                for (index, name) in categoryNames.enumerated() {
                    let category = TemplateCategory(name: name, amount: seed.amounts[index], sortOrder: index, iconName: categoryIcons[index])
                    category.template = template
                    context.insert(category)
                }
                seeded.append(template)
            }
        }

        // Backfill icons for categories created before the iconName field existed.
        let defaultIcons = Dictionary(uniqueKeysWithValues: zip(categoryNames, categoryIcons))
        let allCategories = (try? context.fetch(FetchDescriptor<TemplateCategory>())) ?? []
        for category in allCategories where category.iconName == "tag.fill" {
            if let icon = defaultIcons[category.name] {
                category.iconName = icon
            }
        }

        let settingsCount = (try? context.fetchCount(FetchDescriptor<PlanSettings>())) ?? 0
        if settingsCount == 0 {
            let settings = PlanSettings()
            if let office = seeded.first(where: { $0.name == "Working from Office" }),
               let off = seeded.first(where: { $0.name == "Not Working" }) {
                settings.setTemplateUUID(off.uuid, forWeekday: 1)      // Sunday
                for weekday in 2...6 {                                 // Monday–Friday
                    settings.setTemplateUUID(office.uuid, forWeekday: weekday)
                }
                settings.setTemplateUUID(off.uuid, forWeekday: 7)      // Saturday
            }
            context.insert(settings)
        }
        try? context.save()
    }

    /// Debug helper (`-seedSampleData YES`): fills the past four months,
    /// never touching today or days that already have entries.
    @MainActor
    static func seedSampleDataIfRequested(context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "seedSampleData") else { return }
        let existingEntries = (try? context.fetch(FetchDescriptor<SpendEntry>())) ?? []

        let templates = (try? context.fetch(FetchDescriptor<BudgetTemplate>())) ?? []
        let settings = (try? context.fetch(FetchDescriptor<PlanSettings>()))?.first
        let engine = BudgetEngine(templates: templates, overrides: [], entries: [], settings: settings)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let daysWithData = Set(existingEntries.map { calendar.startOfDay(for: $0.dayKey) })
        guard let start = calendar.date(byAdding: .month, value: -4, to: today) else { return }

        var day = start
        while day < today {
            if daysWithData.contains(day) {
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                continue
            }
            if let template = engine.template(for: day) {
                for category in template.sortedCategories {
                    // Skip the odd category so the data looks lived-in rather than mechanical.
                    if Int.random(in: 0..<10) == 0 { continue }
                    let factor = Double.random(in: 0.55...1.3)
                    let total = (category.amount.doubleValue * factor).rounded()
                    guard total > 0 else { continue }
                    let entry = SpendEntry(dayKey: day, categoryName: category.name, amount: Decimal(total))
                    let hour = 8 + category.sortOrder * 3
                    entry.timestamp = calendar.date(bySettingHour: min(hour, 21), minute: Int.random(in: 0..<60), second: 0, of: day) ?? day
                    context.insert(entry)
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        try? context.save()
    }
}
