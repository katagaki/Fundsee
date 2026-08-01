import SwiftData
import SwiftUI
import WidgetKit


struct CategorySnapshot: Identifiable {
    let id: String
    let iconName: String
    let used: Decimal
    let amount: Decimal
}

struct BudgetEntry: TimelineEntry {
    let date: Date
    let spent: Decimal
    let budget: Decimal
    let categories: [CategorySnapshot]

    var remaining: Decimal { budget - spent }
    var overBudget: Bool { spent > budget }
    var fractionUsed: Double {
        budget > 0 ? min(1, spent.doubleValue / budget.doubleValue) : (spent > 0 ? 1 : 0)
    }

    static let placeholder = BudgetEntry(
        date: .now,
        spent: 12,
        budget: 40,
        categories: [
            CategorySnapshot(id: "Breakfast", iconName: "sunrise.fill", used: 4, amount: 6),
            CategorySnapshot(id: "Lunch", iconName: "takeoutbag.and.cup.and.straw.fill", used: 8, amount: 14),
            CategorySnapshot(id: "Dinner", iconName: "fork.knife", used: 0, amount: 16),
        ]
    )
}

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

struct TodayBudgetContentView: View {
    let entry: BudgetEntry
    let family: WidgetFamily

    private static let lime = Color(red: 0.65, green: 0.86, blue: 0.13)

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.overBudget
                 ? "\((-entry.remaining).currencyString) over today"
                 : "\(entry.remaining.currencyString) left today")

        case .accessoryCircular:
            Gauge(value: entry.fractionUsed) {
                Image(systemName: "chart.pie.fill")
            } currentValueLabel: {
                // The dial is tiny — a bare compact number fits where currency won't.
                Text(
                    (entry.overBudget ? -entry.remaining : entry.remaining).doubleValue,
                    format: .number.notation(.compactName).precision(.significantDigits(2))
                )
                .minimumScaleFactor(0.6)
            }
            .gaugeStyle(.accessoryCircular)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Budget")
                    .font(.headline)
                Text(entry.overBudget
                     ? "\((-entry.remaining).currencyString) over"
                     : "\(entry.remaining.currencyString) left")
                Gauge(value: entry.fractionUsed) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
            }

        case .systemMedium:
            HStack(spacing: 16) {
                ring
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.categories.prefix(4)) { category in
                        HStack(spacing: 6) {
                            Image(systemName: category.iconName)
                                .font(.caption)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(CategoryIconPalette.color(for: category.iconName))
                                .frame(width: 18)
                            Text(category.id)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                            Text(category.used.compactCurrencyString)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(category.used > category.amount ? .red : .primary)
                        }
                    }
                }
            }

        default:
            ring
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: entry.fractionUsed)
                .stroke(
                    entry.overBudget ? Color.red : Self.lime,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(entry.overBudget ? "Over" : "Left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text((entry.overBudget ? -entry.remaining : entry.remaining).compactCurrencyString)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
        }
        .padding(4)
    }
}
