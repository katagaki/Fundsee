import Foundation

/// What the spend sheet is about to record against: a day's category, or one of
/// the overall budgets with the week or month it is spread over.
struct SpendTarget: Identifiable, Hashable {
    let name: String
    var scope: SpendScope = .day
    var period: DateInterval?

    var id: String { name }
}
