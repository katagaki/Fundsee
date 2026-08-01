import Charts
import SwiftData
import SwiftUI

struct MonthView: View {
    @Query private var templates: [BudgetTemplate]
    @Query private var overrides: [DayOverride]
    @Query private var entries: [SpendEntry]
    @Query private var allSettings: [PlanSettings]

    @State private var monthOffset = 0
    @State private var selectedWeekStart: Date?

    private var engine: BudgetEngine {
        BudgetEngine(templates: templates, overrides: overrides, entries: entries, settings: allSettings.first)
    }

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: .now) ?? .now
    }

    private var shownWeek: DateInterval {
        let engine = self.engine
        let weeks = engine.weeks(inMonthContaining: referenceDate)
        if let start = selectedWeekStart,
           let match = weeks.first(where: { $0.start == start }) {
            return match
        }
        let today = Calendar.current.startOfDay(for: .now)
        return weeks.first { Self.week($0, contains: today) } ?? weeks.first
            ?? engine.weekInterval(containing: referenceDate)
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                calendarSection
                selectedWeekSection
                chartSection
            }
            .listStyle(.plain)
            .navigationTitle(referenceDate.formatted(.dateTime.month(.wide).year()))
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Month.Previous", systemImage: "chevron.left") { monthOffset -= 1 }
                    Button("Month.Next", systemImage: "chevron.right") { monthOffset += 1 }
                }
            }
        }
    }

    private var summarySection: some View {
        let engine = self.engine
        let month = engine.monthInterval(containing: referenceDate)
        let budget = engine.monthBudget(containing: referenceDate)
        let used = engine.spent(in: month)
        return Section {
            VStack(spacing: 12) {
            BudgetRingView(used: used, budget: budget, centerCaption: String(localized: "Ring.Caption.OfThisMonth", defaultValue: "of \(budget.currencyString) this month"))
                .frame(height: 200)
            HStack {
                StatBlock(title: "Stat.Budget", amount: budget)
                StatBlock(title: "Stat.Used", amount: used)
                StatBlock(title: "Stat.Remaining", amount: budget - used, tint: budget - used < 0 ? .red : .primary)
            }
            if engine.monthlyExtra > 0 {
                ExtraBudgetCard(
                    title: "OverallBudgets.Monthly.Header",
                    caption: "Month.Extra.Caption",
                    amount: engine.monthlyExtra
                )
            }
            }
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    /// Built eagerly, one row per week. A `LazyVGrid` here reports an unstable
    /// height to the enclosing `List`, which blocks scrolling past the calendar
    /// and makes the week band stutter as it moves.
    private var calendarSection: some View {
        let engine = self.engine
        let calendar = Calendar.current
        let month = engine.monthInterval(containing: referenceDate)
        let weeks = engine.weeks(inMonthContaining: referenceDate)
        let symbols = orderedWeekdaySymbols(calendar)
        let today = calendar.startOfDay(for: .now)
        let shownWeekStart = shownWeek.start

        return Section {
            VStack(spacing: 2) {
                HStack(spacing: 0) {
                    ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 4)

                ForEach(weeks, id: \.start) { week in
                    HStack(spacing: 0) {
                        ForEach(engine.days(in: week), id: \.self) { day in
                            dayCell(
                                day,
                                inMonth: Self.week(month, contains: day),
                                engine: engine,
                                today: today
                            )
                        }
                    }
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(week.start == shownWeekStart ? 0.12 : 0))
                    )
                    .contentShape(.rect)
                    .onTapGesture {
                        withAnimation(.snappy) { selectedWeekStart = week.start }
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
        }
    }

    /// One calendar cell. Days spilling in from the neighboring month keep their
    /// slot so the grid stays aligned, but render empty.
    @ViewBuilder
    private func dayCell(_ day: Date, inMonth: Bool, engine: BudgetEngine, today: Date) -> some View {
        Group {
            if inMonth {
                VStack(spacing: 3) {
                    // Bare number, not `.dateTime.day()`: that renders "1日" in
                    // Japanese and "1일" in Korean, which is too wide for a grid cell.
                    Text(Calendar.current.component(.day, from: day), format: .number.grouping(.never))
                        .font(.caption.weight(day == today ? .heavy : .medium))
                        .foregroundStyle(day == today ? Color.accentColor : .primary)
                    Circle()
                        .fill(
                            dayColor(
                                used: engine.spent(on: day),
                                budget: engine.effectiveBudget(for: day),
                                day: day,
                                today: today
                            )
                        )
                        .frame(width: 6, height: 6)
                }
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
    }

    private var selectedWeekSection: some View {
        let engine = self.engine
        let week = shownWeek
        let budget = engine.weekBudget(containing: week.start, includeCarry: false)
        let used = engine.spent(in: week)
        return Section {
            VStack(spacing: 10) {
                HStack {
                    Text(weekTitle(week))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(verbatim: "\(used.currencyString) / \(budget.currencyString)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(used > budget ? .red : .primary)
                        .contentTransition(.numericText())
                }
                UsageBar(used: used, budget: budget)
                HStack {
                    StatBlock(title: "Stat.Budget", amount: budget)
                    StatBlock(title: "Stat.Used", amount: used)
                    StatBlock(title: "Stat.Remaining", amount: budget - used, tint: budget - used < 0 ? .red : .primary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var chartSection: some View {
        let engine = self.engine
        let weeks = engine.weeks(inMonthContaining: referenceDate)
        let shownWeek = self.shownWeek
        return Section {
            Chart {
                ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                    let budget = engine.weekBudget(containing: week.start, includeCarry: false)
                    let used = engine.spent(in: week)
                    BarMark(
                        x: .value("Chart.Axis.Week", String(localized: "Month.Chart.WeekLabel", defaultValue: "W\(index + 1)")),
                        yStart: .value("Chart.Series.Budget", 0),
                        yEnd: .value("Chart.Series.Budget", budget.doubleValue),
                        width: .ratio(0.72)
                    )
                    .foregroundStyle(Color.gray.opacity(0.18))
                    .cornerRadius(5)
                    BarMark(
                        x: .value("Chart.Axis.Week", String(localized: "Month.Chart.WeekLabel", defaultValue: "W\(index + 1)")),
                        yStart: .value("Chart.Series.Spent", 0),
                        yEnd: .value("Chart.Series.Spent", used.doubleValue),
                        width: .ratio(0.45)
                    )
                    .foregroundStyle(
                        used > budget
                            ? Color.red
                            : (week == shownWeek ? Color.accentColor : Color.accentColor.opacity(0.45))
                    )
                    .cornerRadius(5)
                }
            }
            .frame(height: 160)
            .padding(.vertical, 6)
            .listRowSeparator(.hidden)
        }
    }

    private func weekTitle(_ week: DateInterval) -> String {
        let calendar = Calendar.current
        let lastDay = calendar.date(byAdding: .day, value: -1, to: week.end) ?? week.end
        return (week.start..<lastDay).formatted(.interval.month(.abbreviated).day())
    }

    /// `DateInterval.contains` includes the end boundary; that would leak
    /// the next week's first day into the band.
    private static func week(_ week: DateInterval, contains day: Date) -> Bool {
        day >= week.start && day < week.end
    }

    private func dayColor(used: Decimal, budget: Decimal, day: Date, today: Date) -> Color {
        if day > today { return .gray.opacity(0.2) }
        if budget <= 0 && used <= 0 { return .gray.opacity(0.3) }
        if used > budget { return .red }
        if used.doubleValue > budget.doubleValue * 0.85 { return .orange }
        return .green
    }

    private func orderedWeekdaySymbols(_ calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
}
