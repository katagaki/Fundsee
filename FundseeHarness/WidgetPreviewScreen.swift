import SwiftUI
import WidgetKit

/// Debug-only screen (launch with `-widgetPreview YES`) that renders every
/// widget family at its real size, using the same entry the widget builds.
struct WidgetPreviewScreen: View {
    private let entry = makeTodayBudgetEntry()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                preview("systemSmall", .systemSmall, width: 170, height: 170)
                preview("systemMedium", .systemMedium, width: 364, height: 170)
                preview("accessoryCircular", .accessoryCircular, width: 76, height: 76)
                preview("accessoryRectangular", .accessoryRectangular, width: 180, height: 76)
                preview("accessoryInline", .accessoryInline, width: 260, height: 28)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func preview(_ title: String, _ family: WidgetFamily, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TodayBudgetContentView(entry: entry, family: family)
                .padding(family == .systemSmall || family == .systemMedium ? 16 : 4)
                .frame(width: width, height: height)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
        }
    }
}
