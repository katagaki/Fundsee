import SwiftUI

struct WeekDayPill: View {
    static let selectionID = "WeekDayPill.selection"

    static func selectedForeground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? .white : .black
    }

    @Environment(\.colorScheme) private var colorScheme

    enum Status {
        case empty, under, over

        var color: Color {
            switch self {
            case .empty: .gray.opacity(0.35)
            case .under: .green
            case .over: .red
            }
        }
    }

    let day: Date
    let isSelected: Bool
    let status: Status
    let selectionNamespace: Namespace.ID

    var body: some View {
        VStack(spacing: 6) {
            Text(day.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
            Text(Calendar.current.component(.day, from: day), format: .number.grouping(.never))
                .font(.callout.weight(day.isToday || isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? Self.selectedForeground(colorScheme) : (day.isToday ? Color.accentColor : .primary))
                .frame(width: 36, height: 36)
                .background {
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: Self.selectionID, in: selectionNamespace)
                    }
                }
            Circle()
                .fill(status.color)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}
