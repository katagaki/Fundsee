import SwiftUI
import WidgetKit

struct TodayBudgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayBudgetWidget", provider: TodayBudgetProvider()) { entry in
            TodayBudgetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Widget.Title")
        .description("Widget.Description")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}
