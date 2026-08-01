import Foundation

/// Pure calculation layer. Views build one from their queried data each render.
struct BudgetEngine {
    var templates: [BudgetTemplate]
    var overrides: [DayOverride]
    var entries: [SpendEntry]
    var settings: PlanSettings?
    var calendar: Calendar = .current

    var carryover: CarryoverBehavior { settings?.carryover ?? .leaveAsIs }
    var weeklyExtra: Decimal { settings?.weeklyOverallBudget ?? 0 }
    var monthlyExtra: Decimal { settings?.monthlyOverallBudget ?? 0 }

    // MARK: - Date helpers

    func day(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    func weekInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: day(date), duration: 7 * 86_400)
    }

    func monthInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .month, for: date)
            ?? DateInterval(start: day(date), duration: 30 * 86_400)
    }

    func days(in interval: DateInterval) -> [Date] {
        var result: [Date] = []
        var current = calendar.startOfDay(for: interval.start)
        while current < interval.end {
            result.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    // MARK: - Template resolution

    func override(for date: Date) -> DayOverride? {
        overrides.last { calendar.isDate($0.dayKey, inSameDayAs: date) }
    }

    func template(for date: Date) -> BudgetTemplate? {
        if let override = override(for: date), let template = override.template {
            return template
        }
        let weekday = calendar.component(.weekday, from: date)
        guard let uuid = settings?.templateUUID(forWeekday: weekday) else { return nil }
        return templates.first { $0.uuid == uuid }
    }

    // MARK: - Spending

    func entries(on date: Date) -> [SpendEntry] {
        entries.filter { calendar.isDate($0.dayKey, inSameDayAs: date) }
    }

    func entries(in interval: DateInterval) -> [SpendEntry] {
        entries.filter { interval.contains($0.dayKey) && $0.dayKey < interval.end }
    }

    func spent(on date: Date) -> Decimal {
        entries(on: date).reduce(0) { $0 + $1.amount }
    }

    func spent(on date: Date, category: String) -> Decimal {
        entries(on: date).filter { $0.categoryName == category }.reduce(0) { $0 + $1.amount }
    }

    func spent(in interval: DateInterval) -> Decimal {
        entries(in: interval).reduce(0) { $0 + $1.amount }
    }

    /// Spending split by category name, largest first.
    func spentByCategory(in interval: DateInterval) -> [(name: String, amount: Decimal)] {
        breakdown(of: entries(in: interval))
    }

    func spentByCategory(on date: Date) -> [(name: String, amount: Decimal)] {
        breakdown(of: entries(on: date))
    }

    private func breakdown(of entries: [SpendEntry]) -> [(name: String, amount: Decimal)] {
        var totals: [String: Decimal] = [:]
        for entry in entries {
            totals[entry.categoryName, default: 0] += entry.amount
        }
        return totals
            .map { (name: $0.key, amount: $0.value) }
            .sorted { ($0.amount, $1.name) > ($1.amount, $0.name) }
    }

    /// The icon any template gives this category name.
    func categoryIconName(_ name: String) -> String? {
        for template in templates {
            if let match = template.sortedCategories.first(where: { $0.name == name }) {
                return match.iconName
            }
        }
        return nil
    }

    func recentAmounts(category: String, limit: Int = 3) -> [Decimal] {
        var seen: [Decimal] = []
        for entry in entries.filter({ $0.categoryName == category }).sorted(by: { $0.timestamp > $1.timestamp }) {
            if !seen.contains(entry.amount) {
                seen.append(entry.amount)
                if seen.count == limit { break }
            }
        }
        return seen
    }

    // MARK: - Budgets

    func baseBudget(for date: Date) -> Decimal {
        template(for: date)?.total ?? 0
    }

    /// The day's budget including next-day carryover when that behavior is active.
    /// Carryover chains from the start of the week and resets at each week boundary:
    /// effective(d) = Σ base(weekStart…d) − Σ spent(weekStart…d−1).
    func effectiveBudget(for date: Date) -> Decimal {
        let target = day(date)
        guard carryover == .nextDay else { return baseBudget(for: target) }
        let week = weekInterval(containing: target)
        var budgetSum: Decimal = 0
        var spentSum: Decimal = 0
        for d in days(in: week) where d <= target {
            budgetSum += baseBudget(for: d)
            if d < target { spentSum += spent(on: d) }
        }
        return budgetSum - spentSum
    }

    func remaining(for date: Date) -> Decimal {
        effectiveBudget(for: date) - spent(on: date)
    }

    func weekBudget(containing date: Date, includeCarry: Bool = true) -> Decimal {
        let week = weekInterval(containing: date)
        let base = days(in: week).reduce(Decimal(0)) { $0 + baseBudget(for: $1) } + weeklyExtra
        guard includeCarry, carryover == .nextWeek,
              let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week.start) else {
            return base
        }
        let previousWeek = weekInterval(containing: previous)
        let previousBase = days(in: previousWeek).reduce(Decimal(0)) { $0 + baseBudget(for: $1) } + weeklyExtra
        return base + (previousBase - spent(in: previousWeek))
    }

    func monthBudget(containing date: Date) -> Decimal {
        let month = monthInterval(containing: date)
        let base = days(in: month).reduce(Decimal(0)) { $0 + baseBudget(for: $1) }
        let weekStarts = days(in: month).filter { calendar.isDate($0, equalTo: weekInterval(containing: $0).start, toGranularity: .day) }
        return base + monthlyExtra + weeklyExtra * Decimal(weekStarts.count)
    }

    /// The month's budget counted only up to (and including) a reference day:
    /// day budgets for elapsed days, the weekly extra per week already started,
    /// and the monthly extra in full (it is granted at the start of the month).
    func monthBudgetToDate(containing date: Date, asOf reference: Date) -> Decimal {
        let month = monthInterval(containing: date)
        let cutoff = day(reference)
        let elapsed = days(in: month).filter { $0 <= cutoff }
        let base = elapsed.reduce(Decimal(0)) { $0 + baseBudget(for: $1) }
        let weekStarts = elapsed.filter { calendar.isDate($0, equalTo: weekInterval(containing: $0).start, toGranularity: .day) }
        return base + monthlyExtra + weeklyExtra * Decimal(weekStarts.count)
    }

    func weeks(inMonthContaining date: Date) -> [DateInterval] {
        let month = monthInterval(containing: date)
        var result: [DateInterval] = []
        var cursor = weekInterval(containing: month.start)
        while cursor.start < month.end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor.start) else { break }
            cursor = weekInterval(containing: next)
        }
        return result
    }

    enum MonthStatus {
        case onTrack, surplus, debt, upcoming

        var title: String {
            switch self {
            case .onTrack: String(localized: "MonthStatus.OnTrack", defaultValue: "On Track")
            case .surplus: String(localized: "MonthStatus.Surplus", defaultValue: "Surplus")
            case .debt: String(localized: "MonthStatus.OverBudget", defaultValue: "Over Budget")
            case .upcoming: String(localized: "MonthStatus.Upcoming", defaultValue: "Upcoming")
            }
        }
    }

    /// Year view judgment. Past months compare totals; the current month
    /// compares spend against the budget prorated to today.
    func status(forMonthContaining date: Date, today: Date = .now) -> MonthStatus {
        let month = monthInterval(containing: date)
        let now = day(today)
        if month.start > now { return .upcoming }
        let budget = monthBudget(containing: date)
        let used = spent(in: month)
        if month.end <= today {
            return used > budget ? .debt : (used < budget ? .surplus : .onTrack)
        }
        // Current month: prorate.
        let allDays = days(in: month)
        let elapsed = allDays.filter { $0 <= now }
        guard !allDays.isEmpty else { return .onTrack }
        let prorated = budget * Decimal(elapsed.count) / Decimal(allDays.count)
        let tolerance = prorated * Decimal(0.05)
        if used > prorated + tolerance { return .debt }
        if used < prorated - tolerance { return .surplus }
        return .onTrack
    }
}
