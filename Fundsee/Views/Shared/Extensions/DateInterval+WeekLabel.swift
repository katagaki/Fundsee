import Foundation

extension DateInterval {
    var weekRangeLabel: String {
        let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: end) ?? end
        let format = Date.FormatStyle.dateTime.month(.defaultDigits).day()
        return "\(start.formatted(format)) - \(lastDay.formatted(format))"
    }
}
