import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var templates: [BudgetTemplate]
    @Query private var overrides: [DayOverride]
    @Query(sort: \SpendEntry.timestamp, order: .reverse) private var entries: [SpendEntry]
    @Query private var allSettings: [PlanSettings]

    @State private var inputCategory: String?
    @State private var showingTemplatePicker = false
    @Namespace private var cardZoom

    private var engine: BudgetEngine {
        BudgetEngine(templates: templates, overrides: overrides, entries: entries, settings: allSettings.first)
    }

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    var body: some View {
        NavigationStack {
            List {
                ringSection
                categoriesSection
                entriesSection
            }
            .listStyle(.plain)
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingTemplatePicker = true
                    } label: {
                        Label("Change Template", systemImage: AppSymbol.budgetTemplate)
                    }
                }
            }
            .sheet(isPresented: $showingTemplatePicker) {
                TemplateOverrideSheet(initialDate: today, allowDateChange: true)
            }
            .sheet(item: $inputCategory) { category in
                SpendInputSheet(
                    date: today,
                    categoryName: category,
                    recentAmounts: engine.recentAmounts(category: category)
                )
                .navigationTransition(.zoom(sourceID: category, in: cardZoom))
            }
        }
    }

    private var ringSection: some View {
        let engine = self.engine
        let budget = engine.effectiveBudget(for: today)
        let used = engine.spent(on: today)
        let template = engine.template(for: today)
        let carryover = engine.carryover == .nextDay ? budget - engine.baseBudget(for: today) : 0
        return Section {
            VStack(spacing: 12) {
                BudgetRingView(
                    used: used,
                    budget: budget,
                    centerCaption: "of \(budget.currencyString)",
                    carryover: carryover
                )
                .frame(height: 200)

                HStack(spacing: 8) {
                    Image(systemName: template?.iconName ?? "questionmark.circle")
                    Text(template?.name ?? "No template for today")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var categoriesSection: some View {
        let engine = self.engine
        let template = engine.template(for: today)
        return Section {
            if let template {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(template.sortedCategories) { category in
                        let used = engine.spent(on: today, category: category.name)
                        Button {
                            inputCategory = category.name
                        } label: {
                            CategoryGridCell(category: category, used: used)
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: category.name, in: cardZoom)
                    }
                }
                .padding(.horizontal, 16)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            } else {
                ContentUnavailableView(
                    "No Template",
                    systemImage: "square.dashed",
                    description: Text("Pick a template for today using the button above.")
                )
            }
        }
    }

    private var entriesSection: some View {
        let todayEntries = engine.entries(on: today).sorted { $0.timestamp > $1.timestamp }
        return Section {
            if todayEntries.isEmpty {
                Text("Nothing recorded yet. Tap a category above to add a spend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(todayEntries) { entry in
                    EntryRow(entry: entry) {
                        modelContext.delete(entry)
                        try? modelContext.save()
                    }
                }
            }
        }
    }
}

/// Category card: colored gradient tile whose background fills as the
/// budget is used — the spent fraction is solid, the rest translucent.
struct CategoryGridCell: View {
    @Environment(\.colorScheme) private var colorScheme

    let category: TemplateCategory
    let used: Decimal

    var body: some View {
        let over = used > category.amount
        let fraction = category.amount > 0
            ? min(1, used.doubleValue / category.amount.doubleValue)
            : (used > 0 ? 1 : 0)
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: category.iconName)
                .font(.system(size: 20))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(height: 26)
            Text(category.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(used.compactCurrencyString)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(category.iconColor.gradient)
                        .opacity(0.3)
                    Rectangle()
                        .fill(category.iconColor.gradient)
                        .frame(width: proxy.size.width * fraction)

                    if over {
                        RadialGradient(
                            colors: [Color.red.opacity(0.85), .clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: max(proxy.size.width, proxy.size.height) * 0.75
                        )
                    }
                }
            }
        }
        .clipShape(.rect(cornerRadius: 22))
        .shadow(
            color: colorScheme == .light ? category.iconColor.opacity(0.35) : .clear,
            radius: 6, y: 3
        )
        .contentShape(.rect)
    }
}

/// One immutable spend entry with a remove control.
struct EntryRow: View {
    let entry: SpendEntry
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.categoryName)
                    .font(.subheadline.weight(.medium))
                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.amount.currencyString)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
