import Foundation

extension DateInterval {
    /// Short numeric week range, e.g. "7/26 - 8/1". Digit order follows the
    /// locale, which is month-first in English and in all of ja/ko/zh.
    ///
    /// The interval's `end` is the exclusive start of the next week, so the
    /// label has to step back a day to name the last day actually inside it.
    var weekRangeLabel: String {
        let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: end) ?? end
        let format = Date.FormatStyle.dateTime.month(.defaultDigits).day()
        return "\(start.formatted(format)) - \(lastDay.formatted(format))"
    }
}
