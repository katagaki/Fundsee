import WidgetKit

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
