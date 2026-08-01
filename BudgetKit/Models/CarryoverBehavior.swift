import Foundation

enum CarryoverBehavior: String, CaseIterable, Identifiable {
    case leaveAsIs
    case nextDay
    case nextWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leaveAsIs: String(localized: "Carryover.LeaveAsIs.Title", defaultValue: "Leave As-Is")
        case .nextDay: String(localized: "Carryover.NextDay.Title", defaultValue: "Carry to Next Day")
        case .nextWeek: String(localized: "Carryover.NextWeek.Title", defaultValue: "Carry to Next Week")
        }
    }

    var subtitle: String {
        switch self {
        case .leaveAsIs: String(localized: "Carryover.LeaveAsIs.Subtitle", defaultValue: "Each day's budget stands on its own.")
        case .nextDay: String(localized: "Carryover.NextDay.Subtitle", defaultValue: "Unused budget increases tomorrow; overspend reduces it. Resets each week.")
        case .nextWeek: String(localized: "Carryover.NextWeek.Subtitle", defaultValue: "Last week's leftover or overspend adjusts this week's budget.")
        }
    }
}
