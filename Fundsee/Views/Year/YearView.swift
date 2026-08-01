import Charts
import SwiftData
import SwiftUI

struct YearView: View {
    @Query private var templates: [BudgetTemplate]
    @Query private var overrides: [DayOverride]
    @Query private var entries: [SpendEntry]
    @Query private var allSettings: [PlanSettings]

    @State private var yearOffset = 0

    private var engine: BudgetEngine {
        BudgetEngine(templates: templates, overrides: overrides, entries: entries, settings: allSettings.first)
    }

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .year, value: yearOffset, to: .now) ?? .now
    }

    private var months: [Date] {
        let calendar = Calendar.current
        guard let year = calendar.dateInterval(of: .year, for: referenceDate) else { return [] }
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: year.start) }
    }

    var body: some View {
        NavigationStack {
            List {
                yearSummarySection
                chartSection
                monthsSection
            }
            .listStyle(.plain)
            .navigationTitle(referenceDate.formatted(.dateTime.year()))
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Previous Year", systemImage: "chevron.left") { yearOffset -= 1 }
                    Button("Next Year", systemImage: "chevron.right") { yearOffset += 1 }
                }
            }
        }
    }

    private var yearSummarySection: some View {
        let engine = self.engine
        let today = Calendar.current.startOfDay(for: .now)
        // The in-progress month only counts its budget up to today.
        let started = months.filter { engine.monthInterval(containing: $0).start <= today }
        let budget = started.reduce(Decimal(0)) { total, month in
            let interval = engine.monthInterval(containing: month)
            let full = interval.end <= today
            return total + (full ? engine.monthBudget(containing: month) : engine.monthBudgetToDate(containing: month, asOf: today))
        }
        let used = started.reduce(Decimal(0)) { $0 + engine.spent(in: engine.monthInterval(containing: $1)) }
        let balance = budget - used
        return Section {
            VStack(spacing: 8) {
            Text(balance >= 0 ? "+\(balance.currencyString)" : balance.currencyString)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(balance >= 0 ? Color.green : Color.red)
                .contentTransition(.numericText())
            Text(balance >= 0
                 ? "You've spent less than budgeted so far this year."
                 : "You've spent more than budgeted so far this year.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                StatBlock(title: "Budgeted", amount: budget)
                StatBlock(title: "Spent", amount: used)
            }
            .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    private var chartSection: some View {
        let engine = self.engine
        return Section {
            Chart {
                ForEach(months, id: \.self) { month in
                    let budget = engine.monthBudget(containing: month)
                    let used = engine.spent(in: engine.monthInterval(containing: month))
                    BarMark(
                        x: .value("Month", month, unit: .month),
                        yStart: .value("Budget", 0),
                        yEnd: .value("Budget", budget.doubleValue),
                        width: .ratio(0.72)
                    )
                    .foregroundStyle(Color.gray.opacity(0.18))
                    .cornerRadius(4)
                    BarMark(
                        x: .value("Month", month, unit: .month),
                        yStart: .value("Spent", 0),
                        yEnd: .value("Spent", used.doubleValue),
                        width: .ratio(0.45)
                    )
                    .foregroundStyle(used > budget ? Color.red : Color.accentColor)
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks(values: months) { _ in
                    AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                }
            }
            .frame(height: 200)
            .padding(.vertical, 6)
        }
    }

    private var monthsSection: some View {
        let engine = self.engine
        return Section {
            ForEach(months, id: \.self) { month in
                let budget = engine.monthBudget(containing: month)
                let used = engine.spent(in: engine.monthInterval(containing: month))
                HStack {
                    Text(month.formatted(.dateTime.month(.wide)))
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(used.currencyString) / \(budget.currencyString)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(used > budget ? .red : .secondary)
                        UsageBar(used: used, budget: budget)
                            .frame(width: 90)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
