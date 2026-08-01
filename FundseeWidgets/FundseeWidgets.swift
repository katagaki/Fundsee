import SwiftData
import SwiftUI
import WidgetKit

@main
struct FundseeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayBudgetWidget()
    }
}

struct TodayBudgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        completion(makeTodayBudgetEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now)
            ?? Date.now.addingTimeInterval(1800)
        completion(Timeline(entries: [makeTodayBudgetEntry()], policy: .after(refresh)))
    }
}

struct TodayBudgetWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: BudgetEntry

    var body: some View {
        TodayBudgetContentView(entry: entry, family: family)
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
    }
}

struct TodayBudgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayBudgetWidget", provider: TodayBudgetProvider()) { entry in
            TodayBudgetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Budget")
        .description("How much of today's budget is left.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}
