import SwiftData
import SwiftUI

/// Settings-app-style row label: white symbol on a colored rounded rectangle.
struct SettingsLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color.gradient, in: .rect(cornerRadius: 7))
        }
    }
}

struct MoreView: View {
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    @Query private var templates: [BudgetTemplate]
    @Query private var entries: [SpendEntry]
    @Query private var allSettings: [PlanSettings]

    @State private var exportURL: URL?
    @State private var templatesExportURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section("Budget Setup") {
                    NavigationLink {
                        TemplatesEditorView()
                    } label: {
                        SettingsLabel(title: "Budget Templates", systemImage: AppSymbol.budgetTemplate, color: .green)
                    }
                    NavigationLink {
                        WeekPlanEditorView()
                    } label: {
                        SettingsLabel(title: "Week Plan", systemImage: "calendar", color: .blue)
                    }
                    NavigationLink {
                        OverallBudgetsView()
                    } label: {
                        SettingsLabel(title: "Weekly & Monthly Budgets", systemImage: "basket.fill", color: .teal)
                    }
                }

                Section("Behavior") {
                    NavigationLink {
                        CarryoverSettingsView()
                    } label: {
                        SettingsLabel(title: "Leftovers", systemImage: "arrow.uturn.forward", color: .orange)
                    }
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsLabel(title: "Notifications", systemImage: "bell.badge.fill", color: .red)
                    }
                }

                Section {
                    Toggle(isOn: $iCloudSyncEnabled) {
                        SettingsLabel(title: "iCloud Sync", systemImage: "icloud.fill", color: .cyan)
                    }
                } footer: {
                    Text("Syncs your templates, plans, and spending across devices with the same Apple Account.")
                }

                Section("Export") {
                    Button {
                        exportURL = try? CSVExporter.exportEntries(entries)
                    } label: {
                        SettingsLabel(title: "Export Spending as CSV", systemImage: "square.and.arrow.up", color: .indigo)
                    }
                    .tint(.primary)
                    Button {
                        templatesExportURL = try? CSVExporter.exportTemplates(templates)
                    } label: {
                        SettingsLabel(title: "Export Templates as CSV", systemImage: "square.and.arrow.up.on.square", color: .purple)
                    }
                    .tint(.primary)
                }
            }
            .navigationTitle("More")
            .sheet(item: $exportURL) { url in
                ShareSheet(url: url)
            }
            .sheet(item: $templatesExportURL) { url in
                ShareSheet(url: url)
            }
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Templates editor

struct TemplatesEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetTemplate.createdAt) private var templates: [BudgetTemplate]

    var body: some View {
        List {
            ForEach(templates) { template in
                NavigationLink {
                    TemplateDetailView(template: template)
                } label: {
                    HStack {
                        Label(template.name, systemImage: template.iconName)
                        Spacer()
                        Text(template.total.currencyString)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    modelContext.delete(templates[index])
                }
                try? modelContext.save()
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Template", systemImage: "plus") {
                    let template = BudgetTemplate(name: "New Template", iconName: AppSymbol.budgetTemplate)
                    modelContext.insert(template)
                    for (index, name) in DefaultData.categoryNames.enumerated() {
                        let category = TemplateCategory(name: name, amount: 0, sortOrder: index, iconName: DefaultData.categoryIcons[index])
                        category.template = template
                        modelContext.insert(category)
                    }
                    try? modelContext.save()
                }
            }
        }
    }
}

struct TemplateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var template: BudgetTemplate

    private static let icons = [
        "building.2.fill", "house.fill", "sofa.fill", "party.popper.fill",
        "airplane", "figure.walk", "cart.fill", "star.fill",
    ]

    var body: some View {
        List {
            Section("Name") {
                TextField("Template Name", text: $template.name)
            }
            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(Self.icons, id: \.self) { icon in
                        Button {
                            template.iconName = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    template.iconName == icon ? Color.accentColor.opacity(0.2) : Color.clear,
                                    in: .rect(cornerRadius: 10)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Section("Categories") {
                ForEach(template.sortedCategories) { category in
                    CategoryAmountRow(category: category)
                }
                .onDelete { indexSet in
                    let sorted = template.sortedCategories
                    for index in indexSet {
                        modelContext.delete(sorted[index])
                    }
                    try? modelContext.save()
                }
                Button("Add Category", systemImage: "plus") {
                    let category = TemplateCategory(
                        name: "New Category",
                        amount: 0,
                        sortOrder: (template.sortedCategories.last?.sortOrder ?? -1) + 1
                    )
                    category.template = template
                    modelContext.insert(category)
                    try? modelContext.save()
                }
            }
            Section {
                LabeledContent("Daily Total", value: template.total.currencyString)
                    .font(.headline)
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? modelContext.save() }
    }
}

struct CategoryAmountRow: View {
    @Bindable var category: TemplateCategory

    var body: some View {
        HStack {
            Menu {
                ForEach(AppSymbol.categoryIcons, id: \.self) { icon in
                    Button {
                        category.iconName = icon
                    } label: {
                        Label(icon == category.iconName ? "Selected" : " ", systemImage: icon)
                    }
                }
            } label: {
                Image(systemName: category.iconName)
                    .font(.system(size: 15))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(category.iconColor)
                    .frame(width: 32, height: 32)
                    .background(category.iconColor.opacity(0.12), in: .circle)
            }
            TextField("Category", text: $category.name)
            Spacer()
            TextField("Amount", value: $category.amount, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Week plan editor

struct WeekPlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetTemplate.createdAt) private var templates: [BudgetTemplate]
    @Query private var allSettings: [PlanSettings]

    private var calendar: Calendar { .current }

    var body: some View {
        List {
            Section {
                if let settings = allSettings.first {
                    ForEach(orderedWeekdays(), id: \.self) { weekday in
                        Picker(calendar.weekdaySymbols[weekday - 1], selection: binding(for: weekday, settings: settings)) {
                            Text("None").tag("")
                            ForEach(templates) { template in
                                Text(template.name).tag(template.uuid)
                            }
                        }
                    }
                }
            } footer: {
                Text("Each weekday uses this template unless you override a specific day.")
            }
        }
        .navigationTitle("Week Plan")
    }

    private func orderedWeekdays() -> [Int] {
        (0..<7).map { ((calendar.firstWeekday - 1 + $0) % 7) + 1 }
    }

    private func binding(for weekday: Int, settings: PlanSettings) -> Binding<String> {
        Binding(
            get: { settings.templateUUID(forWeekday: weekday) ?? "" },
            set: { newValue in
                settings.setTemplateUUID(newValue.isEmpty ? nil : newValue, forWeekday: weekday)
                try? modelContext.save()
            }
        )
    }
}

// MARK: - Overall budgets

struct OverallBudgetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [PlanSettings]

    var body: some View {
        List {
            if let settings = allSettings.first {
                @Bindable var settings = settings
                Section {
                    TextField("Amount", value: $settings.weeklyOverallBudget, format: .number)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Weekly Overall Budget")
                } footer: {
                    Text("Extra budget added once per week, e.g. a weekly frozen food subscription. Set to 0 to disable.")
                }
                Section {
                    TextField("Amount", value: $settings.monthlyOverallBudget, format: .number)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Monthly Overall Budget")
                } footer: {
                    Text("Extra budget added once per month, e.g. a 30-pack box of bread. Set to 0 to disable.")
                }
            }
        }
        .navigationTitle("Overall Budgets")
        .onDisappear { try? modelContext.save() }
    }
}

// MARK: - Carryover

struct CarryoverSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [PlanSettings]

    var body: some View {
        List {
            if let settings = allSettings.first {
                Section {
                    ForEach(CarryoverBehavior.allCases) { behavior in
                        Button {
                            settings.carryover = behavior
                            try? modelContext.save()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(behavior.title)
                                        .font(.body.weight(.medium))
                                    Text(behavior.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if settings.carryover == behavior {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                } footer: {
                    Text("Applies globally to how unused or exceeded budget is treated.")
                }
            }
        }
        .navigationTitle("Leftovers")
    }
}

// MARK: - Notifications

struct NotificationSettingsView: View {
    @AppStorage("notifyDaily") private var notifyDaily = false
    @AppStorage("notifyDailyHour") private var notifyDailyHour = 21
    @AppStorage("notifyWeekly") private var notifyWeekly = false
    @AppStorage("notifyMonthly") private var notifyMonthly = false

    @Query private var templates: [BudgetTemplate]
    @Query private var overrides: [DayOverride]
    @Query private var entries: [SpendEntry]
    @Query private var allSettings: [PlanSettings]

    var body: some View {
        List {
            Section {
                Toggle("Daily Report", isOn: $notifyDaily)
                if notifyDaily {
                    Picker("Time", selection: $notifyDailyHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                }
            } footer: {
                Text("A summary of the day's spending and what's left.")
            }
            Section {
                Toggle("Weekly Report", isOn: $notifyWeekly)
            } footer: {
                Text("Sent on Sunday evenings.")
            }
            Section {
                Toggle("Monthly Report", isOn: $notifyMonthly)
            } footer: {
                Text("Sent on the first morning of each month.")
            }
        }
        .navigationTitle("Notifications")
        .onChange(of: [notifyDaily, notifyWeekly, notifyMonthly]) {
            reschedule()
        }
        .onChange(of: notifyDailyHour) {
            reschedule()
        }
    }

    private func reschedule() {
        let engine = BudgetEngine(templates: templates, overrides: overrides, entries: entries, settings: allSettings.first)
        Task {
            if notifyDaily || notifyWeekly || notifyMonthly {
                _ = await NotificationService.requestAuthorization()
            }
            await NotificationService.reschedule(engine: engine)
        }
    }
}
