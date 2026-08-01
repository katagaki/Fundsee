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
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Previous Month", systemImage: "chevron.left") { monthOffset -= 1 }
                    Button("Next Month", systemImage: "chevron.right") { monthOffset += 1 }
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
            BudgetRingView(used: used, budget: budget, centerCaption: "of \(budget.currencyString) this month")
                .frame(height: 200)
            HStack {
                StatBlock(title: "Budget", amount: budget)
                StatBlock(title: "Used", amount: used)
                StatBlock(title: "Remaining", amount: budget - used, tint: budget - used < 0 ? .red : .primary)
            }
            if engine.monthlyExtra > 0 {
                Text("Includes \(engine.monthlyExtra.currencyString) monthly overall budget")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            }
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var calendarSection: some View {
        let engine = self.engine
        let calendar = Calendar.current
        let month = engine.monthInterval(containing: referenceDate)
        let days = engine.days(in: month)
        let firstWeekday = calendar.component(.weekday, from: month.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let symbols = orderedWeekdaySymbols(calendar)
        let today = calendar.startOfDay(for: .now)
        let shownWeek = self.shownWeek

        return Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ForEach(0..<leading, id: \.self) { index in
                    // Leading blanks are part of the first week: band them when selected.
                    Color.clear
                        .frame(height: 48)
                        .background(bandShape(isFirst: index == 0, isLast: false)
                            .fill(days.first.map { Self.week(shownWeek, contains: $0) } == true ? Color.accentColor.opacity(0.12) : .clear))
                }
                ForEach(days, id: \.self) { day in
                    let used = engine.spent(on: day)
                    let budget = engine.effectiveBudget(for: day)
                    let weekday = calendar.component(.weekday, from: day)
                    let position = (weekday - calendar.firstWeekday + 7) % 7
                    let inShownWeek = Self.week(shownWeek, contains: day)
                    Button {
                        withAnimation(.snappy) {
                            selectedWeekStart = engine.weekInterval(containing: day).start
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(day.formatted(.dateTime.day()))
                                .font(.caption.weight(day == today ? .heavy : .medium))
                                .foregroundStyle(day == today ? Color.accentColor : .primary)
                            Circle()
                                .fill(dayColor(used: used, budget: budget, day: day, today: today))
                                .frame(width: 6, height: 6)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            bandShape(
                                isFirst: position == 0 || day == days.first,
                                isLast: position == 6 || day == days.last
                            )
                            .fill(inShownWeek ? Color.accentColor.opacity(0.12) : .clear)
                        )
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
        }
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
                    Text("\(used.currencyString) / \(budget.currencyString)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(used > budget ? .red : .primary)
                        .contentTransition(.numericText())
                }
                UsageBar(used: used, budget: budget)
                HStack {
                    StatBlock(title: "Budget", amount: budget)
                    StatBlock(title: "Used", amount: used)
                    StatBlock(title: "Remaining", amount: budget - used, tint: budget - used < 0 ? .red : .primary)
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
                        x: .value("Week", "W\(index + 1)"),
                        yStart: .value("Budget", 0),
                        yEnd: .value("Budget", budget.doubleValue),
                        width: .ratio(0.72)
                    )
                    .foregroundStyle(Color.gray.opacity(0.18))
                    .cornerRadius(5)
                    BarMark(
                        x: .value("Week", "W\(index + 1)"),
                        yStart: .value("Spent", 0),
                        yEnd: .value("Spent", used.doubleValue),
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

    /// `DateInterval.contains` includes the end boundary; that would leak
    /// the next week's first day into the band.
    private static func week(_ week: DateInterval, contains day: Date) -> Bool {
        day >= week.start && day < week.end
    }

    /// Capsule-ended highlight band (cells are 48pt tall).
    private func bandShape(isFirst: Bool, isLast: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? 24 : 0,
            bottomLeadingRadius: isFirst ? 24 : 0,
            bottomTrailingRadius: isLast ? 24 : 0,
            topTrailingRadius: isLast ? 24 : 0
        )
    }

    private func weekTitle(_ week: DateInterval) -> String {
        let end = Calendar.current.date(byAdding: .day, value: -1, to: week.end) ?? week.end
        return "\(week.start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
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
