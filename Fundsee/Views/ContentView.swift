import SwiftData
import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query private var templates: [BudgetTemplate]
    @Query private var overrides: [DayOverride]
    @Query private var entries: [SpendEntry]
    @Query private var allSettings: [PlanSettings]

    @State private var selectedTab = UserDefaults.standard.string(forKey: "initialTab") ?? "today"

    private var engine: BudgetEngine {
        BudgetEngine(templates: templates, overrides: overrides, entries: entries, settings: allSettings.first)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "sun.max.fill", value: "today") {
                TodayView()
            }
            Tab("Week", systemImage: "calendar.day.timeline.left", value: "week") {
                WeekView()
            }
            Tab("Month", systemImage: "calendar", value: "month") {
                MonthView()
            }
            Tab("Year", systemImage: "chart.bar.xaxis", value: "year") {
                YearView()
            }
            Tab("More", systemImage: "ellipsis", value: "more") {
                MoreView()
            }
        }
        .task {
            DefaultData.seedIfNeeded(context: modelContext)
            DefaultData.seedSampleDataIfRequested(context: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                let engine = self.engine
                Task { await NotificationService.reschedule(engine: engine) }
            } else {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [BudgetTemplate.self, TemplateCategory.self, DayOverride.self, SpendEntry.self, PlanSettings.self], inMemory: true)
}
