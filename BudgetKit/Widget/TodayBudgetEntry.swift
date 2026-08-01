import Foundation
import SwiftData

func makeTodayBudgetEntry() -> BudgetEntry {
    do {
        let container = try AppGroup.readOnlyContainer()
        let context = ModelContext(container)
        let engine = BudgetEngine(
            templates: try context.fetch(FetchDescriptor<BudgetTemplate>()),
            overrides: try context.fetch(FetchDescriptor<DayOverride>()),
            entries: try context.fetch(FetchDescriptor<SpendEntry>()),
            settings: try context.fetch(FetchDescriptor<PlanSettings>()).first
        )
        let today = Date.now
        let categories = (engine.template(for: today)?.sortedCategories ?? []).map {
            CategorySnapshot(
                id: $0.name,
                iconName: $0.iconName,
                used: engine.spent(on: today, category: $0.name),
                amount: $0.amount
            )
        }
        return BudgetEntry(
            date: today,
            spent: engine.spent(on: today),
            budget: engine.effectiveBudget(for: today),
            categories: categories
        )
    } catch {
        return .placeholder
    }
}
