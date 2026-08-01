import SwiftUI
import WidgetKit

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
