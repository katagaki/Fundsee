import Charts
import SwiftData
import SwiftUI

struct WeekView: View {
    @Query private var templates: [BudgetTemplate]
    @Query private var overrides: [DayOverride]
    @Query private var entries: [SpendEntry]
    @Query private var allSettings: [PlanSettings]

    @State private var weekOffset = 0
    @State private var selectedDay: Date?
    @State private var stripDay: Date?
    @State private var inputCategory: String?
    @Namespace private var cardZoom

    private var engine: BudgetEngine {
        BudgetEngine(templates: templates, overrides: overrides, entries: entries, settings: allSettings.first)
    }

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: .now) ?? .now
    }

    private var shownDay: Date {
        let engine = self.engine
        let days = engine.days(in: engine.weekInterval(containing: referenceDate))
        let fallback = days.first(where: \.isToday) ?? days.first ?? referenceDate
        return stripDay.flatMap { days.contains($0) ? $0 : nil } ?? fallback
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                weekCalendarSection
            }
            .listStyle(.plain)
            .navigationTitle("Week")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Previous Week", systemImage: "chevron.left") { weekOffset -= 1 }
                    Button("Next Week", systemImage: "chevron.right") { weekOffset += 1 }
                }
            }
            .navigationDestination(item: $selectedDay) { date in
                DayDetailView(date: date)
            }
            .sheet(item: $inputCategory) { category in
                SpendInputSheet(
                    date: shownDay,
                    categoryName: category,
                    recentAmounts: engine.recentAmounts(category: category)
                )
                .navigationTransition(.zoom(sourceID: category, in: cardZoom))
            }
        }
    }

    private var summarySection: some View {
        let engine = self.engine
        let week = engine.weekInterval(containing: referenceDate)
        let budget = engine.weekBudget(containing: referenceDate)
        let used = engine.spent(in: week)
        let carryover = budget - engine.weekBudget(containing: referenceDate, includeCarry: false)
        return Section {
            VStack(spacing: 12) {
            BudgetRingView(used: used, budget: budget, centerCaption: "of \(budget.currencyString) this week", carryover: carryover)
                .frame(height: 200)
            Text(weekTitle(week))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                StatBlock(title: "Budget", amount: budget)
                StatBlock(title: "Used", amount: used)
                StatBlock(title: "Remaining", amount: budget - used, tint: budget - used < 0 ? .red : .primary)
            }
            if engine.weeklyExtra > 0 {
                Text("Includes \(engine.weeklyExtra.currencyString) weekly overall budget")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            }
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var weekCalendarSection: some View {
        let engine = self.engine
        let week = engine.weekInterval(containing: referenceDate)
        let days = engine.days(in: week)
        let shown = shownDay
        let budget = engine.effectiveBudget(for: shown)
        let spent = engine.spent(on: shown)
        return Group {
            Section {
                HStack(spacing: 4) {
                    ForEach(days, id: \.self) { day in
                        Button {
                            withAnimation(.snappy) { stripDay = day }
                        } label: {
                            WeekDayPill(
                                day: day,
                                isSelected: day == shown,
                                status: dayStatus(day, engine: engine)
                            )
                        }
                        .buttonStyle(.borderless)
                        .tint(.primary)
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())

            Section {
            VStack(spacing: 8) {
                HStack {
                    Label(
                        engine.template(for: shown)?.name ?? "No template",
                        systemImage: engine.template(for: shown)?.iconName ?? "questionmark.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(spent.currencyString) / \(budget.currencyString)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(spent > budget ? .red : .primary)
                        .contentTransition(.numericText())
                }
                UsageBar(used: spent, budget: budget)
            }
            .padding(.vertical, 4)

            if let template = engine.template(for: shown) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(template.sortedCategories) { category in
                        let categorySpent = engine.spent(on: shown, category: category.name)
                        Button {
                            inputCategory = category.name
                        } label: {
                            CategoryGridCell(category: category, used: categorySpent)
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: category.name, in: cardZoom)
                    }
                }
                .padding(.horizontal, 16)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }

            Button {
                selectedDay = shown
            } label: {
                HStack {
                    Text("Edit \(shown.formatted(.dateTime.weekday(.wide)))")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .tint(.primary)
            }
        }
    }

    private func dayStatus(_ day: Date, engine: BudgetEngine) -> WeekDayPill.Status {
        let spent = engine.spent(on: day)
        if spent <= 0 { return .empty }
        return spent > engine.effectiveBudget(for: day) ? .over : .under
    }

    private func weekTitle(_ week: DateInterval) -> String {
        let end = Calendar.current.date(byAdding: .day, value: -1, to: week.end) ?? week.end
        return "\(week.start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
    }
}

/// Per-day drill-in: add or remove spend for any day, override upcoming days' templates.
struct DayDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let date: Date

    @Query private var templates: [BudgetTemplate]
    @Query private var overrides: [DayOverride]
    @Query(sort: \SpendEntry.timestamp, order: .reverse) private var entries: [SpendEntry]
    @Query private var allSettings: [PlanSettings]

    @State private var inputCategory: String?
    @Namespace private var cardZoom
    @State private var showingTemplatePicker = false

    private var engine: BudgetEngine {
        BudgetEngine(templates: templates, overrides: overrides, entries: entries, settings: allSettings.first)
    }

    private var isEditableTemplate: Bool {
        Calendar.current.startOfDay(for: date) >= Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        let engine = self.engine
        let budget = engine.effectiveBudget(for: date)
        let used = engine.spent(on: date)
        List {
            Section {
                VStack(spacing: 10) {
                    BudgetRingView(used: used, budget: budget, centerCaption: "of \(budget.currencyString)", carryover: engine.carryover == .nextDay ? budget - engine.baseBudget(for: date) : 0)
                        .frame(height: 200)
                    HStack(spacing: 8) {
                        Image(systemName: engine.template(for: date)?.iconName ?? "questionmark.circle")
                        Text(engine.template(for: date)?.name ?? "No template")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
            }

            if let template = engine.template(for: date) {
                Section("Add Spend") {
                    ForEach(template.sortedCategories) { category in
                        Button {
                            inputCategory = category.name
                        } label: {
                            HStack {
                                Text(category.name)
                                Spacer()
                                Text("\(engine.spent(on: date, category: category.name).currencyString) / \(category.amount.currencyString)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .tint(.primary)
                    }
                }
            }

            Section("Recorded") {
                let dayEntries = engine.entries(on: date).sorted { $0.timestamp > $1.timestamp }
                if dayEntries.isEmpty {
                    Text("Nothing recorded on this day.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(dayEntries) { entry in
                        EntryRow(entry: entry) {
                            modelContext.delete(entry)
                            try? modelContext.save()
                        }
                    }
                }
            }
        }
        .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditableTemplate {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingTemplatePicker = true
                    } label: {
                        Label("Change Template", systemImage: AppSymbol.budgetTemplate)
                    }
                }
            }
        }
        .sheet(isPresented: $showingTemplatePicker) {
            TemplateOverrideSheet(initialDate: date, allowDateChange: false)
        }
        .sheet(item: $inputCategory) { category in
            SpendInputSheet(
                date: date,
                categoryName: category,
                recentAmounts: engine.recentAmounts(category: category)
            )
        }
    }
}

/// One pill of the horizontal week calendar: weekday, date, status dot.
struct WeekDayPill: View {
    enum Status {
        case empty, under, over

        var color: Color {
            switch self {
            case .empty: .gray.opacity(0.35)
            case .under: .green
            case .over: .red
            }
        }
    }

    let day: Date
    let isSelected: Bool
    let status: Status

    var body: some View {
        VStack(spacing: 6) {
            Text(day.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
            Text(day.formatted(.dateTime.day()))
                .font(.callout.weight(day.isToday || isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? Color.black : (day.isToday ? Color.accentColor : .primary))
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.accentColor : Color.clear, in: .circle)
            Circle()
                .fill(status.color)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}
