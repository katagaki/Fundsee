import SwiftData
import SwiftUI

struct TodayView: View {
    @Query private var templates: [BudgetTemplate]
    @Query private var overrides: [DayOverride]
    @Query(sort: \SpendEntry.timestamp, order: .reverse) private var entries: [SpendEntry]
    @Query private var allSettings: [PlanSettings]

    @State private var spendTarget: SpendTarget?
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
                extraBudgetsSection
                changePlanSection
            }
            .listStyle(.plain)
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
            .toolbarTitleDisplayMode(.inlineLarge)
            .sheet(isPresented: $showingTemplatePicker) {
                TemplateOverrideSheet(initialDate: today)
                    .navigationTransition(.zoom(sourceID: "changePlan", in: cardZoom))
            }
            .sheet(item: $spendTarget) { target in
                SpendInputSheet(
                    date: today,
                    categoryName: target.name,
                    recentAmounts: engine.recentAmounts(category: target.name),
                    scope: target.scope,
                    period: target.period
                )
                .navigationTransition(.zoom(sourceID: target.name, in: cardZoom))
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
                    carryover: carryover,
                    spendPalette: engine.spendPalette(on: today)
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
                            spendTarget = SpendTarget(name: category.name)
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

    private var extraBudgetsSection: some View {
        Section {
            ExtraBudgetCards(engine: engine, date: today, namespace: cardZoom, spendTarget: $spendTarget)
                .padding(.horizontal, 16)
                .padding(.top, 10)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private var changePlanSection: some View {
        Section {
            Button {
                showingTemplatePicker = true
            } label: {
                Text("Common.ChangeTemplate")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .matchedTransitionSource(id: "changePlan", in: cardZoom)
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }
}
