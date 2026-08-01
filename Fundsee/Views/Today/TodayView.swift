import SwiftData
import SwiftUI

struct TodayView: View {
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
            }
            .listStyle(.plain)
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingTemplatePicker = true
                    } label: {
                        Label("Common.ChangeTemplate", systemImage: AppSymbol.budgetTemplate)
                    }
                }
            }
            .sheet(isPresented: $showingTemplatePicker) {
                TemplateOverrideSheet(initialDate: today)
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
                    centerCaption: String(localized: "Ring.Caption.Of", defaultValue: "of \(budget.currencyString)"),
                    carryover: carryover
                )
                .frame(height: 200)

                HStack(spacing: 8) {
                    Image(systemName: template?.iconName ?? "questionmark.circle")
                    if let template {
                        Text(template.name)
                    } else {
                        Text("Today.NoTemplate.Inline")
                    }
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
                    "Today.NoTemplate.Title",
                    systemImage: "square.dashed",
                    description: Text("Today.NoTemplate.Description")
                )
            }
        }
    }

}
